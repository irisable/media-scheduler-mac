import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = root.appendingPathComponent("packaging/AppIcon.iconset", isDirectory: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for (name, size) in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        throw NSError(domain: "IconGen", code: 1)
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    let bg = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.97, green: 0.75, blue: 0.46, alpha: 1),
            NSColor(calibratedRed: 0.89, green: 0.39, blue: 0.27, alpha: 1)
        ]
    )!
    let base = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: size * 0.22, yRadius: size * 0.22)
    bg.draw(in: base, angle: -55)

    NSColor.white.withAlphaComponent(0.16).setFill()
    let glow = NSBezierPath(ovalIn: CGRect(x: size * 0.12, y: size * 0.62, width: size * 0.76, height: size * 0.28))
    glow.fill()

    let cardRect = CGRect(x: size * 0.17, y: size * 0.18, width: size * 0.66, height: size * 0.64)
    let card = NSBezierPath(roundedRect: cardRect, xRadius: size * 0.08, yRadius: size * 0.08)
    NSColor(calibratedWhite: 1, alpha: 0.96).setFill()
    card.fill()

    let headerRect = CGRect(x: cardRect.minX, y: cardRect.maxY - size * 0.16, width: cardRect.width, height: size * 0.16)
    let header = NSBezierPath(roundedRect: headerRect, xRadius: size * 0.08, yRadius: size * 0.08)
    NSColor(calibratedRed: 0.83, green: 0.24, blue: 0.20, alpha: 1).setFill()
    header.fill()

    NSColor(calibratedWhite: 0.88, alpha: 1).setFill()
    let punchY = headerRect.midY - size * 0.022
    for x in [cardRect.minX + size * 0.11, cardRect.maxX - size * 0.17] {
        let hole = NSBezierPath(ovalIn: CGRect(x: x, y: punchY, width: size * 0.044, height: size * 0.044))
        hole.fill()
    }

    let lineColor = NSColor(calibratedRed: 0.91, green: 0.63, blue: 0.46, alpha: 1)
    lineColor.setStroke()
    context.setLineWidth(size * 0.025)
    context.setLineCap(.round)

    let left = cardRect.minX + size * 0.10
    let right = cardRect.maxX - size * 0.10
    let top = cardRect.minY + size * 0.18
    let rowGap = size * 0.11

    for index in 0..<3 {
        let y = top + CGFloat(index) * rowGap
        context.move(to: CGPoint(x: left, y: y))
        context.addLine(to: CGPoint(x: right, y: y))
        context.strokePath()
    }

    let accent = NSColor(calibratedRed: 0.16, green: 0.54, blue: 0.44, alpha: 1)
    accent.setStroke()
    context.setLineWidth(size * 0.055)
    context.move(to: CGPoint(x: cardRect.minX + size * 0.18, y: cardRect.minY + size * 0.24))
    context.addLine(to: CGPoint(x: cardRect.minX + size * 0.28, y: cardRect.minY + size * 0.14))
    context.addLine(to: CGPoint(x: cardRect.minX + size * 0.47, y: cardRect.minY + size * 0.33))
    context.strokePath()

    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconGen", code: 2)
    }

    try png.write(to: iconsetURL.appendingPathComponent(name))
}

print("Generated iconset at \(iconsetURL.path)")
