## Plan: External Cameras, Camera List Changes, and macOS in camera_avfoundation

Split the work into three PRs. PR 1 should go first. After that, PR 2 and PR 3 should be treated as independent and can proceed in either order.

This split matches the upstream issue structure and maintainer guidance:
- flutter/flutter#130073 tracks external camera support on iOS and captures the finding that adding external discovery was enough for preview, but not enough for still capture.
- flutter/packages#5892 was an older Objective-C PR that mainly added external camera discovery on iOS 17+, but it did not solve the full runtime problem and now needs a Swift-native reimplementation rather than revival.
- flutter/flutter#142239 treats camera list change notifications as a separate API feature.
- flutter/flutter#41708 indicates that macOS support should extend camera_avfoundation rather than become a separate plugin.

**Execution order**
1. PR 1: iPadOS external camera support in camera_avfoundation.
2. PR 2 or PR 3: camera list change notifications and macOS support can proceed independently after PR 1.

**Platform notes**
- Apple’s WWDC session and AVCam sample material describe support for external cameras in iPadOS apps, not iPhone apps. The Flutter issue discussion also consistently talks about iPad USB-C devices rather than iPhone. For planning purposes, this should be treated as iPadOS support, not general iPhone support.
- Apple’s sample material shows switching between built-in and external cameras by explicitly reconfiguring the capture session to a chosen device. It does not document an automatic fallback to one of the built-in cameras when an external camera is unplugged. The safe assumption for Flutter is therefore: do not rely on automatic platform fallback; detect disconnect, stop using the missing device, and surface an error so the app can decide whether to stop preview or switch cameras.
- The old Flutter Objective-C PR effectively added external camera discovery. The issue discussion and Apple guidance both suggest that full support requires more than discovery: capture paths and runtime handling must also be validated.
- Android already has some external camera groundwork in both Android implementations. packages/camera/camera_android maps `CameraMetadata.LENS_FACING_EXTERNAL` in `CameraUtils` and includes those devices in `getAvailableCameras`. packages/camera/camera_android_camerax also exposes external cameras through CameraX lens-facing enums and selectors. What is still missing there is dynamic device-list handling and hotplug notifications, not the basic concept of an external lens direction.

---

## PR 1: iPadOS External Camera Support

**Goal**
Make a Flutter app able to use an already-plugged-in external USB camera on iPadOS through camera_avfoundation, with best-effort feature support where the hardware allows it, and no crash when the camera is unplugged.

**Implementation plan**
1. Implement this in the current Swift code only. Use flutter/packages#5892 and flutter/flutter#130073 as design context, not as code to port.
2. Extend discovery in packages/camera/camera_avfoundation/ios/camera_avfoundation/Sources/camera_avfoundation/CameraDeviceDiscoverer.swift so external-capable device types can be requested in a reusable way.
3. Update packages/camera/camera_avfoundation/ios/camera_avfoundation/Sources/camera_avfoundation/CameraPlugin.swift so `getAvailableCameras` includes external camera device types on supported iPadOS versions while preserving the current Flutter-facing shape.
4. Keep the public contract stable by continuing to use `lensDirection.external`. Prefer leaving lens type as unknown unless AVFoundation gives a clearly reliable mapping.
5. Replace fragile camera lookup during initialization so a camera disappearing between enumeration and selection fails with a surfaced error instead of crashing.
6. Harden packages/camera/camera_avfoundation/ios/camera_avfoundation/Sources/camera_avfoundation/DefaultCamera.swift for external-device capability differences such as flash, torch, focus, exposure, mirroring, and format selection.
7. Validate the full capture path, not just preview: `takePicture`, `startVideoRecording`, `stopVideoRecording`, image streaming, and `updateDescriptionWhileRecording` should all work when the hardware supports them.
8. Add explicit disconnect handling for the active external camera. The plugin should report an error and stop using the missing device. The app can then decide whether to stop preview or switch to a built-in camera.
9. Add focused Swift tests for external enumeration, vanished-device initialization failure, per-feature fallback behavior, and disconnect error propagation.
10. Update packages/camera/camera_avfoundation/pubspec.yaml, packages/camera/camera_avfoundation/CHANGELOG.md, and packages/camera/camera_avfoundation/README.md.

**Files most likely to change**
- packages/camera/camera_avfoundation/ios/camera_avfoundation/Sources/camera_avfoundation/CameraPlugin.swift
- packages/camera/camera_avfoundation/ios/camera_avfoundation/Sources/camera_avfoundation/CameraDeviceDiscoverer.swift
- packages/camera/camera_avfoundation/ios/camera_avfoundation/Sources/camera_avfoundation/DefaultCamera.swift
- packages/camera/camera_avfoundation/example/ios/RunnerTests/AvailableCamerasTests.swift
- packages/camera/camera_avfoundation/example/ios/RunnerTests/Mocks/MockCameraDeviceDiscoverer.swift
- packages/camera/camera_avfoundation/example/ios/RunnerTests/Mocks/MockCaptureDevice.swift
- packages/camera/camera_avfoundation/README.md
- packages/camera/camera_avfoundation/pubspec.yaml
- packages/camera/camera_avfoundation/CHANGELOG.md

**Short questions for PR 1**
1. Should the plugin only report the disconnect error and stop preview, or should it also try to leave enough state for the app to switch to a built-in camera without recreating everything?
2. Does the team want any narrower scope for PR 1 if a specific feature, such as still capture on some external cameras, turns out to need follow-up work?

---

## PR 2: Camera List Change Notifications

**Goal**
Add a camera-plugin API so apps can observe that the available device list changed instead of polling `availableCameras`.

**Implementation plan**
1. Treat this as a separate API feature, consistent with flutter/flutter#142239.
2. Design the API so it works for iPadOS external cameras immediately and can also support macOS, web, Windows, and Android dynamic devices.
3. Hook the iOS AVFoundation implementation to device connection and disconnection events so the plugin can publish device-list changes.
4. Add tests and example coverage for dynamic camera availability.

**Two likely API shapes**
1. Global stream or callback on the camera plugin surface. This is the simplest mental model for clients that only need to know “the list changed; re-run availableCameras”.
2. Controller-scoped or lifecycle-scoped notifications. This could be more structured, but it is harder to reason about because camera list changes are global device state, not state owned by one active controller.

**Current recommendation**
Prefer the global stream or callback model unless maintainers have a strong reason to tie this to controller lifecycle.

**Files likely to change**
- packages/camera/camera_platform_interface/lib/src/platform_interface/camera_platform.dart
- packages/camera/camera/lib
- packages/camera/camera_avfoundation/pigeons/messages.dart
- packages/camera/camera_avfoundation/ios/camera_avfoundation/Sources/camera_avfoundation
- packages/camera/camera/example/lib/main.dart

**Short questions for PR 2**
1. Does the team prefer a global stream or callback for camera list changes, or is there another API shape they want explored?
2. Should the API promise only “the list changed”, or should it also try to describe which camera was added or removed?

---

TODO: prototype new PR with MacOS support starting from main:


## PR 3: macOS Support in camera_avfoundation

**Goal**
Extend camera_avfoundation to macOS, using the same AVFoundation package rather than creating a separate macOS implementation package.

**Implementation plan**
1. Follow the direction in flutter/flutter#41708: extend camera_avfoundation.
2. Reuse the discovery and capability abstractions from PR 1. Reuse PR 2 if the camera-list API is already settled, but do not block macOS support on PR 2 if that API discussion takes longer.
3. Refactor iOS-specific assumptions such as device orientation handling where needed.
4. Add macOS registration, entitlements, test setup, docs, and package metadata updates once the implementation is stable.

**Files likely to change**
- packages/camera/camera_avfoundation/pubspec.yaml
- packages/camera/camera_avfoundation/ios/camera_avfoundation/Sources/camera_avfoundation
- packages/camera/camera_avfoundation/README.md
- packages/camera/camera_avfoundation/example

**Short questions for PR 3**
1. Is there any preferred minimum macOS version or test strategy the maintainers want before implementation starts?
2. If PR 2 is still under API discussion, is it acceptable for PR 3 to land first with macOS support but without a new camera-list notification API?

---

## Verification

1. Run formatting, analysis, and relevant tests for camera_avfoundation for each PR.
2. For PR 1, manually validate on the iPad with the Logitech USB camera in these states: connected before app launch, connected after launch, selected for preview, photo capture, video recording, image streaming, unplug during preview, unplug during recording, unplug during stream, background and foreground with external selected, reconnect after disconnect.
3. Confirm that PR 1 does not crash when the external camera is unplugged and that the app can respond sensibly after the surfaced error.

---

## Copy-Paste Questions for Maintainers

1. We plan to split this into three PRs: PR 1 for iPadOS external camera support, PR 2 for camera list change notifications, and PR 3 for macOS support. PR 1 will go first; PR 2 and PR 3 would then proceed independently. Does that sound right?
2. For PR 1, we plan best-effort feature support for external cameras where hardware allows it, and an error if the active external camera is unplugged rather than silent plugin fallback. Is that the intended behavior?
3. For PR 1, if the active external camera is unplugged, do maintainers want the plugin to only surface an error and stop preview, or should it also try to make switching to a built-in camera easier for the app?
4. For PR 2, would maintainers prefer a global stream or callback for camera list changes, or another API shape?
5. For PR 3, if the camera-list API discussion takes longer, is it acceptable for macOS support to proceed independently rather than waiting for PR 2?