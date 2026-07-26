# Roadmap

## Phase 0 — Repository foundation

- [x] Create the public repository.
- [x] Define the initial architecture.
- [ ] Select and add a project license.
- [ ] Add contribution and security guidance.
- [ ] Add ShellCheck and Markdown validation.

## Phase 1 — Core framework

- [ ] Implement the `aob` command dispatcher.
- [ ] Implement configuration loading and path resolution.
- [ ] Implement structured logging and build run identifiers.
- [ ] Implement `./aob doctor` for Debian 12 x86-64.
- [ ] Implement safe workspace and cache management.
- [ ] Add initial Bash tests.

## Phase 2 — Android toolchain installer

- [ ] Install and validate OpenJDK 17.
- [ ] Install Android command-line tools.
- [ ] Pin SDK Platform, Build Tools, and NDK versions.
- [ ] Verify downloaded archives.
- [ ] Support existing user-managed Android SDK installations.
- [ ] Document disk, RAM, swap, and CPU recommendations.

## Phase 3 — RetroArch builder

- [ ] Fetch RetroArch and Libretro sources.
- [ ] Build the ARM64 frontend.
- [ ] Build the default NES, SNES, and computer core pack.
- [ ] Allow custom core selection.
- [ ] Use a distinct application ID and display name.
- [ ] Bundle frontend assets.
- [ ] Produce checksums, logs, and a source manifest.
- [ ] Validate installation on a Pixel 6 Pro.

## Phase 4 — Signing and artifact transfer

- [ ] Document debug and personal release signing.
- [ ] Prevent signing secrets from entering Git or logs.
- [ ] Implement secure artifact retrieval from Termux.
- [ ] Verify APK checksum after transfer.
- [ ] Document keystore backup and recovery.

## Phase 5 — Usability

- [ ] Implement `menu.sh` as a front end to the CLI.
- [ ] Add progress summaries suitable for mobile terminals.
- [ ] Add update and scoped cleanup commands.
- [ ] Add troubleshooting diagnostics and failure bundles.

## Phase 6 — Additional builders

Candidates, added only after the shared framework and RetroArch builder are stable:

- PPSSPP;
- ScummVM;
- Dolphin;
- other maintainable open-source Android applications.

Each candidate requires a licensing, build-system, resource, and maintenance assessment before implementation.
