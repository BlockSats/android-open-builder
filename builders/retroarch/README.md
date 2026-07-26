# RetroArch builder

Status: **ARM64 build with bundled FCEUmm core**.

The builder creates a customized RetroArch AArch64 debug APK and also retains a
standalone FCEUmm Android ARM64 libretro core for verification.

FCEUmm is packaged inside the APK as a native library. On first launch, the
included Java installer copies it into RetroArch's writable `cores` directory.
The installer tracks the pinned FCEUmm revision and replaces the installed core
when a future APK contains a different revision.

## Upstream pins

The source revisions are immutable commit SHAs declared in `config.conf`:

- RetroArch: `2b4a480517ec6fe40ef666fb49adf123def38cd2`;
- FCEUmm: `76f68314ce4213703174108f461c431001dcc204`.

The RetroArch pin uses the current Android build configuration for SDK 36,
Build Tools 36.0.0, NDK 29.0.14206865, AGP 9.1.0, and Gradle 9.3.1.

## Build

```bash
./aob build retroarch --cores fceumm
```

Optional controls:

```bash
./aob build retroarch --cores fceumm --jobs 4
./aob build retroarch --cores fceumm --no-clean
```

## APK packaging

The core is staged in the APK at:

```text
lib/arm64-v8a/libfceumm_libretro_android.so
```

At first launch it is copied to the app-private RetroArch directory as:

```text
cores/fceumm_libretro_android.so
```

The builder verifies the APK entry before publishing artifacts.

## Output

```text
~/.local/share/android-open-builder/output/retroarch/<build-id>/
├── RetroArch-AOB-arm64-v8a-debug.apk
├── fceumm_libretro_android.so
├── SHA256SUMS
├── manifest.json
└── build.log
```

The manifest uses schema version 2 and records both the APK path and installed
core path. The workspace is reset to the pinned revisions before each build.
Gradle and source directories are reused locally to reduce repeated downloads.
