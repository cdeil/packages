// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation

/// A protocol which is a direct passthrough to AVCaptureSession.
/// It exists to allow replacing AVCaptureSession in tests.
protocol CaptureSession: NSObjectProtocol {
  var sessionPreset: AVCaptureSession.Preset { get set }
  var inputs: [AVCaptureInput] { get }
  var outputs: [AVCaptureOutput] { get }
  var automaticallyConfiguresApplicationAudioSession: Bool { get set }
  var isRunning: Bool { get }

  func beginConfiguration()
  func commitConfiguration()
  func startRunning()
  func stopRunning()
  func canSetSessionPreset(_ preset: AVCaptureSession.Preset) -> Bool
  func addInputWithNoConnections(_ input: CaptureInput)
  func addOutputWithNoConnections(_ output: AVCaptureOutput)
  func addConnection(_ connection: AVCaptureConnection)
  func addInput(_ input: CaptureInput)
  func addOutput(_ output: AVCaptureOutput)
  func removeInput(_ input: CaptureInput)
  func removeOutput(_ output: AVCaptureOutput)
  func canAddInput(_ input: CaptureInput) -> Bool
  func canAddOutput(_ output: AVCaptureOutput) -> Bool
  func canAddConnection(_ connection: AVCaptureConnection) -> Bool
}

final class DefaultCaptureSession: NSObject, CaptureSession {
  let avSession: AVCaptureSession

  init(avSession: AVCaptureSession) {
    self.avSession = avSession
    super.init()
  }

  var sessionPreset: AVCaptureSession.Preset {
    get { avSession.sessionPreset }
    set { avSession.sessionPreset = newValue }
  }

  var inputs: [AVCaptureInput] { avSession.inputs }
  var outputs: [AVCaptureOutput] { avSession.outputs }
  var automaticallyConfiguresApplicationAudioSession: Bool {
    get {
      #if os(iOS)
        return avSession.automaticallyConfiguresApplicationAudioSession
      #else
        return false
      #endif
    }
    set {
      #if os(iOS)
        avSession.automaticallyConfiguresApplicationAudioSession = newValue
      #endif
    }
  }
  var isRunning: Bool { avSession.isRunning }

  func beginConfiguration() { avSession.beginConfiguration() }
  func commitConfiguration() { avSession.commitConfiguration() }
  func startRunning() { avSession.startRunning() }
  func stopRunning() { avSession.stopRunning() }
  func canSetSessionPreset(_ preset: AVCaptureSession.Preset) -> Bool {
    avSession.canSetSessionPreset(preset)
  }

  func addInputWithNoConnections(_ input: CaptureInput) {
    avSession.addInputWithNoConnections(input.avInput)
  }

  func addOutputWithNoConnections(_ output: AVCaptureOutput) {
    avSession.addOutputWithNoConnections(output)
  }

  func addConnection(_ connection: AVCaptureConnection) { avSession.addConnection(connection) }

  func addInput(_ input: CaptureInput) {
    avSession.addInput(input.avInput)
  }

  func addOutput(_ output: AVCaptureOutput) { avSession.addOutput(output) }

  func removeInput(_ input: CaptureInput) {
    avSession.removeInput(input.avInput)
  }

  func removeOutput(_ output: AVCaptureOutput) { avSession.removeOutput(output) }

  func canAddInput(_ input: CaptureInput) -> Bool {
    avSession.canAddInput(input.avInput)
  }

  func canAddOutput(_ output: AVCaptureOutput) -> Bool { avSession.canAddOutput(output) }

  func canAddConnection(_ connection: AVCaptureConnection) -> Bool {
    avSession.canAddConnection(connection)
  }
}
