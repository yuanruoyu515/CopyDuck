import AppKit

@main struct DMGArtwork {
    static func main() throws {
        let image = NSImage(size: NSSize(width: 660, height: 440))
        image.lockFocus()
        NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 660, height: 440).fill()
        func label(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
            let p = NSMutableParagraphStyle(); p.alignment = .center
            (text as NSString).draw(in: NSRect(x: x, y: y, width: width, height: size * 1.6), withAttributes: [
                .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: p
            ])
        }
        let ink = NSColor(calibratedRed: 0.19, green: 0.22, blue: 0.24, alpha: 1)
        let gray = NSColor(calibratedWhite: 0.53, alpha: 1)
        DuckArtwork.image(size: 62).draw(in: NSRect(x: 299, y: 355, width: 62, height: 62))
        label("复制鸭", x: 0, y: 320, width: 660, size: 25, weight: .semibold, color: ink)
        label("把小鸭子拖进应用程序", x: 0, y: 286, width: 660, size: 13, weight: .regular, color: gray)
        for x: CGFloat in [104, 432] {
            NSColor(calibratedRed: 0.973, green: 0.976, blue: 0.969, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: 130, width: 124, height: 124), xRadius: 26, yRadius: 26).fill()
        }
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 284, y: 192)); arrow.line(to: NSPoint(x: 373, y: 192))
        arrow.move(to: NSPoint(x: 358, y: 207)); arrow.line(to: NSPoint(x: 373, y: 192)); arrow.line(to: NSPoint(x: 358, y: 177))
        NSColor(calibratedRed: 0.77, green: 0.80, blue: 0.75, alpha: 1).setStroke()
        arrow.lineWidth = 3; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round; arrow.stroke()
        label("首次打开后，点击“安装输入组件”", x: 0, y: 48, width: 660, size: 12, weight: .regular, color: gray)
        label("复制一下，鸭来输入。", x: 0, y: 20, width: 660, size: 11, weight: .regular, color: gray)
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
