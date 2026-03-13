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
