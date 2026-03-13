import AVFoundation
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let flutterViewController = mainFlutterWindow?.contentViewController
      as? FlutterViewController
    {
      let channel = FlutterMethodChannel(
        name: "camera_example/macos_debug",
        binaryMessenger: flutterViewController.engine.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        guard call.method == "getCameraDisplayNames" else {
          result(FlutterMethodNotImplemented)
          return
        }

        let discoverySession = AVCaptureDevice.DiscoverySession(
          deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
          mediaType: .video,
          position: .unspecified)
        result(
          Dictionary(
            uniqueKeysWithValues: discoverySession.devices.map { ($0.uniqueID, $0.localizedName) }))
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
