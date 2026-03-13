# camera_avfoundation macOS Report

## Status

This branch successfully pushed `camera_avfoundation` through a shared Darwin migration far enough that the package now builds for macOS while keeping existing iOS native tests green.

Current state:

- `flutter build macos` succeeds for the example app.
- iOS native `RunnerTests` succeed.
- Dart analysis and Dart tests succeed after the final example import cleanup.
- The plugin now uses `sharedDarwinSource: true` in `pubspec.yaml` and has a real `darwin/` package layout.
- The remaining work is no longer “make macOS compile”; it is now runtime validation, follow-up cleanup, and deciding how much more capability specialization is needed before opening a PR.

Bottom line: the shared Darwin migration was a success. At this point I would recommend continuing with the shared Darwin layout rather than backing out to a separate macOS-only native implementation.

## What Was Implemented

### 1. Orientation abstraction refactor

The shared camera flow no longer stores `UIDeviceOrientation` directly in the core camera path.

Implemented changes:

- `Camera.deviceOrientation` now uses `PlatformDeviceOrientation` internally.
- `CameraConfiguration.orientation` now uses `PlatformDeviceOrientation`.
- `DefaultCamera.lockedCaptureOrientation` now stores an optional `PlatformDeviceOrientation` instead of using `UIDeviceOrientation.unknown` as a sentinel.
- Orientation-to-`AVCaptureVideoOrientation` mapping was rewritten against `PlatformDeviceOrientation`.
- Exposure and focus point calculations now use the platform-neutral orientation value from `DeviceOrientationProvider`.

Why this matters:

- This removes the main type-system dependency that made the shared camera flow fundamentally iOS-only.
- It is a prerequisite for any real Darwin-shared implementation.

### 2. iOS-only orientation notifications isolated

Implemented changes:

- `CameraPlugin` now wraps `UIDevice` orientation notification registration in `#if os(iOS)`.
- `CameraPlugin.orientationChanged` is iOS-only.
- `DeviceOrientationProvider` is now platform-aware:
  - iOS uses `UIDevice.current.orientation` converted into `PlatformDeviceOrientation`.
  - macOS currently returns a deterministic `.landscapeLeft` fallback.

Why this matters:

- The plugin can now compile orientation logic without assuming device-sensor APIs exist on macOS.

### 3. Shared Darwin native layout migration

Implemented changes:

- `example/macos` was generated so there is now a real macOS app host for testing.
- macOS app permissions were added to the example:
  - `NSCameraUsageDescription`
  - `NSMicrophoneUsageDescription`
  - sandbox entitlements for camera and microphone
- `CameraPlugin`, `Camera`, `DefaultCamera`, `ImageStreamHandler`, `SavePhotoDelegate`, and `CameraPermissionManager` were updated to use conditional `Flutter` / `FlutterMacOS` imports.
- The package was migrated to the repo’s shared Darwin structure:
  - `sharedDarwinSource: true` for iOS and macOS
  - `darwin/camera_avfoundation/` Swift package
  - `darwin/camera_avfoundation.podspec`
- `example/macos/Runner.xcodeproj` was patched to add the standard Flutter ephemeral framework search path used by working macOS examples in this repo.
- The existing `ios/` native source tree was kept as the working source while iterating, then synced into `darwin/` once the wrappers were stable.

Why this matters:

- This matches the direction already used by first-party Darwin plugins in this repo, including `video_player_avfoundation`.
- The plugin now compiles from the same Darwin source base for both iOS and macOS instead of depending on a separate macOS prototype copy.

### 4. AVFoundation abstraction reshaping

Implemented changes:

- Replaced direct protocol conformance by AVFoundation classes with explicit wrapper objects for:
  - capture devices
  - capture sessions
  - video data outputs
  - photo outputs
  - capture connections
- Removed iOS-only stabilization types from the shared protocol surface.
- Added platform-specific fallbacks and no-ops for APIs that are unavailable on macOS 10.15.
- Updated device discovery to wrap native devices and to avoid unavailable iOS-only camera device types on macOS.

Why this matters:

- This was the change that unblocked the macOS compile.
- It also matches Apple’s current guidance more closely: keep a shared capture architecture, but isolate platform-specific capabilities and availability differences at the edge.

### 5. Validation and test cleanup

Implemented changes:

- Fixed the iOS mock/test breakage introduced by the orientation refactor.
- Added a minimal example Dart smoke test so the repository `dart-test` step passes again.
- Removed generated example files that conflicted with the repo’s expected analysis/test setup.

## Files Changed

Primary implementation files changed in this prototype include:

- `pubspec.yaml`
- `darwin/camera_avfoundation/Package.swift`
- `darwin/camera_avfoundation.podspec`
- `darwin/camera_avfoundation/Sources/camera_avfoundation/...`
- `ios/camera_avfoundation/Package.swift`
- `ios/camera_avfoundation/Sources/camera_avfoundation/Camera.swift`
- `ios/camera_avfoundation/Sources/camera_avfoundation/CameraConfiguration.swift`
- `ios/camera_avfoundation/Sources/camera_avfoundation/CameraPlugin.swift`
- `ios/camera_avfoundation/Sources/camera_avfoundation/CameraProperties.swift`
- `ios/camera_avfoundation/Sources/camera_avfoundation/DefaultCamera.swift`
- `ios/camera_avfoundation/Sources/camera_avfoundation/DeviceOrientationProvider.swift`
- `ios/camera_avfoundation/Sources/camera_avfoundation/ImageStreamHandler.swift`
- `ios/camera_avfoundation/Sources/camera_avfoundation/SavePhotoDelegate.swift`
- `ios/camera_avfoundation/Sources/camera_avfoundation/CameraPermissionManager.swift`
- `example/macos/...` generated macOS app scaffold and permission changes
- `example/ios/RunnerTests/...` test/mocks updates
- `example/test/main_test.dart`

## Current Validation Results

### Passing

- `flutter_plugin_tools format --packages camera_avfoundation`
- `flutter_plugin_tools analyze --packages camera_avfoundation`
- `flutter_plugin_tools dart-test --packages camera_avfoundation`
- `flutter build macos` from `packages/camera/camera_avfoundation/example`
- iOS native `RunnerTests`:
  - `xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPad (A16)' -only-testing:RunnerTests`

### Not yet verified manually

- Real-device macOS camera preview/photo/video runtime behavior.
- External camera runtime behavior on macOS.
- Long-running audio/video recording behavior on macOS.
- Runtime behavior of unsupported or partially supported device capabilities such as stabilization and advanced camera controls.

## Remaining Risks and Follow-Up Work

These are the remaining items before I would call it PR-ready.

### 1. Runtime validation on macOS

The major compile blockers are resolved, but I have not done human-in-the-loop runtime QA for:

- preview rendering
- still capture
- video recording with audio enabled
- image streaming
- switching cameras
- unplug/replug behavior for external cameras

This is now the main unknown.

### 2. Capability semantics on macOS 10.15

The current implementation deliberately uses wrapper-level fallbacks and `false` capability checks for APIs that are unavailable on macOS 10.15, especially around:

- video stabilization
- some exposure-bias and zoom-related device properties
- newer photo flash APIs on older macOS releases
- iOS-only audio session behavior

That is enough to compile and should be safe, but it needs product-level review for how those limitations should surface to Dart callers.

### 3. Obsolete prototype leftovers should be cleaned up

The old temporary `macos/camera_avfoundation` prototype copy is no longer the intended implementation path once `darwin/` is in use. It should be removed before a PR, along with any other obsolete migration artifacts.

### 4. CocoaPods warnings remain expected for now

Flutter tooling now prefers Swift Packages for these Darwin plugins and emits migration warnings during validation. That is expected based on your requirement to stay on CocoaPods for this PR. It is not a blocker for this branch.

## Apple Guidance: Xcode 26 Era AVFoundation Recommendations

Based on Apple’s current AVFoundation documentation and the Xcode 26-era AVCam sample, the guidance is broadly:

1. Keep one shared capture architecture, not separate end-to-end camera stacks per platform.
2. Put AVFoundation orchestration in a dedicated capture service rather than distributing session mutation across UI code.
3. Treat authorization as an explicit asynchronous step before session setup.
4. Reconfigure sessions atomically with begin/commit configuration when changing modes or devices.
5. Isolate platform and device capability differences behind small seams instead of assuming the same feature set everywhere.
6. Treat external and continuity devices as first-class inputs in macOS capture design.

### Most relevant concrete recommendations

- Apple’s current AVCam sample uses a dedicated capture service actor as the center of the design, explicitly to keep blocking capture work off the main thread and to centralize session state.
- Apple’s capture setup documentation now frames iOS and macOS capture under the same high-level session/input/output architecture.
- Apple’s authorization guidance recommends checking authorization status asynchronously and requesting access only when the user reaches a camera feature.
- Apple’s newer capture setup docs explicitly call out macOS external inputs, including Continuity Camera support in macOS apps.
- AVFoundation updates since the Xcode 26 timeframe emphasize capability-specific features rather than universal assumptions, such as constant color photo capture, background-replacement support on macOS, enhanced stabilization modes, and audio-session mixing behavior.

### What that means for this plugin

- A shared Darwin layout is consistent with Apple’s direction.
- The right pattern is shared capture-session architecture with platform capability adapters, not a forked full macOS implementation unless platform behavior diverges much more than it currently appears to.
- External cameras on macOS should be treated as a normal part of the design surface, not a special afterthought.
- Audio recording should stay in scope for the first PR, but audio-session behavior must remain platform-specific.

## Resolved Product Decisions Used In This Branch

These decisions are now baked into the implementation direction:

1. Use the shared Darwin layout.
2. Support macOS 10.15 minimum.
3. Keep audio recording in scope for the first PR.
4. Stay on CocoaPods for now, despite the current Flutter warning noise.

## Evaluation: Shared Darwin vs Separate macOS Layout

My recommendation is to continue with the shared Darwin layout.

Why:

- The migration did succeed technically.
- The compile blockers were resolved by pushing capability differences into wrappers and guarded code paths, not by discovering an irreconcilable architecture mismatch.
- The remaining work is runtime validation and cleanup, not a structural rescue.
- This aligns with existing first-party plugin patterns in this repo.
- This also aligns with Apple’s current documentation direction: common capture architecture, capability-driven specialization.

When I would reconsider and recommend a separate macOS native layout instead:

- If runtime validation shows too many behavior branches in `DefaultCamera` to keep the shared path readable.
- If external camera support on macOS forces a significantly different session/device model.
- If audio recording diverges enough that the common camera abstraction becomes misleading.

At the current point, I do not think we are there.

## Recommended Next Steps Before PR

1. Remove obsolete temporary migration directories and other no-longer-used native files.
2. Run full repo validation again after that cleanup.
3. Do manual macOS QA for:
  - preview
  - still capture
  - video recording with audio
  - image streaming
  - camera switching
4. Test external cameras on macOS, especially hot-plug and disconnect behavior.
5. Decide how unsupported capability requests should be surfaced to Dart on macOS: explicit errors versus capability-driven absence.

## Commands to Run All Test Levels

Run all commands from the repository root unless otherwise noted.

### Formatting

```sh
export REPO_ROOT=$PWD
dart run $REPO_ROOT/script/tool/bin/flutter_plugin_tools.dart format \
  --clang-format-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang-format \
  --packages camera_avfoundation
```

### Static analysis

```sh
export REPO_ROOT=$PWD
dart run $REPO_ROOT/script/tool/bin/flutter_plugin_tools.dart analyze --packages camera_avfoundation
```

### Dart tests

```sh
export REPO_ROOT=$PWD
dart run $REPO_ROOT/script/tool/bin/flutter_plugin_tools.dart dart-test --packages camera_avfoundation
```

### iOS native unit tests

Run from `packages/camera/camera_avfoundation/example/ios`:

```sh
xcodebuild test \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPad (A16)' \
  -only-testing:RunnerTests
```

### macOS example build

Run from `packages/camera/camera_avfoundation/example`:

```sh
flutter build macos
```

### macOS example run

Run from `packages/camera/camera_avfoundation/example`:

```sh
flutter run -d macos
```

### macOS CocoaPods refresh

Run from `packages/camera/camera_avfoundation/example/macos`:

```sh
pod install
```

### Verbose macOS build for debugging

Run from `packages/camera/camera_avfoundation/example`:

```sh
flutter build macos -v
```

## Step-by-Step Manual Testing and QA

### A. Baseline repository QA

1. Run format.
2. Run analyze.
3. Run Dart tests.
4. Run iOS native `RunnerTests`.
5. Confirm there are no unexpected generated-file diffs after those steps.

### B. iOS regression QA

1. Launch the example on iOS.
2. Grant camera permission.
3. Verify preview appears.
4. Take a still photo.
5. Start and stop video recording.
6. Toggle flash modes.
7. Change focus/exposure points if supported.
8. Lock and unlock capture orientation.
9. Start and stop image streaming.
10. Dispose and recreate the controller.

### C. macOS manual QA once the build compiles

1. Build and launch the macOS example.
2. Confirm the camera permission prompt appears.
3. Confirm the microphone permission prompt appears if audio recording is enabled.
4. Verify the preview renders actual frames.
5. Take a still photo.
6. Start and stop video recording.
7. Start and stop image streaming.
8. If multiple cameras exist, switch between them.
9. If an external camera exists, test it separately from the built-in camera.
10. Quit and relaunch the app to verify permission and initialization stability.

### D. External camera QA on macOS once supported

1. Launch with the external camera already attached.
2. Launch without it attached, then connect it.
3. Select the external camera.
4. Verify preview.
5. Verify still capture.
6. Verify video recording.
7. Verify image streaming.
8. Unplug the active external camera during preview.
9. Unplug during video recording.
10. Unplug during image streaming.
11. Reconnect the device and verify the app can recover.

## How to Build and Run the Example App on macOS

### Current reality on this branch

The commands are:

```sh
cd packages/camera/camera_avfoundation/example
flutter pub get
flutter run -d macos
```

or, for a release-style build:

```sh
cd packages/camera/camera_avfoundation/example
flutter build macos
```

You can also open the native project directly:

```sh
open macos/Runner.xcworkspace
```

Then select the `Runner` scheme and `My Mac` destination in Xcode.

## Bottom Line

This branch moved `camera_avfoundation` from an iOS-only implementation to a shared Darwin implementation that now builds for macOS and stays green on the existing iOS native suite.

The key outcome is not just “macOS compile works”; it is that the shared Darwin approach proved viable without forcing a separate macOS native stack.

The remaining work is now operational and product-facing rather than architectural:

- cleanup
- manual macOS QA
- external camera validation
- deciding capability semantics for macOS-specific gaps

Recommendation: keep the shared Darwin layout.