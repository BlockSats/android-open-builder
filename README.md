# Android Open Builder

Android Open Builder is a modular, open-source build environment for compiling Android applications reproducibly on Debian-based servers.

The first supported target is **RetroArch for ARM64 Android devices**, with an initial focus on the Google Pixel 6 Pro. The project is designed so additional builders can later be added without mixing their dependencies, patches, or build logic.

## Project status

Early architecture phase. No stable release is available yet.

## Initial objectives

- provide a guided installation for a Debian 12 VPS;
- verify the host with a `doctor` command;
- compile RetroArch and selected Libretro cores for `arm64-v8a`;
- produce traceable APKs with checksums, logs, and source manifests;
- keep secrets, signing keys, SDK files, build caches, and generated APKs outside Git;
- support interactive and non-interactive use;
- remain extensible to other open-source Android applications.

## Planned usage

```bash
./aob doctor
./aob install
./aob build retroarch
```

An interactive menu will also be available:

```bash
./menu.sh
```

## Planned repository layout

```text
android-open-builder/
├── aob
├── menu.sh
├── builders/
│   └── retroarch/
├── config/
├── docs/
├── lib/
├── scripts/
└── tests/
```

Runtime directories such as `cache/`, `downloads/`, `logs/`, `output/`, and `work/` will be created locally and ignored by Git.

## Supported host and target

Initial development target:

- host: Debian 12, x86-64;
- Android target: ARM64 (`arm64-v8a`);
- Java: OpenJDK 17;
- Android SDK and NDK versions: pinned by the project configuration;
- primary test device: Google Pixel 6 Pro.

Termux is used as a control terminal and APK retrieval client. Compilation is performed on the VPS.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)

## Security principles

- never commit tokens, passwords, private keys, keystores, ROMs, BIOS files, or proprietary assets;
- verify downloaded tool archives when upstream checksums are available;
- separate debug and personal release signing;
- record upstream revisions used for each build;
- avoid executing unverified remote scripts through `curl | bash`.

## License

A project license has not yet been selected. No reuse rights are granted until a license file is added.
