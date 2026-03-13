# camera_avfoundation macOS Testing Report

## Automated Validation

Currently green:

- `flutter_plugin_tools format --packages camera_avfoundation`
- `flutter_plugin_tools analyze --packages camera_avfoundation,camera`
- `flutter_plugin_tools dart-test --packages camera_avfoundation`
- iOS native `RunnerTests` (129 tests)
- `flutter build macos` for the example app

## Confirmed Working

- shared Darwin package builds on macOS
- preview is no longer black
- still capture works
- multiple macOS cameras are now discovered
- camera order matches the native Photo Booth app in current manual testing
- localized camera names are now shown in the example selector
- rapid camera switching no longer reproduces the earlier disposed-controller crash
- unsupported tap-to-focus/exposure no longer throws on the iPhone camera

## Orientation Fix Applied

Root cause: `DeviceOrientationProvider` hardcoded `.landscapeLeft` on macOS, which the iOS-designed
orientation mapper translated to `AVCaptureVideoOrientation.landscapeRight`, introducing an unwanted
90° rotation on fixed-position macOS cameras.

Fix: on macOS 14+, use `AVCaptureConnection.videoRotationAngle = 0` (identity) instead of the
deprecated `videoOrientation` enum. For macOS < 14.0, fall back to `.portrait` (identity).
Also removed the `normalizedPhotoDataForMacOS()` workaround from `SavePhotoDelegate` that was
applying a blanket -90° CGContext rotation to photos.

See [camera_avfoundation_macos_orientation_analysis.md](camera_avfoundation_macos_orientation_analysis.md) for the full analysis.

## Current Testing Matrix (needs manual re-verification)

| Camera | Current displayed name | Still image | Live preview/video | Notes |
| --- | --- | --- | --- | --- |
| 1 | HD Pro Webcam C920 | Needs recheck | Needs recheck | Was rotated 90° left before fix |
| 2 | FaceTime HD Camera | Needs recheck | Needs recheck | Was rotated 90° left before fix |
| 3 | kPhone Camera | Needs recheck | Needs recheck | Was rotated 90° in both directions before fix |

## Open Issues

### Audio

- after repeated camera switching in earlier manual testing, loud white noise played from the MacBook speakers for roughly 20 seconds
- as a mitigation, audio is currently disabled by default on macOS in the example (`enableAudio = !Platform.isMacOS`)
- macOS has no `AVAudioSession` — unlike iOS, there is no session category to configure; audio capture is set up directly via `AVCaptureAudioDataOutput` on the `audioCaptureSession`
- the white noise likely came from a feedback loop between mic input and speaker output, since macOS does not have the `AVAudioSession.setCategory(.playAndRecord, options: .defaultToSpeaker)` separation that iOS uses
- this is a known platform difference; fixing it properly would require either routing audio output explicitly or keeping audio disabled until a recording starts
- **Impact**: low — audio defaults to off, users can toggle it on via the example UI when they want to test recording with audio

### Example video thumbnail crash

- `Bad state: No active player with ID 1.` error from `video_player_avfoundation`
- occurs when the `VideoPlayerController` tries to interact with a player that has already been disposed
- the example code disposes the old controller during `_startVideoPlayer()` after initializing the new one, but there is a race: the listener callback may fire after disposal
- **Impact**: example-only, does not affect the plugin — the thumbnail just fails to display
- **Possible fix**: guard the listener callback with a `mounted` and controller identity check before accessing the video controller

### macOS startup warning

- `objc[...]: class 'NSKVONotifying_AVCapturePhotoOutput' not linked into application`
- appears on startup in the console log
- does not block preview or still capture
- likely a KVO observation side-effect from AVFoundation's internal implementation
- **Impact**: cosmetic log noise only

## Example-Only Debugging Notes

- the selector now uses real macOS camera names when available
- if names are unique, the old cryptic ID suffixes are no longer shown
- capability-dependent interactions such as focus/exposure taps are guarded in the example app

## Next Manual Checks

1. Recheck preview orientation on all three cameras after the `videoRotationAngle` fix.
2. Recheck still-photo orientation on all cameras, especially the Continuity/iPhone camera.
3. Confirm that still photos are written to disk (check the path shown in the snack bar).
4. Confirm that the `VideoPlayer` thumbnail crash no longer occurs, or reproduces consistently.
5. If audio is re-enabled for testing, explicitly test for speaker noise during camera switching.