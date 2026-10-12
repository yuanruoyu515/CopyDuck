import AppKit

enum DuckArtwork {
    static func image(size: CGFloat, background: Bool = false, template: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let transform = NSAffineTransform()
        transform.scale(by: size / 1024)
        transform.concat()
        draw(background: background, template: template)
        image.unlockFocus()
        image.isTemplate = template
        return image
    }

    // Use the visible glyph bounds, rather than the app icon's padded square.
    // Explicit 1x/2x representations also give the input-source menu the correct point size.
    static func menuIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        let bounds = templateBounds
        for density in [1, 2] {
            let pixels = Int(size) * density
            let bitmap = makeBitmap(pixels: pixels)
            let context = NSGraphicsContext(bitmapImageRep: bitmap)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            let scale = (size - 2) * CGFloat(density) / max(bounds.width, bounds.height)
            context.cgContext.translateBy(x: CGFloat(pixels) / 2 - bounds.midX * scale,
                                          y: CGFloat(pixels) / 2 - bounds.midY * scale)
            context.cgContext.scaleBy(x: scale, y: scale)
            draw(background: false, template: true)
            NSGraphicsContext.restoreGraphicsState()
            bitmap.size = image.size
            image.addRepresentation(bitmap)
        }
        image.isTemplate = true
        return image
    }

    private static func makeBitmap(pixels: Int) -> NSBitmapImageRep {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: pixels * 4, bitsPerPixel: 32)!
        bitmap.bitmapData!.initialize(repeating: 0, count: bitmap.bytesPerRow * pixels)
        return bitmap
    }

    private static let templateBounds: NSRect = {
        let bitmap = makeBitmap(pixels: 1024)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        draw(background: false, template: true)
        NSGraphicsContext.restoreGraphicsState()
        let data = bitmap.bitmapData!
        var minX = 1024, minY = 1024, maxX = 0, maxY = 0
        for y in 0..<1024 {
            for x in 0..<1024 where data[y * bitmap.bytesPerRow + x * 4 + 3] > 0 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        return NSRect(x: minX, y: 1023 - maxY, width: maxX - minX + 1, height: maxY - minY + 1)
    }()

    private static func draw(background: Bool, template: Bool) {
        if background {
            NSColor.white.setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
        }
        let ink = template ? NSColor.black : NSColor(calibratedRed: 0.19, green: 0.22, blue: 0.24, alpha: 1)
        let body = NSBezierPath()
        body.move(to: NSPoint(x: 279, y: 435))
        body.curve(to: NSPoint(x: 300, y: 291), controlPoint1: NSPoint(x: 218, y: 390), controlPoint2: NSPoint(x: 242, y: 321))
        body.curve(to: NSPoint(x: 656, y: 293), controlPoint1: NSPoint(x: 391, y: 236), controlPoint2: NSPoint(x: 584, y: 241))
        body.curve(to: NSPoint(x: 708, y: 472), controlPoint1: NSPoint(x: 734, y: 348), controlPoint2: NSPoint(x: 738, y: 398))
        body.curve(to: NSPoint(x: 721, y: 626), controlPoint1: NSPoint(x: 693, y: 509), controlPoint2: NSPoint(x: 736, y: 552))
        body.curve(to: NSPoint(x: 510, y: 716), controlPoint1: NSPoint(x: 711, y: 737), controlPoint2: NSPoint(x: 587, y: 772))
        body.curve(to: NSPoint(x: 461, y: 543), controlPoint1: NSPoint(x: 453, y: 674), controlPoint2: NSPoint(x: 444, y: 610))
        body.curve(to: NSPoint(x: 329, y: 461), controlPoint1: NSPoint(x: 476, y: 474), controlPoint2: NSPoint(x: 383, y: 462))
        body.curve(to: NSPoint(x: 251, y: 495), controlPoint1: NSPoint(x: 292, y: 474), controlPoint2: NSPoint(x: 272, y: 496))
        body.curve(to: NSPoint(x: 279, y: 435), controlPoint1: NSPoint(x: 245, y: 477), controlPoint2: NSPoint(x: 254, y: 451))
        body.close()
        if !template { NSColor(calibratedWhite: 0.995, alpha: 1).setFill(); body.fill() }
        ink.setStroke(); body.lineWidth = template ? 43 : 23
        body.lineCapStyle = .round; body.lineJoinStyle = .round; body.stroke()
        let bill = NSBezierPath()
        bill.move(to: NSPoint(x: 716, y: 610))
        bill.curve(to: NSPoint(x: 812, y: 572), controlPoint1: NSPoint(x: 748, y: 611), controlPoint2: NSPoint(x: 797, y: 593))
        bill.curve(to: NSPoint(x: 710, y: 541), controlPoint1: NSPoint(x: 788, y: 550), controlPoint2: NSPoint(x: 746, y: 535))
        bill.close()
        (template ? ink : NSColor(calibratedRed: 1, green: 0.71, blue: 0.30, alpha: 1)).setFill(); bill.fill()
        ink.setStroke(); bill.lineWidth = template ? 28 : 19; bill.lineJoinStyle = .round; bill.stroke()
        ink.setFill()
        NSBezierPath(ovalIn: NSRect(x: 632, y: 620, width: 25, height: 30)).fill()
        let wing = NSBezierPath()
        wing.move(to: NSPoint(x: 415, y: 407))
        wing.curve(to: NSPoint(x: 583, y: 388), controlPoint1: NSPoint(x: 456, y: 357), controlPoint2: NSPoint(x: 553, y: 356))
        wing.lineWidth = template ? 30 : 19; wing.lineCapStyle = .round; wing.stroke()
        if !template {
            let tuft = NSBezierPath()
            tuft.move(to: NSPoint(x: 571, y: 743)); tuft.curve(to: NSPoint(x: 557, y: 775), controlPoint1: NSPoint(x: 572, y: 762), controlPoint2: NSPoint(x: 557, y: 772))
            tuft.move(to: NSPoint(x: 593, y: 747)); tuft.curve(to: NSPoint(x: 603, y: 779), controlPoint1: NSPoint(x: 592, y: 765), controlPoint2: NSPoint(x: 600, y: 775))
            tuft.lineWidth = 18; tuft.lineCapStyle = .round; tuft.stroke()
            NSColor(calibratedRed: 1, green: 0.86, blue: 0.79, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 605, y: 570, width: 38, height: 21)).fill()
        }
    }
}
