# camera_avfoundation macOS Orientation Fix Analysis

## Problem

Preview is rotated 90° left on all tested macOS cameras. Still photos from Continuity/iPhone cameras are also rotated incorrectly.

## Root Cause

Two interacting issues in the current code:

1. **`DeviceOrientationProvider.swift`** hardcodes macOS device orientation to `.landscapeLeft` (macOS has no gyroscope).
2. **`DefaultCamera.videoOrientation(forDeviceOrientation:)`** maps `.landscapeLeft` → `AVCaptureVideoOrientation.landscapeRight`. This swap is correct on iOS (compensating for physical device rotation) but wrong on macOS where cameras are fixed-position.

The result: every macOS capture connection gets `videoOrientation = .landscapeRight`, which instructs AVFoundation to rotate all delivered pixel buffers by 90°.

Additionally, **`SavePhotoDelegate.normalizedPhotoDataForMacOS()`** applies a blanket -90° CGContext rotation to any photo where `height > width`. This is a compensation hack that works for some cameras but fails for Continuity/iPhone cameras and will conflict with any connection-level fix.

## Fix: Use `videoRotationAngle` on macOS (Option B)

### What changes

On macOS, use `AVCaptureConnection.videoRotationAngle` (available macOS 14.0+) instead of the deprecated `videoOrientation` enum. Set the angle to `0` for the natural sensor orientation (correct for fixed-position macOS cameras).

For macOS < 14.0 (deployment target is 10.15), fall back to `videoOrientation = .portrait` which is the identity orientation.

Remove `normalizedPhotoDataForMacOS()` since the connection-level fix makes it unnecessary — photos will be captured with correct orientation from the source.

### Files changed

| File | Change |
|------|--------|
| `DefaultCamera.swift` | macOS branch in `updateOrientation(_:forCaptureOutput:)` using `videoRotationAngle` |
| `CaptureConnection.swift` | Add `videoRotationAngle` and `isVideoRotationAngleSupported(_:)` to the protocol |
| `SavePhotoDelegate.swift` | Remove `normalizedPhotoDataForMacOS()` and its call site |
| `MockCaptureConnection.swift` | Add mock implementations for new protocol members |

### What does NOT change

| Aspect | Status |
|--------|--------|
| iOS behavior | Completely unchanged — all macOS code is behind `#if os(macOS)` |
| Public Dart API | No change — `lockCaptureOrientation()`, `unlockCaptureOrientation()`, `DeviceOrientation` enum all stay the same |
| Pigeon interface | No change — `PlatformDeviceOrientation` enum and host API unchanged |
| iOS native tests | Unchanged — orientation tests use `MockCaptureConnection` which is iOS-only |

## Performance Analysis: `videoRotationAngle` vs `videoOrientation`

Both `videoRotationAngle` and `videoOrientation` are properties on `AVCaptureConnection`. They control how AVFoundation's internal pipeline delivers frames. The rotation happens inside the hardware-accelerated capture pipeline before the pixel buffer reaches the app.

| Aspect | `videoOrientation` (enum) | `videoRotationAngle` (CGFloat) |
|--------|--------------------------|-------------------------------|
| Where rotation happens | AVFoundation internal pipeline | AVFoundation internal pipeline |
| Hardware acceleration | Yes (same pipeline) | Yes (same pipeline) |
| Per-frame CPU cost | None (applied at source) | None (applied at source) |
| API status | Deprecated (iOS 17+ / macOS 14+) | Replacement API (iOS 17+ / macOS 14+) |
| Allowed values | 4 enum values | Discrete: 0, 90, 180, 270 |

**There is no performance difference.** Both APIs configure the same underlying hardware rotation in the capture pipeline. Apple introduced `videoRotationAngle` as a clearer replacement for `videoOrientation`, not as a different mechanism. The pixel buffer delivered to `copyPixelBuffer()` is already rotated by the hardware in both cases — there is no additional CPU-side image manipulation.

The `camera_macos` third-party package has been shipping with `videoRotationAngle` and shows no performance issues in its frame delivery path.

## Public API Impact

### Will this break users?

**No.** The changes are entirely inside the native AVFoundation layer and do not affect:

- The public `CameraController` API (`lockCaptureOrientation()`, `unlockCaptureOrientation()`)
- The `DeviceOrientation` enum values
- The `CameraValue` properties (`lockedCaptureOrientation`, `deviceOrientation`)
- The `CameraPreview` widget
- The Pigeon-generated platform channel interface

On macOS, `lockCaptureOrientation()` will continue to work. When a user locks to a specific orientation, the fix maps that orientation to the correct `videoRotationAngle` value for macOS.

On iOS, nothing changes at all — all new code is behind `#if os(macOS)` or `#available(macOS 14.0, *)` guards.

### Edge case: macOS < 14.0

The deployment target is macOS 10.15. For macOS versions older than 14.0:

- `videoRotationAngle` is unavailable
- The fallback uses `videoOrientation = .portrait` (identity orientation)
- This is correct for fixed-position macOS cameras and is better than the current `.landscapeRight` behavior

In practice, Flutter's macOS support and the macOS devices in active use make macOS < 14.0 a diminishing edge case, but it remains handled.
