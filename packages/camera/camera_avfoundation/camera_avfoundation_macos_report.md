# camera_avfoundation macOS Report

## Status

This branch has successfully moved `camera_avfoundation` to a shared Darwin layout that builds for macOS while keeping the existing iOS native test suite green.

Current state:

- `sharedDarwinSource: true` is in use for both iOS and macOS.
- The active native implementation now lives under `darwin/`.
- The obsolete temporary `macos/` native prototype copy has been removed.
- `flutter build macos` succeeds for the example app.
- iOS native `RunnerTests` succeed.
- Dart format, analysis, and Dart tests succeed.

Bottom line: the architectural migration is done. The remaining work before a PR is runtime validation and a small amount of product-level decision making around unsupported capabilities.

## What Changed

### Shared Darwin migration

- Migrated the package to `sharedDarwinSource: true` in `pubspec.yaml`.
- Added the real Darwin package layout under `darwin/camera_avfoundation/`.
- Updated the example to include a working macOS host app with camera and microphone permissions.
- Removed the temporary duplicate native implementation that had lived under `macos/`.

### Shared camera-path refactor

- Replaced direct `UIDeviceOrientation` usage in the core camera path with `PlatformDeviceOrientation`.
- Isolated iOS-only device orientation notifications behind `#if os(iOS)`.
- Added platform-aware orientation behavior so macOS can compile without iOS sensor APIs.

### AVFoundation abstraction work

- Reworked the AVFoundation seam so the shared code uses wrapper objects for capture devices, sessions, connections, and outputs.
- Moved capability and availability differences to the wrapper layer instead of letting shared code depend directly on iOS-only APIs.
- Added macOS-safe fallbacks for unsupported capabilities on the current minimum target.

### Validation cleanup

- Kept the iOS native test suite passing through the refactor.
- Fixed example/test issues introduced during migration.
- Restored a clean validation path for format, analyze, Dart tests, iOS native tests, and macOS build.

## External-Camera Prototype Comparison

I compared this branch against Stuart's earlier `ios-support-external-cameras` prototype branch.

### What Stuart's branch did

- It kept the existing iOS AVFoundation architecture.
- It added external-camera discovery on supported OS versions by appending `.external` to the discovery device list.
- It added disconnect handling for the active external camera by observing `AVCaptureDevice.wasDisconnectedNotification` and surfacing an error when the active external device disappeared.

### What this branch does differently

- The main difference is architectural scope, not capture-model philosophy.
- This branch focuses on making the plugin genuinely Darwin-shared:
  - shared package layout
  - platform-neutral orientation types
  - AVFoundation wrapper seams
  - macOS-safe capability handling
- It does not currently carry forward Stuart's external-camera discovery/disconnect behavior into the active shared implementation yet.

### Conclusion from the comparison

External-camera support does not appear to require a fundamentally different session or device model on macOS.

Why:

- Stuart's prototype handled external cameras by extending the same capture-session architecture rather than introducing a separate pipeline.
- The current branch also keeps the same overall camera/session model; it just makes that model portable across Darwin platforms.
- The work needed for external cameras looks additive: discovery policy, disconnect handling, and capability validation.

So the answer to the question in the report is: no, the earlier prototype does not suggest that macOS external-camera support forces a significantly different session/device architecture.

## Recommendation

Keep the shared Darwin layout.

The evidence so far points to:

- one shared AVFoundation capture architecture,
- plus platform-specific capability adapters,
- plus explicit handling for external-device discovery and disconnects.

That is consistent with both the current implementation and the earlier external-camera prototype.

## Remaining Work Before PR

### 1. Manual macOS runtime QA

This is now the main unknown. The code builds, but it still needs real-device validation for:

- preview rendering
- still capture
- video recording with audio
- image streaming
- camera switching
- relaunch stability after permissions are granted

### 2. External-camera behavior on macOS

The current branch proves the shared Darwin migration. It does not yet prove full macOS external-camera behavior.

Manual testing should cover:

- app launch with an external camera already attached
- attach after launch
- select external camera
- preview, photo, video, and streaming on that camera
- unplug during preview
- unplug during recording
- unplug during image streaming
- reconnect and recover

### 3. Capability semantics review

Some capabilities are intentionally guarded or downgraded on macOS 10.15. Before PR, we should confirm how these should surface to Dart callers:

- stabilization
- flash/torch-related behavior
- exposure/zoom capability differences
- any other feature where macOS support is partial rather than absent

## Manual QA Checklist

### Repository-level checks

1. Run format.
2. Run analyze.
3. Run Dart tests.
4. Run iOS native `RunnerTests`.
5. Build the macOS example.

### macOS app checks

1. Launch the example on macOS.
2. Grant camera permission.
3. Grant microphone permission if recording with audio.
4. Confirm preview renders frames.
5. Take a still photo.
6. Record video, then stop and verify completion.
7. Start and stop image streaming.
8. If multiple cameras exist, switch between them.
9. Relaunch and verify initialization still works.

### macOS external-camera checks

1. Start with the external camera attached.
2. Start without it attached, then plug it in.
3. Select the external camera.
4. Verify preview.
5. Verify still capture.
6. Verify video recording.
7. Verify image streaming.
8. Unplug during preview.
9. Unplug during recording.
10. Unplug during image streaming.
11. Reconnect and verify recovery behavior.

## Validation Commands

Run from the repository root unless noted.

### Format

```sh
export REPO_ROOT=$PWD
dart run $REPO_ROOT/script/tool/bin/flutter_plugin_tools.dart format \
  --clang-format-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang-format \
  --packages camera_avfoundation
```

### Analyze

```sh
export REPO_ROOT=$PWD
dart run $REPO_ROOT/script/tool/bin/flutter_plugin_tools.dart analyze --packages camera_avfoundation
```

### Dart tests

```sh
export REPO_ROOT=$PWD
dart run $REPO_ROOT/script/tool/bin/flutter_plugin_tools.dart dart-test --packages camera_avfoundation
```

### iOS native tests

Run from `packages/camera/camera_avfoundation/example/ios`:

```sh
xcodebuild test \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPad (A16)' \
  -only-testing:RunnerTests
```

### macOS build

Run from `packages/camera/camera_avfoundation/example`:

```sh
flutter build macos
```

## Bottom Line

This branch has already answered the main architecture question: `camera_avfoundation` can use one shared Darwin AVFoundation implementation for iOS and macOS.

Compared with Stuart's earlier external-camera prototype, the approach is mostly the same at the capture-model level and different mainly in scope: this branch adds the shared-Darwin refactor and macOS portability work, while Stuart's branch was a narrower iOS external-camera prototype.

Recommendation: keep the shared Darwin layout, finish manual QA, and then decide whether to port the earlier external-camera discovery/disconnect behavior into the shared implementation before opening the PR.
