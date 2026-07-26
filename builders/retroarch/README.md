# RetroArch builder

Status: **scaffold only**.

The first complete builder will target Android ARM64 and create an APK named
**RetroArch Rom Build** with an application ID distinct from the official app.

The default core pack is declared in `cores.conf`. Actual source pins,
toolchain versions, patches, build commands, asset bundling, checksums, and
manifests will be added in the Android-toolchain and RetroArch phases.
