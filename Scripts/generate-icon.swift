// Renders the app icon: the app's own ring on a dark rounded square.
//
// Run once, then convert and commit the result:
//   swift Scripts/generate-icon.swift Resources/AppIcon.iconset
//   iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
// The iPhone's, one opaque 1024-pixel square:
//   swift Scripts/generate-icon.swift --ios ios/Pomodoro/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
// Not part of build.sh — the .icns is committed, not rebuilt.

import AppKit
import UniformTypeIdentifiers

// Matches config.json: popover.background, ring.trackColor, ring.workColor.
let background = NSColor(srgbRed: 0x25 / 255, green: 0x25 / 255, blue: 0x25 / 255, alpha: 1)
let track = NSColor(srgbRed: 0x3D / 255, green: 0x3D / 255, blue: 0x3D / 255, alpha: 1)
let accent = NSColor(srgbRed: 0xEC / 255, green: 0x95 / 255, blue: 0x8C / 255, alpha: 1)

/// Fraction of the circle the arc covers — the same three-quarters the app
/// shows for a 45 minute timer, so the icon reads as "timer with time left".
let arcFraction = 0.75

func renderIcon(size: Int) -> NSImage {
    let side = CGFloat(size)
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()
    defer { image.unlockFocus() }
    drawIcon(side: side, macOS: true)
    return image
}

/// Draws into the current context. macOS icons sit inside a rounded square
/// with a margin around it; iOS fills the whole square and rounds it itself.
func drawIcon(side: CGFloat, macOS: Bool) {
    let context = NSGraphicsContext.current!
    context.imageInterpolation = .high
    context.cgContext.setLineCap(.butt)

    let inset = macOS ? side * 0.09 : 0
    let plate = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let corner = macOS ? plate.width * 0.2237 : 0          // the macOS squircle ratio
    let plateePath = NSBezierPath(roundedRect: plate, xRadius: corner, yRadius: corner)
    background.setFill()
    plateePath.fill()

    let center = NSPoint(x: plate.midX, y: plate.midY)
    let radius = plate.width * 0.32
    let lineWidth = max(1, plate.width * 0.055)

    let trackPath = NSBezierPath()
    trackPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    trackPath.lineWidth = lineWidth
    track.setStroke()
    trackPath.stroke()

    // AppKit angles run counter-clockwise from three o'clock; the app's arc
    // runs clockwise from twelve, hence the negative sweep from 90°.
    let sweep = 360 * arcFraction
    let arc = NSBezierPath()
    arc.appendArc(
        withCenter: center,
        radius: radius,
        startAngle: 90,
        endAngle: 90 - sweep,
        clockwise: true
    )
    arc.lineWidth = lineWidth
    accent.setStroke()
    arc.stroke()

    // The handle sits at the end of the arc, hollow, filled with the plate.
    let endAngle = CGFloat(90 - sweep) * .pi / 180
    let handleCenter = NSPoint(
        x: center.x + radius * cos(endAngle),
        y: center.y + radius * sin(endAngle)
    )
    let handleRadius = lineWidth * 1.5
    let handleRect = NSRect(
        x: handleCenter.x - handleRadius,
        y: handleCenter.y - handleRadius,
        width: handleRadius * 2,
        height: handleRadius * 2
    )
    let handle = NSBezierPath(ovalIn: handleRect)
    background.setFill()
    handle.fill()
    handle.lineWidth = lineWidth * 0.7
    accent.setStroke()
    handle.stroke()
}

/// Exactly `pixels` square and without an alpha channel, as iOS wants it.
func writeOpaquePNG(pixels: Int, to url: URL) throws {
    guard let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { throw CocoaError(.fileWriteUnknown) }
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    drawIcon(side: CGFloat(pixels), macOS: false)
    guard let image = context.makeImage(),
          let file = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(file, image, nil)
    guard CGImageDestinationFinalize(file) else { throw CocoaError(.fileWriteUnknown) }
}

func write(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: url)
}

let arguments = CommandLine.arguments
if arguments.count == 3, arguments[1] == "--ios" {
    try writeOpaquePNG(pixels: 1024, to: URL(fileURLWithPath: arguments[2]))
    print("Wrote \(arguments[2])")
    exit(0)
}
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate-icon.swift <output.iconset> | --ios <output.png>\n".utf8))
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// The ten entries iconutil expects.
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    let image = renderIcon(size: variant.pixels)
    try write(image, to: outputDirectory.appendingPathComponent("\(variant.name).png"))
}

print("Wrote \(variants.count) sizes to \(outputDirectory.path)")
