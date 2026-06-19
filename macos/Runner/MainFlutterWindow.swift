import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let pasteboardChannel = FlutterMethodChannel(
      name: "io.cardtrove.companion/pasteboard",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    pasteboardChannel.setMethodCallHandler { call, result in
      if call.method == "readImage" {
        result(readPasteboardImageData())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}

private func readPasteboardImageData() -> FlutterStandardTypedData? {
  guard let image = NSImage(pasteboard: NSPasteboard.general),
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
  else {
    return nil
  }

  let resized = resizeImage(cgImage, maxDimension: 1600)
  let bitmap = NSBitmapImageRep(cgImage: resized)
  guard let data = bitmap.representation(
    using: .jpeg,
    properties: [.compressionFactor: 0.82])
  else {
    return nil
  }
  return FlutterStandardTypedData(bytes: data)
}

private func resizeImage(_ image: CGImage, maxDimension: CGFloat) -> CGImage {
  let width = CGFloat(image.width)
  let height = CGFloat(image.height)
  let longestSide = max(width, height)
  guard longestSide > maxDimension else {
    return image
  }

  let scale = maxDimension / longestSide
  let newWidth = Int(width * scale)
  let newHeight = Int(height * scale)
  guard let colorSpace = image.colorSpace,
        let context = CGContext(
          data: nil,
          width: newWidth,
          height: newHeight,
          bitsPerComponent: image.bitsPerComponent,
          bytesPerRow: 0,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else {
    return image
  }

  context.interpolationQuality = .high
  context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
  return context.makeImage() ?? image
}
