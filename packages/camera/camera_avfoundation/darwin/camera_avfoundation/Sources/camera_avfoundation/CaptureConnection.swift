// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation

/// A protocol which is a direct passthrough to `AVCaptureConnection`. It exists to allow replacing
/// `AVCaptureConnection` in tests.
protocol CaptureConnection: NSObjectProtocol {
  var avConnection: AVCaptureConnection { get }

  /// Corresponds to the `isVideoMirrored` property of `AVCaptureConnection`
  var isVideoMirrored: Bool { get set }

  /// Corresponds to the `videoOrientation` property of `AVCaptureConnection`
  var videoOrientation: AVCaptureVideoOrientation { get set }

  /// Corresponds to the `inputPorts` property of `AVCaptureConnection`
  var inputPorts: [AVCaptureInput.Port] { get }

  /// Corresponds to the `supportsVideoMirroring` property of `AVCaptureConnection`
  var isVideoMirroringSupported: Bool { get }

  /// Corresponds to the `supportsVideoOrientation` property of `AVCaptureConnection`
  var isVideoOrientationSupported: Bool { get }

  /// Corresponds to the preferredVideoStabilizationMode property of `AVCaptureConnection`
  var preferredVideoStabilizationMode: PlatformVideoStabilizationMode { get set }

}

final class DefaultCaptureConnection: NSObject, CaptureConnection {
  let avConnection: AVCaptureConnection

  init(avConnection: AVCaptureConnection) {
    self.avConnection = avConnection
    super.init()
  }

  var isVideoMirrored: Bool {
    get { avConnection.isVideoMirrored }
    set { avConnection.isVideoMirrored = newValue }
  }

  var videoOrientation: AVCaptureVideoOrientation {
    get { avConnection.videoOrientation }
    set { avConnection.videoOrientation = newValue }
  }

  var inputPorts: [AVCaptureInput.Port] { avConnection.inputPorts }
  var isVideoMirroringSupported: Bool { avConnection.isVideoMirroringSupported }
  var isVideoOrientationSupported: Bool { avConnection.isVideoOrientationSupported }

  var preferredVideoStabilizationMode: PlatformVideoStabilizationMode {
    get {
      #if os(iOS)
        return getPlatformVideoStabilizationMode(avConnection.preferredVideoStabilizationMode)
      #else
        return .off
      #endif
    }
    set {
      #if os(iOS)
        avConnection.preferredVideoStabilizationMode = getAvCaptureVideoStabilizationMode(newValue)
      #endif
    }
  }
}
