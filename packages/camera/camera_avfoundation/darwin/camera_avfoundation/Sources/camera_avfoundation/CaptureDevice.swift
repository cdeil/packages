// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation

/// A protocol which is a direct passthrough to AVCaptureDevice.
/// It exists to allow replacing AVCaptureDevice in tests.
protocol CaptureDevice: NSObjectProtocol {
  /// Underlying `AVCaptureDevice` instance. This is should not be used directly
  /// in the plugin implementation code, but it exists so that other protocol default
  /// implementation can pass the raw device to AVFoundation methods.
  var avDevice: AVCaptureDevice { get }

  // Device identifier
  var uniqueID: String { get }

  // Position/Orientation
  var position: AVCaptureDevice.Position { get }

  // Lens type
  var deviceType: AVCaptureDevice.DeviceType { get }

  // Format/Configuration
  var flutterActiveFormat: CaptureDeviceFormat { get set }
  var flutterFormats: [CaptureDeviceFormat] { get }

  // Flash/Torch
  var hasFlash: Bool { get }
  var hasTorch: Bool { get }
  var isTorchAvailable: Bool { get }
  var torchMode: AVCaptureDevice.TorchMode { get set }
  func isFlashModeSupported(_ mode: AVCaptureDevice.FlashMode) -> Bool

  // Focus
  var isFocusPointOfInterestSupported: Bool { get }
  func isFocusModeSupported(_ mode: AVCaptureDevice.FocusMode) -> Bool
  var focusMode: AVCaptureDevice.FocusMode { get set }
  var focusPointOfInterest: CGPoint { get set }

  // Exposure
  var isExposurePointOfInterestSupported: Bool { get }
  var exposureMode: AVCaptureDevice.ExposureMode { get set }
  var exposurePointOfInterest: CGPoint { get set }
  var minExposureTargetBias: Float { get }
  var maxExposureTargetBias: Float { get }
  func setExposureTargetBias(
    _ bias: Float, completionHandler handler: ((CMTime) -> Void)?)
  func isExposureModeSupported(_ mode: AVCaptureDevice.ExposureMode) -> Bool

  // Zoom
  var maxAvailableVideoZoomFactor: CGFloat { get }
  var minAvailableVideoZoomFactor: CGFloat { get }
  var videoZoomFactor: CGFloat { get set }

  // Video Stabilization
  func isVideoStabilizationModeSupported(_ videoStabilizationMode: PlatformVideoStabilizationMode)
    -> Bool

  // Camera Properties
  var lensAperture: Float { get }
  var exposureDuration: CMTime { get }
  var iso: Float { get }

  // Configuration Lock
  func lockForConfiguration() throws
  func unlockForConfiguration()

  // Frame Duration
  var activeVideoMinFrameDuration: CMTime { get set }
  var activeVideoMaxFrameDuration: CMTime { get set }
}

final class DefaultCaptureDevice: NSObject, CaptureDevice {
  let avDevice: AVCaptureDevice

  init(avDevice: AVCaptureDevice) {
    self.avDevice = avDevice
    super.init()
  }

  var uniqueID: String { avDevice.uniqueID }
  var position: AVCaptureDevice.Position { avDevice.position }
  var deviceType: AVCaptureDevice.DeviceType { avDevice.deviceType }

  var flutterActiveFormat: CaptureDeviceFormat {
    get { avDevice.activeFormat }
    set { avDevice.activeFormat = newValue.avFormat }
  }

  var flutterFormats: [CaptureDeviceFormat] { avDevice.formats }
  var hasFlash: Bool { avDevice.hasFlash }
  var hasTorch: Bool { avDevice.hasTorch }
  var isTorchAvailable: Bool { avDevice.isTorchAvailable }

  var torchMode: AVCaptureDevice.TorchMode {
    get { avDevice.torchMode }
    set { avDevice.torchMode = newValue }
  }

  func isFlashModeSupported(_ mode: AVCaptureDevice.FlashMode) -> Bool {
    avDevice.isFlashModeSupported(mode)
  }

  var isFocusPointOfInterestSupported: Bool { avDevice.isFocusPointOfInterestSupported }

  func isFocusModeSupported(_ mode: AVCaptureDevice.FocusMode) -> Bool {
    avDevice.isFocusModeSupported(mode)
  }

  var focusMode: AVCaptureDevice.FocusMode {
    get { avDevice.focusMode }
    set { avDevice.focusMode = newValue }
  }

  var focusPointOfInterest: CGPoint {
    get { avDevice.focusPointOfInterest }
    set { avDevice.focusPointOfInterest = newValue }
  }

  var isExposurePointOfInterestSupported: Bool { avDevice.isExposurePointOfInterestSupported }

  var exposureMode: AVCaptureDevice.ExposureMode {
    get { avDevice.exposureMode }
    set { avDevice.exposureMode = newValue }
  }

  var exposurePointOfInterest: CGPoint {
    get { avDevice.exposurePointOfInterest }
    set { avDevice.exposurePointOfInterest = newValue }
  }

  var minExposureTargetBias: Float {
    #if os(iOS)
      return avDevice.minExposureTargetBias
    #else
      return 0
    #endif
  }

  var maxExposureTargetBias: Float {
    #if os(iOS)
      return avDevice.maxExposureTargetBias
    #else
      return 0
    #endif
  }

  func setExposureTargetBias(
    _ bias: Float, completionHandler handler: ((CMTime) -> Void)?
  ) {
    #if os(iOS)
      avDevice.setExposureTargetBias(bias, completionHandler: handler)
    #else
      handler?(CMTime.zero)
    #endif
  }

  func isExposureModeSupported(_ mode: AVCaptureDevice.ExposureMode) -> Bool {
    avDevice.isExposureModeSupported(mode)
  }

  var maxAvailableVideoZoomFactor: CGFloat {
    #if os(iOS)
      return avDevice.maxAvailableVideoZoomFactor
    #else
      return 1.0
    #endif
  }

  var minAvailableVideoZoomFactor: CGFloat {
    #if os(iOS)
      return avDevice.minAvailableVideoZoomFactor
    #else
      return 1.0
    #endif
  }

  var videoZoomFactor: CGFloat {
    get {
      #if os(iOS)
        return avDevice.videoZoomFactor
      #else
        return 1.0
      #endif
    }
    set {
      #if os(iOS)
        avDevice.videoZoomFactor = newValue
      #endif
    }
  }

  func isVideoStabilizationModeSupported(_ videoStabilizationMode: PlatformVideoStabilizationMode)
    -> Bool
  {
    #if os(iOS)
      return avDevice.activeFormat.isVideoStabilizationModeSupported(
        getAvCaptureVideoStabilizationMode(videoStabilizationMode))
    #else
      return false
    #endif
  }

  var lensAperture: Float {
    #if os(iOS)
      return avDevice.lensAperture
    #else
      return 0
    #endif
  }

  var exposureDuration: CMTime {
    #if os(iOS)
      return avDevice.exposureDuration
    #else
      return .zero
    #endif
  }

  var iso: Float {
    #if os(iOS)
      return avDevice.iso
    #else
      return 0
    #endif
  }

  func lockForConfiguration() throws {
    try avDevice.lockForConfiguration()
  }

  func unlockForConfiguration() {
    avDevice.unlockForConfiguration()
  }

  var activeVideoMinFrameDuration: CMTime {
    get { avDevice.activeVideoMinFrameDuration }
    set { avDevice.activeVideoMinFrameDuration = newValue }
  }

  var activeVideoMaxFrameDuration: CMTime {
    get { avDevice.activeVideoMaxFrameDuration }
    set { avDevice.activeVideoMaxFrameDuration = newValue }
  }
}

/// A protocol which is a direct passthrough to AVCaptureInput.
/// It exists to allow replacing AVCaptureInput in tests.
protocol CaptureInput: NSObjectProtocol {
  /// Underlying input instance. It is exposed as raw AVCaptureInput has to be passed to some
  /// AVFoundation methods. The plugin implementation code shouldn't use it though.
  var avInput: AVCaptureInput { get }

  var ports: [AVCaptureInput.Port] { get }
}

/// A protocol which wraps the creation of AVCaptureDeviceInput.
/// It exists to allow mocking instances of AVCaptureDeviceInput in tests.
protocol CaptureDeviceInputFactory: NSObjectProtocol {
  func deviceInput(with device: CaptureDevice) throws -> CaptureInput
}

extension AVCaptureInput: CaptureInput {
  var avInput: AVCaptureInput { self }
}

/// A default implementation of CaptureDeviceInputFactory protocol which
/// wraps a call to AVCaptureInput static method `deviceInputWithDevice`.
class DefaultCaptureDeviceInputFactory: NSObject, CaptureDeviceInputFactory {
  func deviceInput(with device: CaptureDevice) throws -> CaptureInput {
    return try AVCaptureDeviceInput(device: device.avDevice)
  }
}
