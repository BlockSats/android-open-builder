# Architecture

## 1. Purpose

Android Open Builder provides a common command-line framework for building multiple open-source Android projects on a remote Debian host.

The framework owns shared concerns such as environment checks, logging, downloads, checksums, workspace management, artifact metadata, and user interaction. Each application-specific builder owns its source repositories, pinned versions, dependencies, patches, build commands, and artifact collection rules.

## 2. Design principles

1. **Modular builders** — application-specific logic stays inside `builders/<name>/`.
2. **Pinned toolchains** — SDK, NDK, Java, and important upstream revisions are declared rather than silently following latest versions.
3. **Reproducible records** — every build produces a manifest containing tool versions, source revisions, options, timestamps, and checksums.
4. **Safe defaults** — generated files and secrets are excluded from Git; destructive cleanup requires explicit scope.
5. **Transparent execution** — commands are logged and failures retain enough context for diagnosis.
6. **CLI first** — all operations work non-interactively; the menu is only a front end.
7. **Host isolation** — project-managed Android tooling lives under a configurable data directory instead of modifying unrelated system paths.
8. **Incremental adoption** — RetroArch is implemented first; later builders reuse stable shared components.

## 3. Repository layout

```text
android-open-builder/
├── aob                         # Main command dispatcher
├── menu.sh                     # Optional interactive interface
├── config/
│   ├── defaults.conf           # Versioned defaults
│   └── local.conf.example      # Example local overrides
├── builders/
│   └── retroarch/
│       ├── builder.sh          # Builder entry points
│       ├── config.conf         # Pinned sources and defaults
│       ├── cores.conf          # Supported Libretro cores
│       ├── patches/            # Versioned project patches
│       └── README.md
├── lib/
│   ├── common.sh               # Output, errors, paths, utilities
│   ├── config.sh               # Configuration loading
│   ├── download.sh             # Download and checksum handling
│   ├── git.sh                  # Clone, revision, dirty-tree helpers
│   ├── logging.sh              # Per-run logs
│   ├── manifest.sh             # Build metadata generation
│   └── platform.sh             # Debian/CPU/RAM/disk detection
├── scripts/
│   ├── doctor.sh
│   ├── install.sh
│   ├── clean.sh
│   └── fetch-artifact.sh
├── docs/
├── tests/
└── .github/
```

The following local directories are created at runtime and ignored by Git:

```text
.aob/
cache/
downloads/
logs/
output/
work/
```

## 4. Command model

The main executable is `aob`.

```text
./aob doctor
./aob install
./aob list
./aob build <builder> [options]
./aob clean [scope]
./aob fetch <builder>
```

Exit-code convention:

- `0`: success;
- `1`: build or operational failure;
- `2`: invalid command or configuration;
- `3`: missing prerequisite;
- `4`: network or download verification failure.

Builder interface, implemented as Bash functions:

```bash
builder_metadata
builder_doctor
builder_fetch
builder_prepare
builder_build
builder_collect
builder_manifest
```

The dispatcher loads only the selected builder.

## 5. Configuration hierarchy

Configuration is applied in this order, with later values overriding earlier values:

1. `config/defaults.conf`;
2. `builders/<name>/config.conf`;
3. optional user file `${AOB_CONFIG:-$HOME/.config/android-open-builder/config.conf}`;
4. supported environment variables;
5. explicit command-line options.

Secrets are never accepted in versioned configuration files. Signing credentials will be read from protected local files or environment variables and redacted from logs.

## 6. Data locations

By default:

```text
AOB_DATA_DIR=$HOME/.local/share/android-open-builder
AOB_CACHE_DIR=$HOME/.cache/android-open-builder
AOB_CONFIG_DIR=$HOME/.config/android-open-builder
```

A repository-local development mode may use `.aob/`. The selected paths must always be printed by `./aob doctor`.

## 7. Build lifecycle

1. Validate host and builder prerequisites.
2. Resolve configuration and write a sanitized run configuration.
3. Acquire a build lock to prevent conflicting builds.
4. Download or update sources at configured revisions.
5. Verify downloaded archives.
6. Prepare an isolated workspace.
7. Apply tracked patches idempotently.
8. Build with captured stdout and stderr.
9. Collect APKs and related artifacts.
10. Generate SHA-256 checksums and a machine-readable manifest.
11. Copy results into a timestamped output directory.
12. Preserve logs whether the build succeeds or fails.

Example output:

```text
output/retroarch/2026-07-26T153000Z/
├── RetroArch-Rom-Build-arm64-v8a.apk
├── SHA256SUMS
├── manifest.json
└── build-summary.txt
```

## 8. RetroArch builder: first implementation

Initial frontend target:

- Android ARM64 only;
- distinct application ID so it can coexist with an official RetroArch installation;
- distinct display name;
- debug APK first, personal release signing later.

Initial cores:

| Platform | Core |
|---|---|
| NES / Famicom | FCEUmm, Nestopia |
| SNES | Snes9x |
| Commodore 64 | VICE x64 |
| Amiga | PUAE |
| Atari ST | Hatari |
| Amstrad CPC | Caprice32 |
| ZX Spectrum | Fuse |
| MSX | blueMSX |
| DOS | DOSBox SVN |

Core selection must be configurable so a user can build the default pack or a subset.

## 9. Diagnostics

`./aob doctor` must report, without modifying the host:

- supported operating system and architecture;
- CPU count, RAM, swap, and available disk space;
- Git and GitHub connectivity;
- Java version;
- Android SDK, Build Tools, and NDK versions;
- CMake, Ninja, compiler, Python, and archive utilities;
- writable data, cache, work, log, and output directories;
- builder-specific requirements.

Results use `PASS`, `WARN`, and `FAIL`. A machine-readable mode is planned:

```bash
./aob doctor --json
```

## 10. Installation policy

The installer may install Debian packages with explicit user consent. It must not:

- overwrite unrelated Android SDK installations;
- alter shell startup files without displaying the exact change;
- create or expose signing keys automatically;
- upload artifacts or source code;
- run as root except for package-management steps that require privilege.

All important versions and download locations must be visible in configuration.

## 11. Logging and manifests

Each run gets an identifier and log directory. Logs include command context but redact known secret variables.

The JSON manifest should include:

- project and builder version;
- host OS and architecture;
- Java, SDK, NDK, Gradle, CMake, and Ninja versions;
- upstream repository URLs and commit hashes;
- selected cores and build options;
- patch hashes;
- artifact names, sizes, and SHA-256 checksums;
- start time, end time, duration, and final status.

## 12. Testing strategy

Initial tests use ShellCheck and small Bash integration tests for configuration, path handling, command dispatch, checksum verification, and manifest generation.

Real Android compilation remains an integration test because it is resource intensive. GitHub Actions should initially validate scripts and documentation, not publish unsigned third-party APKs automatically.

## 13. Security and legal boundaries

The project builds open-source software but does not distribute ROMs, BIOS files, copyrighted game assets, private signing material, or third-party credentials.

Upstream licenses must be preserved. Builders must document the upstream projects they invoke and any redistribution constraints before automated releases are enabled.

## 14. Decisions still open

- project license;
- exact CLI argument parser approach;
- supported Debian/Ubuntu versions beyond Debian 12;
- artifact transfer method between VPS and Termux;
- whether GitHub Actions should ever perform full Android builds;
- release-signing workflow and keystore backup policy.
