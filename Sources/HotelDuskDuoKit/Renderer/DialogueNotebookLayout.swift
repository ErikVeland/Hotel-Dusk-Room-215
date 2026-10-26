import Foundation
import CoreText
import CoreGraphics

/// Core Text measures and draws the same glyphs, including pages split mid-passage.
struct DialogueNotebookLayout {
    let text: NSAttributedString
    let size: CGSize
    let pages: [NSRange]
    private let frames: [Int: CTFrame]

    init(runs: [OriginalDialogueLines.Run], size: CGSize, fontSize: CGFloat) {
        self.size = size
        let text = NSMutableAttributedString(string: "")
        let font = CTFontCreateWithName("Georgia" as CFString, fontSize, nil)
        var lineSpacing: CGFloat = 6
        let paragraph = withUnsafePointer(to: &lineSpacing) { spacing in
            var setting = CTParagraphStyleSetting(spec: .lineSpacingAdjustment,
                                                  valueSize: MemoryLayout<CGFloat>.size, value: spacing)
            return CTParagraphStyleCreate(&setting, 1)
        }
        for run in runs {
            let colour: CGColor
            switch run.colour {
            case 1: colour = CGColor(red: 0.48, green: 0.19, blue: 0.15, alpha: 1)
            case 2: colour = CGColor(red: 0.20, green: 0.27, blue: 0.42, alpha: 1)
            default: colour = Self.speakerInk(person: run.person)
            }
            text.append(NSAttributedString(string: run.text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): colour,
                NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph
            ]))
        }
        self.text = text
        guard size.width > 0, size.height >= CTFontGetAscent(font) + CTFontGetDescent(font) else {
            pages = []
            frames = [:]
            return
        }
        let setter = CTFramesetterCreateWithAttributedString(text)
        let path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        var ranges: [NSRange] = []
        var frames: [Int: CTFrame] = [:]
        var offset = 0
        while offset < text.length {
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: offset, length: 0), path, nil)
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else { break }
            frames[offset] = frame
            var end = offset + visible.length
            // Keep paragraph separators on the preceding leaf so the next
            // passage starts at the top margin, even at an exact page break.
            let string = text.string as NSString
            while end < text.length, string.character(at: end) == 10 { end += 1 }
            ranges.append(NSRange(location: offset, length: end - offset))
            offset = end
        }
        pages = ranges
        self.frames = frames
    }

    /// Stable source identities keep their ink across scenes and physical pages.
    /// Narration, special portrait codes and unknown participants use neutral ink.
    private static func speakerInk(person: Int32?) -> CGColor {
        let rgb: (CGFloat, CGFloat, CGFloat)
        switch person {
        case 2: rgb = (0.22, 0.34, 0.24) // Dunning
        case 3: rgb = (0.38, 0.23, 0.36)
        case 4: rgb = (0.40, 0.28, 0.16)
        case 5: rgb = (0.31, 0.30, 0.43)
        case 6: rgb = (0.24, 0.35, 0.32)
        case 7: rgb = (0.42, 0.25, 0.32)
        case 8: rgb = (0.34, 0.32, 0.17)
        case 9: rgb = (0.32, 0.24, 0.39)
        case 10: rgb = (0.29, 0.33, 0.23)
        case 11: rgb = (0.44, 0.29, 0.23)
        case 12: rgb = (0.35, 0.28, 0.31)
        case 13: rgb = (0.27, 0.32, 0.29)
        case 14: rgb = (0.37, 0.30, 0.23)
        case 15: rgb = (0.30, 0.34, 0.19)
        case 16: rgb = (0.43, 0.22, 0.38)
        case 17: rgb = (0.25, 0.30, 0.37)
        default: rgb = (0.20, 0.17, 0.14) // Kyle and unattributed text
        }
        return CGColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }

    func draw(page: NSRange, revealedEnd: Int, in context: CGContext) {
        guard let frame = frames[page.location], page.length > 0 else { return }
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        for (index, line) in lines.enumerated() {
            let range = CTLineGetStringRange(line)
            guard range.location < revealedEnd else { break }
            context.saveGState()
            if revealedEnd < range.location + range.length {
                // Clip the already-shaped line rather than reshaping a prefix.
                // Kerning, ligatures, and wrapping stay fixed as ink appears.
                let width = CTLineGetOffsetForStringIndex(line, revealedEnd, nil)
                var ascent: CGFloat = 0, descent: CGFloat = 0
                CTLineGetTypographicBounds(line, &ascent, &descent, nil)
                context.clip(to: CGRect(x: origins[index].x - 2, y: origins[index].y - descent - 2,
                                        width: max(0, width + 2), height: ascent + descent + 4))
            }
            context.textPosition = origins[index]
            CTLineDraw(line, context)
            context.restoreGState()
        }
        context.restoreGState()
    }

    func accessibleText(page: NSRange) -> String {
        guard NSMaxRange(page) <= text.length else { return "" }
        return (text.string as NSString).substring(with: page)
    }
}
