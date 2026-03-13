// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation
import Foundation

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import AppKit
  import FlutterMacOS
  import ImageIO
#endif

private func debugSavePhotoLog(_ message: String) {
  #if os(macOS)
    NSLog("camera_avfoundation: %@", message)
  #endif
}

#if os(macOS)
  private func normalizedPhotoDataForMacOS(_ data: Data, path: String) -> Data {
    guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
      cgImage.height > cgImage.width
    else {
      return data
    }

    let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    guard
      let context = CGContext(
        data: nil,
        width: cgImage.height,
        height: cgImage.width,
        bitsPerComponent: cgImage.bitsPerComponent,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: cgImage.bitmapInfo.rawValue)
    else {
      return data
    }

    context.translateBy(x: 0, y: CGFloat(cgImage.width))
    context.rotate(by: -.pi / 2)
    context.draw(
      cgImage,
      in: CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))

    guard let rotatedImage = context.makeImage() else {
      return data
    }

    let bitmap = NSBitmapImageRep(cgImage: rotatedImage)
    let fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
    let fileType: NSBitmapImageRep.FileType = fileExtension == "png" ? .png : .jpeg
    let properties: [NSBitmapImageRep.PropertyKey: Any] =
      fileType == .jpeg ? [.compressionFactor: 1.0] : [:]
    return bitmap.representation(using: fileType, properties: properties) ?? data
  }
#endif

/// The completion handler block for save photo operations.
/// Can be called from either main queue or IO queue.
/// If success, `path` will be present and `error` will be nil. Otherwise, `path` will be nil and
/// `error` will be present.
/// path - the path for successfully saved photo file.
/// error - photo capture error or IO error.
typealias SavePhotoDelegateCompletionHandler = (String?, Error?) -> Void

/// Delegate object that handles photo capture results.
class SavePhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  /// The file path for the captured photo.
  private let path: String

  /// The queue on which captured photos are written to disk.
  private let ioQueue: DispatchQueue

  /// The completion handler block for capture and save photo operations.
  let completionHandler: SavePhotoDelegateCompletionHandler

  /// The path for captured photo file.
  /// Exposed for unit tests to verify the captured photo file path.
  var filePath: String {
    path
  }

  /// Initialize a photo capture delegate.
  /// path - the path for captured photo file.
  /// ioQueue - the queue on which captured photos are written to disk.
  /// completionHandler - The completion handler block for save photo operations. Can
  /// be called from either main queue or IO queue.
  init(
    path: String,
    ioQueue: DispatchQueue,
    completionHandler: @escaping SavePhotoDelegateCompletionHandler
  ) {
    self.path = path
    self.ioQueue = ioQueue
    self.completionHandler = completionHandler
    super.init()
  }

  /// Handler to write captured photo data into a file.
  /// - Parameters:
  ///   - error: The capture error
  ///   - photoDataProvider: A closure that provides photo data
  func handlePhotoCaptureResult(
    error: Error?,
    photoDataProvider: @escaping () -> WritableData?
  ) {
    if let error = error {
      debugSavePhotoLog("photo capture error=\(error)")
      completionHandler(nil, error)
      return
    }

    ioQueue.async { [weak self] in
      guard let strongSelf = self else { return }

      do {
        let data = photoDataProvider()
        debugSavePhotoLog("photo data available=\(data != nil) path=\(strongSelf.path)")

        #if os(macOS)
          if let rawData = data as? Data {
            let normalizedData = normalizedPhotoDataForMacOS(rawData, path: strongSelf.path)
            try normalizedData.writeToPath(strongSelf.path, options: .atomic)
            strongSelf.completionHandler(strongSelf.path, nil)
            return
          }
        #endif

        try data?.writeToPath(strongSelf.path, options: .atomic)
        strongSelf.completionHandler(strongSelf.path, nil)
      } catch {
        debugSavePhotoLog("photo save error=\(error)")
        strongSelf.completionHandler(nil, error)
      }
    }
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    handlePhotoCaptureResult(error: error) {
      photo.fileDataRepresentation()
    }
  }
}
