# RetroArch builder

Status: **ARM64 smoke build**.

The builder currently creates two separate artifacts:

1. a customized RetroArch AArch64 debug APK;
2. an FCEUmm Android ARM64 libretro core.

The core is **not yet bundled inside the APK**. Core installation and packaging are
reserved for a later pull request after the frontend and core compile successfully
on the Debian 12 build host.

## Upstream pins

The source revisions are immutable commit SHAs declared in `config.conf`:

- RetroArch: `2b4a480517ec6fe40ef666fb49adf123def38cd2`;
- FCEUmm: `76f68314ce4213703174108f461c431001dcc204`.

The RetroArch pin uses the current Android build configuration for SDK 36,
Build Tools 36.0.0, NDK 29.0.14206865, AGP 9.1.0, and Gradle 9.3.1.

## Build

Run long builds inside `tmux` or another persistent terminal session:

```bash
./aob build retroarch --cores fceumm
```

Optional controls:

```bash
./aob build retroarch --cores fceumm --jobs 4
./aob build retroarch --cores fceumm --no-clean
```

## Output

```text
~/.local/share/android-open-builder/output/retroarch/<build-id>/
├── RetroArch-AOB-arm64-v8a-debug.apk
├── fceumm_libretro_android.so
├── SHA256SUMS
├── manifest.json
└── build.log
```

The workspace is reset to the pinned revisions before each build. Gradle and
source directories are reused locally to reduce repeated downloads.
