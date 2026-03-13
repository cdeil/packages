# camera_avfoundation macOS Implementation Report

## Current Status

`camera_avfoundation` now uses a shared Darwin implementation that builds and runs on macOS.

Current implementation state:

- `sharedDarwinSource: true` is in use
- the active native code lives under `darwin/camera_avfoundation/`
- the temporary duplicate macOS native implementation has been removed
- the macOS example host app builds and runs
- camera discovery, preview startup, still capture, and multi-camera switching now work at a basic level

## Main Implementation Changes

### Shared Darwin migration

- consolidated iOS and macOS AVFoundation code under one Darwin implementation
- replaced iOS-only assumptions with platform-aware wrappers and guards
- kept the existing iOS native test path intact during the refactor

### macOS preview startup fix

- the original blank preview was caused by the iOS-style manual capture-session connection path not delivering frames on macOS
- macOS now uses automatic session wiring (`addInput` / `addOutput`)
- that restored frame delivery to the Flutter texture path

### macOS camera discovery

- discovery now includes both built-in and external-style macOS camera device types
- current manual testing confirms enumeration of built-in Mac cameras, USB cameras, and Continuity/iPhone cameras

### Example-side macOS support

- added a small macOS-only method channel in the example host app to expose localized camera names from AVFoundation
- improved the example camera selector for multi-camera testing
- guarded unsupported tap-to-focus/exposure interactions in the example
- disabled audio by default on macOS in the example as a temporary mitigation for the current speaker-noise issue

## Open Implementation Issues

1. Preview orientation is still wrong on macOS cameras.
2. Still-photo orientation is still camera-dependent, especially for the Continuity/iPhone camera.
3. macOS camera naming and lens-direction semantics may still need a plugin-level decision rather than only example-side handling.
4. The macOS audio path still needs investigation before audio should be enabled by default again.
5. The startup log line about `NSKVONotifying_AVCapturePhotoOutput` remains unexplained, but it does not currently block preview or still capture.

## Recommendation

Keep the shared Darwin layout.

The remaining problems are runtime behavior and capability-handling issues, not evidence that macOS needs a separate long-term architecture.

All runtime findings, matrices, regressions, and manual QA results should live in [packages/camera/camera_avfoundation/camera_avfoundation_macos_testing_report.md](/Users/cdeil/code/oss/packages/packages/camera/camera_avfoundation/camera_avfoundation_macos_testing_report.md).

## Proposed PR Split

The current spike branch is a good candidate for splitting into 3 PRs.

Why split it:

- GitHub review becomes much easier when structural refactors, feature bring-up, and debugging/example work are separated.
- Reviewers can validate the low-risk architectural work first before getting into macOS runtime behavior.
- If the macOS orientation issues keep moving, they do not have to block landing the earlier cleanup and plumbing work.

Based on the current diff against `main`, the changed files are concentrated in:

- shared preview widget code in `camera`
- Darwin native files in `camera_avfoundation`
- example app Dart and macOS host files
- the macOS report documents

### PR 1: Shared Darwin migration and core refactor

Goal:

- land the structural migration and shared-camera-path cleanup with minimal user-visible discussion

Should contain:

- `sharedDarwinSource: true` migration and Darwin layout changes
- shared AVFoundation wrapper/refactor work
- platform-aware orientation/device abstractions needed for shared compilation
- removal of the obsolete duplicate macOS native implementation
- any required iOS-safe test or build fixes that are strictly part of the refactor

Why first:

- this is the lowest-level foundation
- it is the easiest part to review in isolation
- it reduces noise in later PRs

### PR 2: macOS camera bring-up

Goal:

- land basic macOS support as a working feature: enumerate cameras, start preview, and take still images

Should contain:

- macOS session wiring changes in the Darwin native camera implementation
- macOS camera discovery changes, including external-style devices
- still-capture path changes needed for macOS bring-up
- macOS example host app support and permissions wiring
- the app-facing preview widget changes needed to render macOS preview content

Why second:

- this is the actual feature PR from a product perspective
- it can be reviewed as “macOS support exists” even if orientation is not fully polished yet

### PR 3: example UX, debugging, and follow-up runtime fixes

Goal:

- land the debugging and stabilization work that made the feature testable on real hardware

Should contain:

- example camera selector improvements
- macOS localized camera-name lookup in the example host app
- example controller lifecycle fixes for rapid camera switching
- capability guards for unsupported focus/exposure point interactions
- temporary macOS audio mitigation in the example
- report/documentation updates that describe the current runtime status
- any remaining orientation fixes if they are not ready for PR 2

Why third:

- most of this is example-only or follow-up stabilization work
- it is useful, but not essential to understanding the core migration or initial macOS bring-up

## Open Question

The one thing that could change the exact boundary between PR 2 and PR 3 is the orientation problem.

Open question:

- if preview/still-photo orientation fixes stay invasive, should they remain in PR 3 as follow-up stabilization work, or should the minimum acceptable macOS-support PR require correct orientation before landing?

I would leave that open for now while continuing orientation debugging.
