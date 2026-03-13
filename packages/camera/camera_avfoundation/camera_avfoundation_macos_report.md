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

## Prototype Comparison

There are two relevant earlier prototypes, and they should be distinguished clearly.

### Christoph's iOS external-camera prototype

Your `ios-support-external-cameras` branch was an iOS/iPadOS external-camera prototype.

What it demonstrated:

- external-camera discovery can be added within the existing AVFoundation camera architecture
- disconnect handling can also be layered into that same architecture
- the external-camera work looks like an additive feature, not a sign that the capture model itself needs to be replaced

This branch does not yet carry forward that external-camera discovery/disconnect behavior into the active shared implementation.

### Stuart's earlier macOS prototype

Stuart's earlier macOS prototype is the outdated `macos-camera` work and compare view referenced in the issue comments, not `ios-support-external-cameras`.

What Stuart said in the issue:

- the expected direction is to extend `camera_avfoundation`
- his earlier `macos-camera` diff is an outdated example of that expected approach
- that prototype compiled, but did not work correctly yet
- specifically, the preview was blank and taking a picture returned an `NSError`, suggesting capture configuration problems rather than a fundamental architectural mismatch

### Conclusion from the comparison

Taken together, these earlier prototypes do not suggest that macOS support needs a separate session or device architecture.

Why:

- your iOS external-camera prototype showed that external-camera support fits into the existing AVFoundation model
- Stuart's macOS prototype pointed in the same high-level direction: extend `camera_avfoundation`, not create a separate long-term implementation
- the main problems in Stuart's WIP were runtime capture configuration issues, not evidence that shared Darwin architecture is the wrong model

So the answer to the architecture question remains: no, the earlier prototypes do not suggest that macOS external-camera support forces a significantly different session/device architecture.

## Recommendation

Keep the shared Darwin layout.

The evidence so far points to:

- one shared AVFoundation capture architecture,
- plus platform-specific capability adapters,
- plus explicit handling for external-device discovery and disconnects.

That is consistent with both the current implementation and the earlier external-camera prototype.

## Proposed 3 PR Split

If the full branch is too large to review comfortably, the cleanest split is three PRs.

### PR 1: Internal refactor only

Goal:

- land the shared-camera-path cleanup without claiming macOS support yet

Scope:

- platform-neutral orientation refactor
- AVFoundation wrapper/protocol reshaping
- iOS test updates required by those refactors

Why this helps:

- reviewers can treat it as internal cleanup with existing behavior preserved
- it removes most of the logic churn from the macOS feature PR

### PR 2: Shared Darwin plumbing

Goal:

- switch the package to the shared Darwin layout and remove the obsolete temporary native copy

Scope:

- `sharedDarwinSource: true`
- `darwin/` package and podspec
- conditional `Flutter` / `FlutterMacOS` import plumbing
- example/build wiring needed for the shared Darwin structure
- delete the obsolete temporary `macos/` implementation copy

Why this helps:

- reviewers can focus on repo structure and packaging changes separately from runtime camera behavior

### PR 3: macOS support

Goal:

- land the actual user-visible macOS support

Scope:

- macOS example host and entitlements
- macOS-specific capability handling and guarded fallbacks
- docs, changelog, and release metadata
- final manual QA results

Why this helps:

- the final PR becomes a focused review of macOS behavior rather than a giant mixed refactor

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

Compared with the earlier prototypes, the approach is mostly the same at the capture-model level and different mainly in scope: your `ios-support-external-cameras` branch was a narrower iOS external-camera prototype, while Stuart's `macos-camera` work was an outdated macOS WIP showing the expected extension point for `camera_avfoundation`.

Recommendation: keep the shared Darwin layout, finish manual QA, and then decide whether to port the earlier external-camera discovery/disconnect behavior from your iOS prototype into the shared implementation before opening the PR.
