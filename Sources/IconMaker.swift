import AppKit

@main struct IconMaker {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for size in [16, 32, 64, 128, 256, 512, 1024] {
            let image = DuckArtwork.image(size: CGFloat(size), background: true)
            let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
            let data = bitmap.representation(using: .png, properties: [:])!
            try data.write(to: directory.appendingPathComponent("duck-\(size).png"))
        }
        try DuckArtwork.menuIcon(size: 16).tiffRepresentation!.write(to: directory.appendingPathComponent("InputIcon-v2.tiff"))
        try DuckArtwork.menuIcon(size: 18).tiffRepresentation!.write(to: directory.appendingPathComponent("MenuIcon.tiff"))
    }
}
