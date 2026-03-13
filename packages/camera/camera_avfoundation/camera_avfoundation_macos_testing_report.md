# camera_avfoundation macOS Testing Report

## Automated Validation

The following checks are currently green:

- `flutter_plugin_tools format --packages camera_avfoundation`
- `flutter_plugin_tools analyze --packages camera_avfoundation`
- `flutter_plugin_tools dart-test --packages camera_avfoundation`
- iOS native `RunnerTests` pass
- `flutter build macos` succeeds for the example app

These results show that the package is structurally healthy and that the shared Darwin migration did not break the existing iOS native test suite.

## Example App Debugging Added

To make macOS manual testing easier, the example app now includes additional debug output:

- the camera selector shows labels instead of only icons
- a debug status panel is shown below the preview area
- if exactly one camera is detected, the example auto-selects it
- enumeration, selection, and initialization are logged with `CameraExample:` prefixes

This makes it possible to see whether the plugin is finding cameras and whether the controller reaches the initialized state, even if the preview itself is black.

## Current Manual macOS Findings

Using `flutter run -d macos` on the example app, the following behavior was observed:

- the example launches successfully in debug mode
- the app reports one available camera
- that camera is currently surfaced as `external:<UUID>`
- the example auto-selects the camera
- the controller reaches the initialized state
- the preview widget builds a `Texture`
- the preview remains black
- taking a picture fails with `PlatformException(Error -11800, The operation could not be completed, AVFoundationErrorDomain, null)`
- a video playback failure was also reported after the failed capture flow

Relevant log lines observed during debugging include:

- `CameraExample: availableCameras returned 1: external:...`
- `CameraExample: Selected external:...`
- `CameraExample: Initializing external:...`
- `CameraExample: Initialized external:...`
- `objc[...] class 'NSKVONotifying_AVCapturePhotoOutput' not linked into application`

## Interpretation So Far

The current failure is no longer in camera enumeration or controller initialization.

What appears to be working:

- camera discovery
- camera selection
- controller initialization on the Dart side
- texture creation on the Flutter side

What appears to be broken:

- native preview frame delivery and/or rendering on macOS
- still capture on macOS

That means the remaining problem is now concentrated in the native macOS AVFoundation runtime path rather than package wiring, permissions metadata, or basic Flutter integration.

## Next Investigation Focus

The most useful next debugging steps are:

1. Instrument the native sample-buffer path to verify whether `captureOutput(_:didOutput:from:)` is receiving frames.
2. Instrument the texture path to verify whether `copyPixelBuffer()` is being called and returning buffers.
3. Inspect macOS-specific session/output configuration for anything that can cause a running session with no visible preview.
4. Inspect the still-capture path around `AVCapturePhotoOutput` and photo settings to understand the `-11800` failure.

## Current Ask for Manual QA

Manual help may still be useful later for:

- verifying behavior with different physical cameras
- checking whether the camera permission prompt ever appears after app bundle resets
- validating preview/photo/video behavior once the native fix is in place

At this point, however, the next step is primarily engineering investigation rather than manual testing.

## Follow-Up Investigation Result

After additional native instrumentation, the macOS capture path was changed from the iOS-style manual `addInputWithNoConnections` / `addOutputWithNoConnections` / `addConnection` setup to a simpler macOS-specific automatic `addInput` / `addOutput` session wiring path.

That change produced the first clear evidence of progress:

- the session still starts successfully
- the macOS video connection now exists
- the first video frame is received in `captureOutput(_:didOutput:from:)`
- `copyPixelBuffer()` is called with a real pixel buffer

Relevant native log lines after the change:

- `camera_avfoundation: macOS auto-wired videoConnectionExists=true photoConnectionExists=true`
- `camera_avfoundation: first video frame width=1080 height=1920 pixelFormat=1111970369`
- `camera_avfoundation: copyPixelBuffer width=1080 height=1920 pixelFormat=1111970369`

Interpretation:

- the earlier black preview was very likely caused by the manual connection setup not delivering frames on macOS
- the updated macOS wiring appears to unblock frame delivery to the Flutter texture path

This still needs visual confirmation in the app window and photo-capture retesting, but it is the first concrete native fix that moved the failure forward rather than only adding diagnostics.

## Latest Manual QA Result

Latest manual testing on a MacBook now shows the following:

- live preview is visible again
- still capture succeeds and writes JPEGs to disk
- the black-preview issue is resolved by the macOS-specific automatic session wiring change

However, two follow-up issues remain:

- the preview is rotated by 90 degrees and was previously squeezed into the wrong aspect ratio
- captured JPEGs are portrait-shaped (`1080 x 1920`) with no orientation metadata, so they also need normalization for desktop display

The current branch now includes follow-up fixes aimed at those two issues:

- macOS preview rotation/aspect handling in the preview widgets
- macOS photo-data normalization before writing captured JPEGs to disk

Follow-up manual testing showed that those first rotation fixes were directionally wrong:

- the preview remained sideways
- the saved image became upside down

The current branch now contains a second correction pass:

- macOS preview rotation direction has been reversed
- macOS photo normalization rotation direction has also been reversed

Those updated fixes need one more fresh manual confirmation run.

## macOS Camera Label Semantics

The built-in MacBook camera is currently surfaced by the plugin as `external`.

Why this is happening:

- the AVFoundation device reports as `AVCaptureDeviceTypeBuiltInWideAngleCamera`
- its reported position is effectively unspecified on macOS rather than `front`
- the current plugin mapping treats unspecified position as `external`

This is confusing for laptops, even though it is consistent with the current plugin mapping.

For now:

- the example UI has been adjusted to show a more neutral `camera` label on macOS rather than exposing `external` directly in the selector
- the underlying plugin behavior should still be revisited before PR, especially after testing with a real external USB camera

## External Camera Testing Recommendation

Testing with a real external USB camera would be useful, but not as a reason to merge in the external-camera spike yet.

Recommended order:

1. confirm the built-in macOS camera path is correct for preview and still capture orientation
2. connect the USB camera and see how the current macOS implementation enumerates and behaves with two devices
3. only then decide whether external-camera-specific code from the earlier spike is actually needed for macOS, or whether the current branch already handles most of it

So yes: plugging in the USB camera is a good next test. No: I would not pull in the external-camera spike yet, because it would mix a new feature branch into code that is still stabilizing the base macOS path.

## External Camera Discovery Status

The initial macOS implementation only asked AVFoundation for `.builtInWideAngleCamera`, which explains why Photo Booth could see additional cameras while the Flutter example could not.

The current branch now expands macOS discovery to include:

- `.builtInWideAngleCamera`
- `.externalUnknown`

That should make USB and other externally-reported macOS cameras discoverable if AVFoundation reports them through the standard external device type.

This still needs manual confirmation with the USB camera connected.

Manual testing has now confirmed that the expanded discovery works:

- the example can now enumerate three cameras on macOS
- external USB-style devices are now discoverable
- a Continuity/iPhone camera is also surfacing through the current discovery path

So external-camera discovery is no longer blocked at the basic enumeration level.

## Note on `NSKVONotifying_AVCapturePhotoOutput`

The log line:

- `objc[...]: class 'NSKVONotifying_AVCapturePhotoOutput' not linked into application`

is still appearing during startup.

At this point it does not appear to be the root cause of the main failures, because:

- preview now receives real frames
- still capture now returns photo data successfully

It should be kept in mind as a potential implementation smell, but it is not currently the highest-priority blocker.

## New Issues Found During Multi-Camera Testing

Once multiple cameras were available and camera switching was exercised more heavily, several new issues became visible.

### 1. Camera selector UX is not acceptable yet

Problems observed:

- the old selector layout wrapped awkwardly on macOS
- showing every camera as just `camera` made the list hard to use
- users could not reliably tell which option corresponded to which physical camera

The example UI has now been improved to:

- use a horizontally scrollable selector row
- use shorter indexed labels
- include shortened camera ID suffixes so cameras can be distinguished visually

This is an example-only debugging and usability improvement, not a final product decision for the plugin API.

### 2. Camera switching produced disposed-controller exceptions

New runtime issue observed during repeated camera switching:

- `A CameraController was used after being disposed.`

The stack traces point to asynchronous initialization work in the example controller continuing after the controller had been invalidated or replaced.

The example controller has now been updated to:

- invalidate stale initialization work with an incrementing token
- cancel and replace the orientation subscription during reinitialization
- dispose the previous native camera before creating a replacement one
- guard async callbacks from writing state after disposal

This should eliminate the specific stale-callback race seen in the logs, but still needs confirmation in another manual multi-camera switching run.

### 3. Preview orientation is still not fully correct

Current state:

- live preview works
- still capture works
- external discovery works
- preview orientation remains incorrect for some or all macOS cameras

The preview rotation implementation has been revised again to use a more explicit fitted/rotated layout rather than the earlier simpler `RotatedBox` path, but this still needs manual confirmation.

### 4. Saved-photo orientation is only partially fixed

Current state from manual testing:

- internal Mac cameras now appear to produce correctly-oriented saved photos
- at least one external/Continuity camera still appears to produce incorrectly-oriented saved photos

That suggests that the current normalization is not universally correct across all macOS camera types, and photo-orientation handling likely needs to become more device- or metadata-aware instead of assuming one fixed rotation rule.