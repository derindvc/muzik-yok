import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
for file in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
where file.pathExtension == "png" {
  let source = CGImageSourceCreateWithURL(file as CFURL, nil)!
  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
  let context = CGContext(
    data: nil,
    width: image.width,
    height: image.height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
  )!
  context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
  let output = context.makeImage()!
  let temporary = file.deletingLastPathComponent().appendingPathComponent(".opaque-\(file.lastPathComponent)")
  let destination = CGImageDestinationCreateWithURL(
    temporary as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
  )!
  CGImageDestinationAddImage(destination, output, nil)
  precondition(CGImageDestinationFinalize(destination))
  try FileManager.default.removeItem(at: file)
  try FileManager.default.moveItem(at: temporary, to: file)
}
