import AppKit
import Foundation

private struct IconSpec {
    let filename: String
    let pixels: CGFloat
}

private enum AppIconGenerator {
    static let symbolName = "camera.viewfinder"
    static let specs: [IconSpec] = [
        .init(filename: "icon_16x16.png", pixels: 16),
        .init(filename: "icon_16x16@2x.png", pixels: 32),
        .init(filename: "icon_32x32.png", pixels: 32),
        .init(filename: "icon_32x32@2x.png", pixels: 64),
        .init(filename: "icon_128x128.png", pixels: 128),
        .init(filename: "icon_128x128@2x.png", pixels: 256),
        .init(filename: "icon_256x256.png", pixels: 256),
        .init(filename: "icon_256x256@2x.png", pixels: 512),
        .init(filename: "icon_512x512.png", pixels: 512),
        .init(filename: "icon_512x512@2x.png", pixels: 1024)
    ]

    static func run(outputDirectory: URL) throws {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        for spec in specs {
            let destinationURL = outputDirectory.appendingPathComponent(spec.filename)
            try renderPNG(size: spec.pixels, to: destinationURL)
        }
    }

    private static func renderPNG(size: CGFloat, to destinationURL: URL) throws {
        let imageSize = NSSize(width: size, height: size)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size),
            pixelsHigh: Int(size),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw NSError(domain: "AppIconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate bitmap image rep."])
        }

        rep.size = imageSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let rect = NSRect(origin: .zero, size: imageSize)
        NSColor.clear.setFill()
        rect.fill()

        let inset = size * 0.08
        let backgroundRect = rect.insetBy(dx: inset, dy: inset)
        let cornerRadius = size * 0.225
        let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: cornerRadius, yRadius: cornerRadius)

        let gradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 0.11, green: 0.48, blue: 0.98, alpha: 1.0),
                NSColor(calibratedRed: 0.03, green: 0.30, blue: 0.89, alpha: 1.0)
            ]
        )
        gradient?.draw(in: backgroundPath, angle: 90)

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.54, weight: .bold, scale: .large)
        guard let baseSymbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            throw NSError(domain: "AppIconGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to load system symbol \(symbolName)."])
        }

        let symbol = baseSymbol.withSymbolConfiguration(symbolConfig) ?? baseSymbol
        let symbolRect = centeredRect(for: symbol.size, inside: backgroundRect, scale: 0.68)

        symbol.isTemplate = false
        let tintedSymbol = symbol.tinted(with: .white)
        tintedSymbol.draw(in: symbolRect)

        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "AppIconGenerator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode png data."])
        }

        try pngData.write(to: destinationURL)
    }

    private static func centeredRect(for sourceSize: NSSize, inside bounds: NSRect, scale: CGFloat) -> NSRect {
        let maxWidth = bounds.width * scale
        let maxHeight = bounds.height * scale
        let aspect = sourceSize.width / max(sourceSize.height, 1)

        var width = maxWidth
        var height = maxWidth / max(aspect, 0.01)

        if height > maxHeight {
            height = maxHeight
            width = maxHeight * aspect
        }

        return NSRect(
            x: bounds.midX - (width / 2),
            y: bounds.midY - (height / 2),
            width: width,
            height: height
        )
    }
}

private extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let output = NSImage(size: size)
        output.lockFocus()

        let drawRect = NSRect(origin: .zero, size: size)
        draw(in: drawRect)
        color.set()
        drawRect.fill(using: .sourceAtop)

        output.unlockFocus()
        output.isTemplate = false
        return output
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("Usage: swift Support/generate_app_icon.swift <iconset-output-dir>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
try AppIconGenerator.run(outputDirectory: outputDirectory)
