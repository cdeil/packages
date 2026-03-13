// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation
import XCTest

@testable import camera_avfoundation

final class DefaultCameraDisconnectTests: XCTestCase {
    func testExternalCameraDisconnectReportsErrorEvent() {
        let configuration = CameraTestUtils.createTestCameraConfiguration()
        let captureDevice = MockCaptureDevice()
        captureDevice.uniqueID = "external-camera"
        captureDevice.position = .unspecified
        if #available(iOS 17.0, macCatalyst 17.0, macOS 14.0, *) {
            captureDevice.deviceType = .external
        }
        configuration.videoCaptureDeviceFactory = { _ in captureDevice }

        let camera = CameraTestUtils.createTestCamera(configuration)
        let messenger = MockFlutterBinaryMessenger()
        camera.dartAPI = CameraEventApi(binaryMessenger: messenger, messageChannelSuffix: "7")

        NotificationCenter.default.post(
            name: AVCaptureDevice.wasDisconnectedNotification,
            object: captureDevice)

        waitForQueueRoundTrip(with: DispatchQueue.main)

        XCTAssertTrue(
            messenger.sentMessages.contains(where: {
                $0.channel == "dev.flutter.pigeon.camera_avfoundation.CameraEventApi.error.7"
            }))
    }
}
