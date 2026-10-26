import Foundation
import Combine

/// One transcript and one reading cursor for the physical book spread.
@MainActor
final class DialogueNotebook: ObservableObject {
    struct Reader: Equatable {
        var pages: [NSRange] = []
        var spreadIndex = 0
        var revealedEnd = 0
        var leftIndex: Int { spreadIndex * 2 }
        func page(at index: Int) -> NSRange {
            pages.indices.contains(index) ? pages[index] : NSRange(location: pages.last.map(NSMaxRange) ?? 0, length: 0)
        }
        var spreadEnd: Int { max(NSMaxRange(page(at: leftIndex)), NSMaxRange(page(at: leftIndex + 1))) }
        var isWriting: Bool { revealedEnd < spreadEnd }
        var hasNextSpread: Bool { leftIndex + 2 < pages.count }
    }

    @Published private(set) var ink: [OriginalDialogueLines.Run] = []
    @Published private(set) var reader = Reader()
    @Published private(set) var layout: DialogueNotebookLayout?
    @Published private(set) var isTurning = false
    private(set) var turnRevision = 0
    private var lastPhase: OriginalEventRunner.Phase?
    private var lastProgram: String?
    private var pendingLayout = false
    // Keep the source offset across temporary cover sizes and repeated reflows.
    private var readingAnchor = 0
    private var followsNextPassage = false
    private var reviewAnchor: Int?
    private(set) var turnFromSpread = 0
    var turnsBackward: Bool { turnFromSpread > reader.spreadIndex }
    var isReviewing: Bool { reviewAnchor != nil }
    var canTurnBack: Bool {
        !pendingLayout && !isTurning && reader.spreadIndex > 0
    }
    var canTurnForward: Bool {
        !pendingLayout && !isTurning && !reader.isWriting && reader.hasNextSpread &&
            (!isReviewing || reader.page(at: reader.leftIndex + 2).location < reader.revealedEnd)
    }

    func followNextPassage() { followsNextPassage = true }

    func beginReview() {
        guard reviewAnchor == nil else { return }
        reviewAnchor = readingAnchor
    }

    func endReview() {
        guard let anchor = reviewAnchor else { return }
        reviewAnchor = nil
        if isTurning {
            turnRevision += 1
            isTurning = false
        }
        readingAnchor = anchor
        if let layout { configure(layout) }
    }

    func turnBack() {
        guard canTurnBack else { return }
        turn(to: reader.spreadIndex - 1)
    }

    func turnForward() {
        guard canTurnForward else { return }
        turn(to: reader.spreadIndex + 1)
    }

    private func turn(to spread: Int) {
        turnFromSpread = reader.spreadIndex
        turnRevision += 1
        isTurning = true
        reader.spreadIndex = spread
        readingAnchor = reader.page(at: reader.leftIndex).location
    }

    func endPresentation() { lastPhase = nil }

    func record(_ phase: OriginalEventRunner.Phase, program: String) {
        guard phase != lastPhase || program != lastProgram else { return }
        lastPhase = phase
        lastProgram = program
        let pages: [OriginalDialoguePacket.Page]
        let presentations: [OriginalDialoguePacket.Presentation]
        switch phase {
        case .dialogue(let packet):
            pages = packet.pages
            presentations = packet.presentations
        case .itemNotice(_, let page):
            pages = [page]
            presentations = []
        default: return
        }
        var next = ink
        // Packet order is narrative order. Original screen IDs do not assign leaves.
        for page in pages {
            let person = presentations.first { $0.page == page.page }.map { Int32($0.person) }
            let lines = OriginalDialogueLines(page: page, person: person)
            guard !lines.isEmpty else { continue }
            if !next.isEmpty { next.append(.init(text: "\n\n", colour: 0)) }
            let writtenLines = lines.lines.filter { !$0.allSatisfy { $0.text.trimmingCharacters(in: .whitespaces).isEmpty } }
            for (index, line) in writtenLines.enumerated() {
                if index > 0 { next.append(.init(text: " ", colour: 0)) }
                next.append(contentsOf: line)
            }
        }
        if next != ink {
            if followsNextPassage {
                readingAnchor = ink.reduce(0) { $0 + ($1.text as NSString).length } + (ink.isEmpty ? 0 : 2)
                reader.revealedEnd = max(reader.revealedEnd, readingAnchor)
                followsNextPassage = false
            }
            pendingLayout = true
            ink = next
        }
    }

    func configure(_ layout: DialogueNotebookLayout) {
        // Empty cover geometry must not discard the last usable pagination.
        guard !layout.pages.isEmpty || ink.isEmpty else { return }
        let anchor = readingAnchor
        var next = reader
        next.pages = layout.pages
        let anchorPage = layout.pages.firstIndex { NSLocationInRange(anchor, $0) } ?? max(0, layout.pages.count - 1)
        next.spreadIndex = anchorPage / 2
        if isTurning, next.pages != reader.pages {
            turnRevision += 1
            isTurning = false
        }
        self.layout = layout
        reader = next
        pendingLayout = !ink.isEmpty && layout.pages.isEmpty
    }

    func write(count: Int = 2) {
        guard !isTurning, !pendingLayout, reader.isWriting else { return }
        reader.revealedEnd = min(reader.spreadEnd, reader.revealedEnd + max(0, count))
    }

    func finishWriting() {
        guard !isTurning, !pendingLayout, reader.isWriting else { return }
        reader.revealedEnd = reader.spreadEnd
    }

    func finishTurn(revision: Int) {
        guard revision == turnRevision else { return }
        isTurning = false
    }

    var tapLabel: String {
        if isTurning { return "Turning pages" }
        if isReviewing { return "Next pages" }
        if pendingLayout || reader.isWriting { return "Finish writing" }
        if reader.hasNextSpread { return "Turn spread" }
        return "Continue"
    }

    /// A spread stays visible until all its ink is read. The next spread begins
    /// on its left leaf; the script cannot advance during the curl.
    func consumeTap() -> Bool {
        guard !isTurning, !pendingLayout else { return false }
        if isReviewing { turnForward(); return false }
        if reader.isWriting {
            finishWriting()
            return false
        }
        if reader.hasNextSpread {
            turnForward()
            return false
        }
        return true
    }
}
