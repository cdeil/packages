// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation

/// A protocol which is a direct passthrough to `AVCaptureOutput`. It exists to allow mocking
/// `AVCaptureOutput` in tests.
protocol CaptureOutput {
  /// Returns a connection with the specified media type, or nil if no such connection exists.
  func connection(with mediaType: AVMediaType) -> CaptureConnection?
}

/// A protocol which is a direct passthrough to `AVCaptureVideoDataOutput`. It exists to allow
/// mocking `AVCaptureVideoDataOutput` in tests.
protocol CaptureVideoDataOutput: CaptureOutput {
  /// The underlying instance of `AVCaptureVideoDataOutput`.
  var avOutput: AVCaptureVideoDataOutput { get }

  /// Corresponds to the `alwaysDiscardsLateVideoFrames` property of `AVCaptureVideoDataOutput`
  var alwaysDiscardsLateVideoFrames: Bool { get set }

  /// Corresponds to the `availableVideoPixelFormatTypes` property of `AVCaptureVideoDataOutput`
  var availableVideoPixelFormatTypes: [FourCharCode] { get }

  /// Corresponds to the `videoSettings` property of `AVCaptureVideoDataOutput`
  var videoSettings: [String: Any]! { get set }

  /// Corresponds to the `setSampleBufferDelegate` method of `AVCaptureVideoDataOutput`
  func setSampleBufferDelegate(
    _ sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?,
    queue sampleBufferCallbackQueue: DispatchQueue?
  )
}

final class DefaultCaptureVideoDataOutput: NSObject, CaptureVideoDataOutput {
  let avOutput: AVCaptureVideoDataOutput

  init(avOutput: AVCaptureVideoDataOutput) {
    self.avOutput = avOutput
    super.init()
  }

  var alwaysDiscardsLateVideoFrames: Bool {
    get { avOutput.alwaysDiscardsLateVideoFrames }
    set { avOutput.alwaysDiscardsLateVideoFrames = newValue }
  }

  var availableVideoPixelFormatTypes: [FourCharCode] { avOutput.availableVideoPixelFormatTypes }

  var videoSettings: [String: Any]! {
    get { avOutput.videoSettings }
    set { avOutput.videoSettings = newValue }
  }

  func setSampleBufferDelegate(
    _ sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?,
    queue sampleBufferCallbackQueue: DispatchQueue?
  ) {
    avOutput.setSampleBufferDelegate(sampleBufferDelegate, queue: sampleBufferCallbackQueue)
  }

  func connection(with mediaType: AVMediaType) -> CaptureConnection? {
    let rawOutput: AVCaptureOutput = avOutput
    guard let connection = rawOutput.connection(with: mediaType) else { return nil }
    return DefaultCaptureConnection(avConnection: connection)
  }
}

/// A protocol which is a direct passthrough to `AVCapturePhotoOutput`. It exists to allow mocking
/// `AVCapturePhotoOutput` in tests.
protocol CapturePhotoOutput: CaptureOutput {
  /// The underlying instance of `AVCapturePhotoOutput`.
  var avOutput: AVCapturePhotoOutput { get }

  /// Corresponds to the `availablePhotoCodecTypes` property of `AVCapturePhotoOutput`
  var availablePhotoCodecTypes: [AVVideoCodecType] { get }

  /// Corresponds to the `isHighResolutionCaptureEnabled` property of `AVCapturePhotoOutput`
  var isHighResolutionCaptureEnabled: Bool { get set }

  /// Corresponds to the `supportedFlashModes` property of `AVCapturePhotoOutput`
  var supportedFlashModes: [AVCaptureDevice.FlashMode] { get }

  /// Corresponds to the `capturePhotoWithSettings` method of `AVCapturePhotoOutput`
  func capturePhoto(with settings: AVCapturePhotoSettings, delegate: AVCapturePhotoCaptureDelegate)
}

final class DefaultCapturePhotoOutput: NSObject, CapturePhotoOutput {
  let avOutput: AVCapturePhotoOutput

  init(avOutput: AVCapturePhotoOutput) {
    self.avOutput = avOutput
    super.init()
  }

  var availablePhotoCodecTypes: [AVVideoCodecType] { avOutput.availablePhotoCodecTypes }

  var isHighResolutionCaptureEnabled: Bool {
    get { avOutput.isHighResolutionCaptureEnabled }
    set { avOutput.isHighResolutionCaptureEnabled = newValue }
  }

  var supportedFlashModes: [AVCaptureDevice.FlashMode] {
    #if os(iOS)
      return avOutput.supportedFlashModes
    #else
      if #available(macOS 13.0, *) {
        return avOutput.supportedFlashModes
      }
      return []
    #endif
  }

  func capturePhoto(with settings: AVCapturePhotoSettings, delegate: AVCapturePhotoCaptureDelegate)
  {
    avOutput.capturePhoto(with: settings, delegate: delegate)
  }

  func connection(with mediaType: AVMediaType) -> CaptureConnection? {
    let rawOutput: AVCaptureOutput = avOutput
    guard let connection = rawOutput.connection(with: mediaType) else { return nil }
    return DefaultCaptureConnection(avConnection: connection)
  }
}
