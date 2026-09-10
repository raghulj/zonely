// Draws Zonely's app icon: a dial with a day/night ring. Run: swift Tools/GenerateIcon.swift out.icns
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"

func icon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let s = size

    // Rounded square ground
    let inset = s * 0.06
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.225, yRadius: s * 0.225)
    path.addClip()
    let ground = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(srgbRed: 0.09, green: 0.11, blue: 0.15, alpha: 1).cgColor,
            NSColor(srgbRed: 0.04, green: 0.05, blue: 0.07, alpha: 1).cgColor,
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(ground, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

    // Day/night ring
    let centre = CGPoint(x: s / 2, y: s / 2)
    let radius = s * 0.30
    let ring = s * 0.055
    ctx.setLineWidth(ring)
    ctx.setLineCap(.butt)
    ctx.setStrokeColor(NSColor(srgbRed: 0.16, green: 0.19, blue: 0.24, alpha: 1).cgColor)
    ctx.addArc(center: centre, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
    ctx.setStrokeColor(NSColor(srgbRed: 0.90, green: 0.66, blue: 0.24, alpha: 1).cgColor)
    ctx.addArc(center: centre, radius: radius, startAngle: -.pi * 0.15, endAngle: .pi * 0.75, clockwise: false)
    ctx.strokePath()

    // Hands
    ctx.setLineCap(.round)
    ctx.setStrokeColor(NSColor(srgbRed: 0.0, green: 0.78, blue: 0.45, alpha: 1).cgColor)
    ctx.setLineWidth(s * 0.045)
    ctx.move(to: centre)
    ctx.addLine(to: CGPoint(x: centre.x, y: centre.y + radius * 0.62))
    ctx.strokePath()
    ctx.setStrokeColor(NSColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1).cgColor)
    ctx.setLineWidth(s * 0.038)
    ctx.move(to: centre)
    ctx.addLine(to: CGPoint(x: centre.x + radius * 0.48, y: centre.y - radius * 0.18))
    ctx.strokePath()

    ctx.setFillColor(NSColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: centre.x - s * 0.022, y: centre.y - s * 0.022, width: s * 0.044, height: s * 0.044))

    image.unlockFocus()
    return image
}

let sizes: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Zonely.iconset")
try? FileManager.default.removeItem(at: tmp)
try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

for (point, scale) in sizes {
    let pixels = CGFloat(point * scale)
    let image = icon(size: pixels)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    let name = scale == 1 ? "icon_\(point)x\(point).png" : "icon_\(point)x\(point)@2x.png"
    try png.write(to: tmp.appendingPathComponent(name))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", tmp.path, "-o", outPath]
try task.run()
task.waitUntilExit()
print("wrote \(outPath)")
