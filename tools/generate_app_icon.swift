import AppKit
import CoreGraphics

let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let side = 1024
let bitmap = NSBitmapImageRep(
  bitmapDataPlanes: nil,
  pixelsWide: side,
  pixelsHigh: side,
  bitsPerSample: 8,
  samplesPerPixel: 4,
  hasAlpha: true,
  isPlanar: false,
  colorSpaceName: .deviceRGB,
  bytesPerRow: 0,
  bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let context = NSGraphicsContext.current!.cgContext
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

let background = CGGradient(
  colorsSpace: CGColorSpaceCreateDeviceRGB(),
  colors: [
    CGColor(red: 0.043, green: 0.067, blue: 0.051, alpha: 1),
    CGColor(red: 0.098, green: 0.180, blue: 0.118, alpha: 1),
  ] as CFArray,
  locations: [0, 1]
)!
context.drawLinearGradient(
  background,
  start: CGPoint(x: 0, y: 1024),
  end: CGPoint(x: 1024, y: 0),
  options: []
)

context.setLineCap(.round)
context.setLineJoin(.round)
let ivory = CGColor(red: 0.953, green: 1, blue: 0.961, alpha: 1)
let green = CGColor(red: 0.278, green: 0.890, blue: 0.498, alpha: 1)

context.setFillColor(ivory)
context.fillEllipse(in: CGRect(x: 335, y: 245, width: 280, height: 165))
context.setStrokeColor(ivory)
context.setLineWidth(78)
context.move(to: CGPoint(x: 588, y: 335))
context.addLine(to: CGPoint(x: 588, y: 745))
context.addCurve(to: CGPoint(x: 780, y: 562), control1: CGPoint(x: 725, y: 735), control2: CGPoint(x: 793, y: 655))
context.strokePath()

context.setStrokeColor(green)
context.setLineWidth(74)
context.move(to: CGPoint(x: 272, y: 765))
context.addLine(to: CGPoint(x: 764, y: 260))
context.strokePath()

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

let source = base.appendingPathComponent("Icon-App-1024x1024@1x.png")
try bitmap.representation(using: .png, properties: [:])!.write(to: source)

let sizes: [(String, Int)] = [
  ("Icon-App-20x20@1x.png", 20),
  ("Icon-App-20x20@2x.png", 40),
  ("Icon-App-20x20@3x.png", 60),
  ("Icon-App-29x29@1x.png", 29),
  ("Icon-App-29x29@2x.png", 58),
  ("Icon-App-29x29@3x.png", 87),
  ("Icon-App-40x40@1x.png", 40),
  ("Icon-App-40x40@2x.png", 80),
  ("Icon-App-40x40@3x.png", 120),
  ("Icon-App-60x60@2x.png", 120),
  ("Icon-App-60x60@3x.png", 180),
  ("Icon-App-76x76@1x.png", 76),
  ("Icon-App-76x76@2x.png", 152),
  ("Icon-App-83.5x83.5@2x.png", 167),
]
for (name, pixels) in sizes {
  let image = NSImage(contentsOf: source)!
  let output = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  )!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: output)
  NSGraphicsContext.current?.imageInterpolation = .high
  image.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
  NSGraphicsContext.current?.flushGraphics()
  NSGraphicsContext.restoreGraphicsState()
  try output.representation(using: .png, properties: [:])!
    .write(to: base.appendingPathComponent(name))
}
