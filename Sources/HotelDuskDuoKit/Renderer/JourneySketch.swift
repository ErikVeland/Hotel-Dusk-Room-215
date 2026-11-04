import CoreGraphics
import CoreText
import Foundation
import ImageIO

/// Fixed pencil marks derived from the actual room view and recovered floor plan.
enum JourneySketch {
    static func make(_ image: CGImage, floorPlan: Bool = false) -> Data? {
        let scale = min(1, 512 / CGFloat(max(image.width, image.height)))
        let width = max(1, Int(CGFloat(image.width) * scale))
        let height = max(1, Int(CGFloat(image.height) * scale))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
              let bytes = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var grey = [Float](repeating: 0, count: width * height)
        for i in grey.indices {
            grey[i] = (0.2126 * Float(bytes[i * 4]) + 0.7152 * Float(bytes[i * 4 + 1])
                + 0.0722 * Float(bytes[i * 4 + 2])) / 255
        }
        if floorPlan, grey.reduce(0, +) / Float(grey.count) < 0.45 {
            grey = grey.map { 1 - $0 }
        }
        for y in 0..<height { for x in 0..<width {
            let i = y * width + x
            let dx = abs(grey[y * width + min(width - 1, x + 1)] - grey[y * width + max(0, x - 1)])
            let dy = abs(grey[min(height - 1, y + 1) * width + x] - grey[max(0, y - 1) * width + x])
            let hatch: Float = (x + y * 2) % 7 < 2 ? 0.13 : 0.03
            let shade = min(0.86, (dx + dy) * 1.65 + (1 - grey[i]) * hatch)
            let alpha = max(0, min(255, shade * 255))
            bytes[i * 4] = UInt8(alpha * 0.22)
            bytes[i * 4 + 1] = UInt8(alpha * 0.20)
            bytes[i * 4 + 2] = UInt8(alpha * 0.17)
            bytes[i * 4 + 3] = UInt8(alpha)
        } }
        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func image(_ data: Data?) -> CGImage? {
        guard let data, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func fit(_ aspect: CGFloat, in box: CGRect) -> CGRect {
        let width = min(box.width, box.height * aspect)
        let height = width / aspect
        return CGRect(x: box.midX - width / 2, y: box.midY - height / 2, width: width, height: height)
    }

    private static func draw(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.setBlendMode(.multiply)
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    private static func label(_ text: String, at point: CGPoint, size: CGFloat, context: CGContext) {
        let font = CTFontCreateWithName("Georgia-Italic" as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.23, alpha: 1)
        ]))
        context.saveGState()
        context.translateBy(x: point.x, y: point.y + CTFontGetAscent(font))
        context.scaleBy(x: 1, y: -1)
        context.textMatrix = .identity
        context.textPosition = .zero
        CTLineDraw(line, context)
        context.restoreGState()
    }

    static func draw(_ entry: BookJourney.Entry, size: CGSize, fontSize: CGFloat, in context: CGContext) {
        context.saveGState()
        context.clip(to: CGRect(origin: .zero, size: size))
        label(entry.name, at: .zero, size: fontSize, context: context)
        let viewBox = CGRect(x: 0, y: fontSize + 14, width: size.width, height: max(0, size.height * 0.58 - fontSize))
        if let view = image(entry.viewPNG) {
            draw(view, in: fit(CGFloat(view.width) / CGFloat(view.height), in: viewBox), context: context)
        }
        let mapTop = viewBox.maxY + 14
        let box = CGRect(x: 0, y: mapTop, width: size.width, height: max(0, size.height - mapTop - 24))
        let mapRect = fit(CGFloat(entry.mapSize.x / entry.mapSize.y), in: box)
        if let map = image(entry.floorPlanPNG) { draw(map, in: mapRect, context: context) }
        context.saveGState()
        context.clip(to: mapRect)
        let points = entry.route.map {
            CGPoint(x: mapRect.minX + CGFloat($0.x / entry.mapSize.x) * mapRect.width,
                    y: mapRect.minY + CGFloat($0.y / entry.mapSize.y) * mapRect.height)
        }
        context.setStrokeColor(CGColor(red: 0.48, green: 0.19, blue: 0.15, alpha: 0.9))
        context.setFillColor(CGColor(red: 0.48, green: 0.19, blue: 0.15, alpha: 0.9))
        context.setLineWidth(1.6)
        context.setLineCap(.round)
        if let first = points.first {
            context.move(to: first)
            for point in points.dropFirst() { context.addLine(to: point) }
            context.strokePath()
            context.strokeEllipse(in: CGRect(x: first.x - 3, y: first.y - 3, width: 6, height: 6))
        }
        if let last = points.last {
            context.fillEllipse(in: CGRect(x: last.x - 2.5, y: last.y - 2.5, width: 5, height: 5))
        }
        context.restoreGState()
        label("Chapter \(entry.chapter + 1) · \(entry.kind.rawValue.capitalized)",
              at: CGPoint(x: 0, y: size.height - 18), size: min(13, fontSize * 0.75), context: context)
        context.restoreGState()
    }
}
