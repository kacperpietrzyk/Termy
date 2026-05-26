#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = root.appendingPathComponent(".build/appicon/AppIcon.iconset", isDirectory: true)
let output = resources.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

struct RGBA {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

let ink = RGBA(red: 0.05, green: 0.06, blue: 0.09, alpha: 1)
let panel = RGBA(red: 0.075, green: 0.085, blue: 0.13, alpha: 1)
let panelTop = RGBA(red: 0.13, green: 0.15, blue: 0.22, alpha: 1)
let cyan = RGBA(red: 0.18, green: 0.90, blue: 0.84, alpha: 1)
let mint = RGBA(red: 0.57, green: 0.96, blue: 0.77, alpha: 1)
let violet = RGBA(red: 0.66, green: 0.55, blue: 0.98, alpha: 1)
let blue = RGBA(red: 0.38, green: 0.62, blue: 1.00, alpha: 1)
let amber = RGBA(red: 0.96, green: 0.73, blue: 0.33, alpha: 1)

func gradient(_ colors: [RGBA], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors.map(\.cgColor) as CFArray,
        locations: locations
    )!
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func strokeLine(_ context: CGContext, _ points: [CGPoint], color: RGBA, width: CGFloat) {
    guard let first = points.first else { return }
    context.saveGState()
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.beginPath()
    context.move(to: first)
    for point in points.dropFirst() {
        context.addLine(to: point)
    }
    context.strokePath()
    context.restoreGState()
}

func fillRound(_ context: CGContext, rect: CGRect, radius: CGFloat, color: RGBA) {
    context.saveGState()
    context.addPath(roundedRect(rect, radius))
    context.setFillColor(color.cgColor)
    context.fillPath()
    context.restoreGState()
}

func drawIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    let context = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let scale = CGFloat(size) / 1024.0
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: scale, y: -scale)

    let base = CGRect(x: 54, y: 54, width: 916, height: 916)
    let basePath = roundedRect(base, 216)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 30), blur: 56, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.48))
    context.addPath(basePath)
    context.drawLinearGradient(
        gradient([
            RGBA(red: 0.16, green: 0.17, blue: 0.26, alpha: 1),
            RGBA(red: 0.08, green: 0.09, blue: 0.14, alpha: 1),
            RGBA(red: 0.03, green: 0.04, blue: 0.07, alpha: 1),
        ], [0, 0.58, 1]),
        start: CGPoint(x: 150, y: 54),
        end: CGPoint(x: 900, y: 970),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    context.restoreGState()

    context.saveGState()
    context.addPath(basePath)
    context.clip()

    context.setAlpha(0.45)
    strokeLine(context, [CGPoint(x: 122, y: 210), CGPoint(x: 884, y: 210)], color: violet, width: 2)
    strokeLine(context, [CGPoint(x: 160, y: 802), CGPoint(x: 860, y: 802)], color: cyan, width: 2)
    strokeLine(context, [CGPoint(x: 220, y: 116), CGPoint(x: 220, y: 906)], color: blue, width: 2)
    context.setAlpha(1)

    let nodeStroke = RGBA(red: 0.40, green: 0.78, blue: 1, alpha: 0.55)
    strokeLine(context, [CGPoint(x: 642, y: 250), CGPoint(x: 746, y: 178), CGPoint(x: 842, y: 272)], color: nodeStroke, width: 13)
    for (point, color) in [
        (CGPoint(x: 642, y: 250), violet),
        (CGPoint(x: 746, y: 178), cyan),
        (CGPoint(x: 842, y: 272), amber),
    ] {
        fillRound(context, rect: CGRect(x: point.x - 29, y: point.y - 29, width: 58, height: 58), radius: 29, color: RGBA(red: 0.03, green: 0.04, blue: 0.07, alpha: 0.88))
        fillRound(context, rect: CGRect(x: point.x - 17, y: point.y - 17, width: 34, height: 34), radius: 17, color: color)
    }

    let terminal = CGRect(x: 186, y: 300, width: 652, height: 430)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 24), blur: 40, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.42))
    context.addPath(roundedRect(terminal, 68))
    context.setFillColor(ink.cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(roundedRect(terminal, 68))
    context.clip()
    fillRound(context, rect: CGRect(x: terminal.minX, y: terminal.minY, width: terminal.width, height: 92), radius: 0, color: panelTop)
    fillRound(context, rect: CGRect(x: terminal.minX, y: terminal.minY + 92, width: terminal.width, height: terminal.height - 92), radius: 0, color: panel)

    for (index, color) in [cyan, violet, amber].enumerated() {
        let x = terminal.minX + 72 + CGFloat(index * 48)
        fillRound(context, rect: CGRect(x: x, y: terminal.minY + 34, width: 22, height: 22), radius: 11, color: color)
    }

    context.setAlpha(0.16)
    strokeLine(context, [CGPoint(x: 710, y: 345), CGPoint(x: 710, y: 690)], color: mint, width: 2)
    strokeLine(context, [CGPoint(x: 214, y: 596), CGPoint(x: 812, y: 596)], color: mint, width: 2)
    context.setAlpha(1)
    context.restoreGState()

    context.saveGState()
    context.addPath(roundedRect(terminal, 68))
    context.setStrokeColor(RGBA(red: 0.67, green: 1.00, blue: 0.95, alpha: 0.30).cgColor)
    context.setLineWidth(4)
    context.strokePath()
    context.restoreGState()

    strokeLine(context, [CGPoint(x: 306, y: 492), CGPoint(x: 386, y: 552), CGPoint(x: 306, y: 612)], color: mint, width: 48)

    let cursor = CGRect(x: 442, y: 584, width: 180, height: 42)
    context.saveGState()
    context.addPath(roundedRect(cursor, 20))
    context.clip()
    context.drawLinearGradient(
        gradient([cyan, violet], [0, 1]),
        start: CGPoint(x: cursor.minX, y: cursor.midY),
        end: CGPoint(x: cursor.maxX, y: cursor.midY),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    context.restoreGState()

    let splitPane = CGRect(x: 678, y: 438, width: 76, height: 88)
    fillRound(context, rect: splitPane, radius: 16, color: RGBA(red: 0.14, green: 0.18, blue: 0.28, alpha: 0.92))
    context.saveGState()
    context.addPath(roundedRect(splitPane, 16))
    context.setStrokeColor(blue.cgColor)
    context.setLineWidth(6)
    context.strokePath()
    context.restoreGState()

    context.restoreGState()

    context.saveGState()
    context.addPath(basePath)
    context.setStrokeColor(RGBA(red: 1, green: 1, blue: 1, alpha: 0.16).cgColor)
    context.setLineWidth(4)
    context.strokePath()
    context.restoreGState()

    return rep
}

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in outputs {
    let rep = drawIcon(size: size)
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: iconset.appendingPathComponent(name), options: .atomic)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "TermyIcon", code: Int(process.terminationStatus), userInfo: [
        NSLocalizedDescriptionKey: "iconutil failed with status \(process.terminationStatus)"
    ])
}

print(output.path)
