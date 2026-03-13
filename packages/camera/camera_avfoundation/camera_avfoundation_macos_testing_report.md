# camera_avfoundation macOS Testing Report

## Automated Validation

Currently green:

- `flutter_plugin_tools format --packages camera_avfoundation`
- `flutter_plugin_tools analyze --packages camera_avfoundation,camera`
- `flutter_plugin_tools dart-test --packages camera_avfoundation`
- iOS native `RunnerTests`
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

## Current Testing Matrix

| Camera | Current displayed name | Still image | Live preview/video | Notes |
| --- | --- | --- | --- | --- |
| 1 | HD Pro Webcam C920 | OK | Rotated 90 degrees left | Device itself appears landscape-capable in native apps |
| 2 | FaceTime HD Camera | OK | Rotated 90 degrees left | Internal Mac camera |
| 3 | kPhone Camera | Rotated 90 degrees right | Rotated 90 degrees left | Continuity/iPhone camera still differs from internal cameras |

Interpretation:

- still-photo orientation is correct for the two non-Continuity cameras tested most recently
- preview orientation is still wrong on all tested cameras
- the Continuity/iPhone camera still has incorrect still-photo orientation as well

## Open Issues

### Orientation

- preview remains rotated 90 degrees left on all tested cameras
- Continuity/iPhone still photos remain rotated 90 degrees right
- image rotation mismatch also causes the preview to appear stretched even though the underlying width/height values are correct

### Audio

- after repeated camera switching in earlier manual testing, loud white noise played from the MacBook speakers for roughly 20 seconds
- as a mitigation, audio is currently disabled by default on macOS in the example
- explicit macOS audio testing is still needed before enabling it again

### Example video thumbnail crash

Manual testing surfaced an example-side error while rendering the thumbnail video player:

- `Bad state: No active player with ID 1.`

This appears to be a `video_player` lifecycle issue in the example app rather than a core camera capture failure. The example has been hardened to clear old video controllers earlier, but this should still be rechecked manually.

### macOS startup warning

The startup log still includes:

- `objc[...]: class 'NSKVONotifying_AVCapturePhotoOutput' not linked into application`

It does not currently appear to block preview or still capture, so it remains a secondary issue.

## Example-Only Debugging Notes

- the selector now uses real macOS camera names when available
- if names are unique, the old cryptic ID suffixes are no longer shown
- capability-dependent interactions such as focus/exposure taps are guarded in the example app

## Next Manual Checks

1. Recheck preview orientation on all three cameras after the latest preview/layout changes.
2. Recheck still-photo orientation on the Continuity/iPhone camera.
3. Confirm that the `VideoPlayer` thumbnail crash no longer occurs.
4. If audio is re-enabled for testing, explicitly test for speaker noise during camera switching.