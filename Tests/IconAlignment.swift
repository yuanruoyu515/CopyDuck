import AppKit

@main struct IconAlignment {
    static func main() throws {
        for size: CGFloat in [16, 18] {
            let icon = DuckArtwork.menuIcon(size: size)
            precondition(icon.isTemplate && icon.size == NSSize(width: size, height: size))
            precondition(icon.representations.count == 2)
            for case let bitmap as NSBitmapImageRep in icon.representations {
                let width = bitmap.pixelsWide, height = bitmap.pixelsHigh
                var minX = width, minY = height, maxX = -1, maxY = -1
                let data = bitmap.bitmapData!
                for y in 0..<height {
                    for x in 0..<width where data[y * bitmap.bytesPerRow + x * 4 + 3] > 0 {
                        minX = min(minX, x); maxX = max(maxX, x)
                        minY = min(minY, y); maxY = max(maxY, y)
                    }
                }
                let left = minX, right = width - maxX - 1
                let top = minY, bottom = height - maxY - 1
                precondition(maxX >= minX && maxY >= minY, "Empty glyph")
                precondition(min(left, right, top, bottom) >= 1, "Clipped glyph")
                precondition(abs(left - right) <= 1 && abs(top - bottom) <= 1, "Glyph is off-center")
                print("\(Int(size))pt / \(width)px: left=\(left), right=\(right), top=\(top), bottom=\(bottom)")
            }
            let saved = NSBitmapImageRep.imageReps(with: icon.tiffRepresentation!)
            precondition(saved.count == 2, "TIFF must retain both resolutions")
            for representation in saved { precondition(representation.size == icon.size, "TIFF point size changed") }
        }
    }
}
