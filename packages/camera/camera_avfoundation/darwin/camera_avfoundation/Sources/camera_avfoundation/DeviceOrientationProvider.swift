// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if os(iOS)
  import UIKit
#else
  import Foundation
#endif

/// A protocol which provides the current device orientation.
/// It exists to allow replacing UIDevice in tests.
protocol DeviceOrientationProvider {
  /// Returns the physical orientation of the device.
  var orientation: PlatformDeviceOrientation { get }
}

/// A default implementation of DeviceOrientationProvider which uses orientation
/// of the current device from UIDevice.
class DefaultDeviceOrientationProvider: NSObject, DeviceOrientationProvider {
  var orientation: PlatformDeviceOrientation {
    #if os(iOS)
      return getPigeonDeviceOrientation(for: UIDevice.current.orientation)
    #else
      // macOS does not expose a device-sensor orientation equivalent to UIDevice.
      return .landscapeLeft
    #endif
  }
}
