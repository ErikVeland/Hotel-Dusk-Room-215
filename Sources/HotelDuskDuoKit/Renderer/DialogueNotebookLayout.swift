import Foundation
import CoreText
import CoreGraphics

/// Core Text measures and draws the same glyphs, including pages split mid-passage.
struct DialogueNotebookLayout {
    /// A line of a choice or question menu. Menus follow the ink like another
    /// passage, but they are never typed out or saved.
    struct MenuEntry: Equatable {
        let text: String
        let selectable: Bool
    }

    let text: NSAttributedString
    /// Characters of conversation ink; any menu follows them.
    let inkLength: Int
    let menuRanges: [NSRange]
    let size: CGSize
    let pages: [NSRange]
    let fontSize: CGFloat
    let portraitSize: CGSize
    let book: BookJourney.Record
    private let frames: [Int: CTFrame]

    init(runs: [OriginalDialogueLines.Run], size: CGSize, fontSize: CGFloat,
         portraitSize: CGSize = .zero,
         menu: [MenuEntry] = [], book: BookJourney.Record = .init()) {
        self.size = size
        self.fontSize = fontSize
        self.portraitSize = portraitSize
        self.book = book
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
        inkLength = text.length
        var menuRanges: [NSRange] = []
        if !menu.isEmpty {
            var spacing: CGFloat = 6, before = fontSize * 0.45
            let entryStyle = withUnsafePointer(to: &spacing) { spacing in
                withUnsafePointer(to: &before) { before in
                    var settings = [
                        CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: spacing),
                        CTParagraphStyleSetting(spec: .paragraphSpacingBefore, valueSize: MemoryLayout<CGFloat>.size, value: before)
                    ]
                    return CTParagraphStyleCreate(&settings, settings.count)
                }
            }
            let heading = CTFontCreateWithName("Georgia-Italic" as CFString, fontSize * 0.85, nil)
            for (index, entry) in menu.enumerated() {
                let separator = index > 0 ? "\n" : text.length > 0 ? "\n\n" : ""
                text.append(NSAttributedString(string: separator, attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font,
                    NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph
                ]))
                let label = entry.selectable ? "– " + entry.text : entry.text
                menuRanges.append(NSRange(location: text.length, length: (label as NSString).length))
                text.append(NSAttributedString(string: label, attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): entry.selectable ? font : heading,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): entry.selectable
                        ? CGColor(red: 0.48, green: 0.19, blue: 0.15, alpha: 1)
                        : CGColor(red: 0.20, green: 0.17, blue: 0.14, alpha: 0.6),
                    NSAttributedString.Key(kCTParagraphStyleAttributeName as String): entryStyle
                ]))
            }
        }
        self.menuRanges = menuRanges
        self.text = text
        guard size.width > 0, size.height >= CTFontGetAscent(font) + CTFontGetDescent(font) else {
            pages = []
            frames = [:]
            return
        }
        let setter = CTFramesetterCreateWithAttributedString(text)
        var ranges: [NSRange] = []
        var frames: [Int: CTFrame] = [:]
        var offset = 0
        var pageIndex = 0
        while offset < text.length {
            if book.entries.contains(where: { $0.inkOffset == offset }) {
                var end = offset + 1
                let string = text.string as NSString
                while end < text.length, string.character(at: end) == 10 { end += 1 }
                ranges.append(NSRange(location: offset, length: end - offset))
                offset = end
                pageIndex += 1
                continue
            }
            let boundary = book.entries.first(where: { $0.inkOffset > offset })?.inkOffset ?? text.length
            let path = Self.framePath(size: size, padding: max(14, fontSize * 0.8),
                                      portraitSize: portraitSize, portraitAtLeadingEdge: pageIndex.isMultiple(of: 2))
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: offset, length: boundary - offset), path, nil)
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
            pageIndex += 1
        }
        pages = ranges
        self.frames = frames
    }

    /// Portraits stay in the outer corners. The view uses these text-canvas coordinates.
    func portraitFrame(pageIndex: Int) -> CGRect {
        CGRect(x: pageIndex.isMultiple(of: 2) ? 0 : size.width - portraitSize.width,
               y: size.height - portraitSize.height,
               width: portraitSize.width, height: portraitSize.height)
    }

    private static func framePath(size: CGSize, padding: CGFloat, portraitSize: CGSize,
                                  portraitAtLeadingEdge: Bool) -> CGPath {
        let path = CGMutablePath()
        guard portraitSize.width > 0, portraitSize.height > 0 else {
            path.addRect(CGRect(origin: .zero, size: size))
            return path
        }
        let width = min(size.width, portraitSize.width + padding)
        let height = min(size.height, portraitSize.height + padding)

        // Reserve the full portrait frame, even while it is empty. Poses and
        // speakers can change without moving ink or entering its space.
        if portraitAtLeadingEdge {
            path.move(to: CGPoint(x: 0, y: height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: size.width, y: 0))
            path.addLine(to: CGPoint(x: width, y: 0))
            path.addLine(to: CGPoint(x: width, y: height))
        } else {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size.width - width, y: 0))
            path.addLine(to: CGPoint(x: size.width - width, y: height))
            path.addLine(to: CGPoint(x: size.width, y: height))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
        }
        path.closeSubpath()
        return path
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
        if let entry = journey(on: page) {
            JourneySketch.draw(entry, size: size, fontSize: fontSize, in: context)
            return
        }
        guard let frame = frames[page.location], page.length > 0 else { return }
        // A menu appears whole once the ink before it is written.
        let revealedEnd = !menuRanges.isEmpty && revealedEnd >= inkLength ? text.length : revealedEnd
        let lines = CTFrameGetLines(frame) as? [CTLine] ?? []
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

    /// The selectable menu entry under a point in page coordinates (y down).
    func menuEntry(at point: CGPoint, page: NSRange) -> Int? {
        guard !menuRanges.isEmpty, let frame = frames[page.location] else { return nil }
        let lines = CTFrameGetLines(frame) as? [CTLine] ?? []
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        let y = size.height - point.y
        for (index, line) in lines.enumerated() {
            var ascent: CGFloat = 0, descent: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
            // Reach into the gap between entries so each one is a fair target.
            guard y >= origins[index].y - descent - 8, y <= origins[index].y + ascent + 8,
                  point.x >= origins[index].x - 12, point.x <= origins[index].x + width + 12 else { continue }
            let location = CTLineGetStringRange(line).location
            return menuRanges.firstIndex { NSLocationInRange(location, $0) }
        }
        return nil
    }

    func accessibleText(page: NSRange) -> String {
        if let entry = journey(on: page) {
            return "\(entry.name). Chapter \(entry.chapter + 1). \(entry.kind.rawValue.capitalized). A pencil view and the route walked on this visit."
        }
        guard NSMaxRange(page) <= text.length else { return "" }
        return (text.string as NSString).substring(with: page)
    }

    func journey(on page: NSRange) -> BookJourney.Entry? {
        book.entries.first { $0.inkOffset == page.location }
    }

    func portraits(on page: NSRange) -> [BookJourney.Portrait] {
        guard journey(on: page) == nil else { return [] }
        return book.portraits.last(where: { $0.inkOffset < NSMaxRange(page) })?.portraits ?? []
    }
}
