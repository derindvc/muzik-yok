import AppKit
import CoreGraphics

let outputFolder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
let size = 512

func render(_ name: String, draw: (CGContext) -> Void) throws {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
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
  context.scaleBy(x: 0.5, y: 0.5)
  context.setAllowsAntialiasing(true)
  context.setShouldAntialias(true)
  let background = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
      CGColor(red: 0.043, green: 0.067, blue: 0.051, alpha: 1),
      CGColor(red: 0.090, green: 0.170, blue: 0.115, alpha: 1),
    ] as CFArray,
    locations: [0, 1]
  )!
  context.drawLinearGradient(
    background,
    start: CGPoint(x: 0, y: 1024),
    end: CGPoint(x: 1024, y: 0),
    options: []
  )
  draw(context)
  NSGraphicsContext.current?.flushGraphics()
  NSGraphicsContext.restoreGraphicsState()
  try bitmap.representation(using: .png, properties: [:])!
    .write(to: outputFolder.appendingPathComponent(name))
}

let green = CGColor(red: 0.278, green: 0.890, blue: 0.498, alpha: 1)

try render("1-monogram.png") { context in
  context.setStrokeColor(green)
  context.setLineWidth(88)
  context.setLineCap(.round)
  context.setLineJoin(.round)
  context.move(to: CGPoint(x: 238, y: 300))
  context.addLine(to: CGPoint(x: 238, y: 650))
  context.addCurve(to: CGPoint(x: 454, y: 648), control1: CGPoint(x: 238, y: 820), control2: CGPoint(x: 454, y: 820))
  context.addLine(to: CGPoint(x: 454, y: 300))
  context.move(to: CGPoint(x: 454, y: 648))
  context.addCurve(to: CGPoint(x: 735, y: 648), control1: CGPoint(x: 454, y: 830), control2: CGPoint(x: 735, y: 830))
  context.addLine(to: CGPoint(x: 735, y: 300))
  context.strokePath()
}

try render("2-focus.png") { context in
  context.setStrokeColor(green)
  context.setLineWidth(68)
  context.setLineCap(.round)
  context.addArc(
    center: CGPoint(x: 512, y: 512),
    radius: 305,
    startAngle: .pi / 4,
    endAngle: .pi * 7 / 4,
    clockwise: false
  )
  context.strokePath()
  context.setFillColor(green)
  context.fillEllipse(in: CGRect(x: 454, y: 454, width: 116, height: 116))
}

try render("3-sessizlik.png") { context in
  context.setFillColor(green)
  context.fillEllipse(in: CGRect(x: 225, y: 205, width: 590, height: 590))
  context.setFillColor(CGColor(red: 0.068, green: 0.122, blue: 0.082, alpha: 1))
  context.fillEllipse(in: CGRect(x: 365, y: 315, width: 550, height: 550))
  context.setFillColor(green)
  context.fillEllipse(in: CGRect(x: 725, y: 250, width: 105, height: 105))
}
