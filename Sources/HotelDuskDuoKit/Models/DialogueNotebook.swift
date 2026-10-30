import Foundation
import Combine

/// One transcript and one reading cursor for the physical book spread.
@MainActor
final class DialogueNotebook: ObservableObject {
    struct SavedState: Codable, Equatable, Sendable {
        struct Ink: Codable, Equatable, Sendable {
            let text: String
            let colour: UInt8
            let person: Int32?
            var verbatim: Bool? = nil
        }
        let ink: [Ink]
        let readingAnchor: Int
        let revealedEnd: Int
        var reviewAnchor: Int? = nil
        var retraceEnd: Int? = nil
        var furthestRevealedEnd: Int? = nil
        var reviewPassageEnd: Int? = nil
        var reviewRevealedEnd: Int? = nil
    }

    var onSaveProgress: ((Bool) -> Void)?

    func savedState() -> SavedState {
        SavedState(ink: ink.map { .init(text: $0.text, colour: $0.colour, person: $0.person, verbatim: $0.verbatim) },
            readingAnchor: isTurning && (isHoldingTurn || !turnWillComplete) ? turnAnchor : readingAnchor,
            revealedEnd: reader.revealedEnd, reviewAnchor: reviewAnchor,
            retraceEnd: reader.passageEnd, furthestRevealedEnd: max(furthestRevealedEnd, reader.revealedEnd),
            reviewPassageEnd: reviewPassageEnd, reviewRevealedEnd: reviewRevealedEnd)
    }

    func restore(_ saved: SavedState) {
        ink = saved.ink.map { .init(text: $0.text, colour: $0.colour, person: $0.person, verbatim: $0.verbatim ?? false) }
        readingAnchor = saved.readingAnchor
        reader = Reader(revealedEnd: saved.revealedEnd, passageEnd: saved.retraceEnd)
        furthestRevealedEnd = saved.furthestRevealedEnd ?? saved.revealedEnd
        layout = nil
        pendingLayout = !ink.isEmpty
        isHoldingTurn = false
        isTurning = false
        reviewAnchor = saved.reviewAnchor
        reviewPassageEnd = saved.reviewPassageEnd
        reviewRevealedEnd = saved.reviewRevealedEnd
    }
    struct Reader: Equatable {
        var pages: [NSRange] = []
        var spreadIndex = 0
        var revealedEnd = 0
        var passageEnd: Int?
        var pagesPerSpread = 2
        var leftIndex: Int { spreadIndex * pagesPerSpread }
        func page(at index: Int) -> NSRange {
            pages.indices.contains(index) ? pages[index] : NSRange(location: pages.last.map(NSMaxRange) ?? 0, length: 0)
        }
        var spreadEnd: Int {
            let end = NSMaxRange(page(at: leftIndex + pagesPerSpread - 1))
            return min(end, passageEnd ?? end)
        }
        var isWriting: Bool { revealedEnd < spreadEnd }
        var hasNextSpread: Bool {
            leftIndex + pagesPerSpread < pages.count &&
                page(at: leftIndex + pagesPerSpread).location < (passageEnd ?? Int.max)
        }
    }

    @Published private(set) var passageRevision = 0
    @Published private(set) var ink: [OriginalDialogueLines.Run] = []
    @Published private(set) var reader = Reader()
    @Published private(set) var layout: DialogueNotebookLayout?
    @Published private(set) var isTurning = false
    @Published private(set) var isHoldingTurn = false
    @Published private(set) var turnProgress = 0.0
    private(set) var turnWillComplete = true
    private var turnAnchor = 0
    private(set) var turnRevision = 0
    private var lastPhase: OriginalEventRunner.Phase?
    private var lastProgram: String?
    private var pendingLayout = false
    // Keep the source offset across temporary cover sizes and repeated reflows.
    private var readingAnchor = 0
    private var followsNextPassage = false
    private var furthestRevealedEnd = 0
    private var reviewAnchor: Int?
    private var reviewPassageEnd: Int?
    private var reviewRevealedEnd: Int?
    private(set) var turnFromSpread = 0
    var turnsBackward: Bool { turnFromSpread > reader.spreadIndex }
    var isReviewing: Bool { reviewAnchor != nil }
    var canTurnBack: Bool {
        !pendingLayout && !isTurning && reader.spreadIndex > 0
    }
    var canTurnForward: Bool {
        !pendingLayout && !isTurning && !reader.isWriting && reader.hasNextSpread &&
            (!isReviewing || reader.page(at: reader.leftIndex + reader.pagesPerSpread).location < reader.revealedEnd)
    }

    func followNextPassage() { followsNextPassage = true }

    func beginReview() {
        guard reviewAnchor == nil else { return }
        reviewAnchor = readingAnchor
        reviewPassageEnd = reader.passageEnd
        reviewRevealedEnd = reader.revealedEnd
        reader.passageEnd = nil
        reader.revealedEnd = max(reader.revealedEnd, furthestRevealedEnd)
    }

    func endReview() {
        guard let anchor = reviewAnchor else { return }
        reviewAnchor = nil
        reader.passageEnd = reviewPassageEnd
        reader.revealedEnd = reviewRevealedEnd ?? reader.revealedEnd
        reviewPassageEnd = nil
        reviewRevealedEnd = nil
        if isTurning {
            turnRevision += 1
            isTurning = false
            isHoldingTurn = false
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
        turnAnchor = readingAnchor
        turnProgress = 0
        turnWillComplete = true
        turnFromSpread = reader.spreadIndex
        turnRevision += 1
        isTurning = true
        reader.spreadIndex = spread
        readingAnchor = reader.page(at: reader.leftIndex).location
    }

    @discardableResult
    func beginInteractiveTurn(backward: Bool) -> Bool {
        guard backward ? canTurnBack : canTurnForward else { return false }
        isHoldingTurn = true
        turn(to: reader.spreadIndex + (backward ? -1 : 1))
        return true
    }

    func updateInteractiveTurn(progress: Double) {
        guard isTurning, isHoldingTurn else { return }
        turnProgress = min(1, max(0, progress))
    }

    func releaseInteractiveTurn(commit: Bool) {
        guard isTurning, isHoldingTurn else { return }
        turnWillComplete = commit
        isHoldingTurn = false
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
        var passage: [OriginalDialogueLines.Run] = []
        for page in pages {
            let person = presentations.first { $0.page == page.page }.map { Int32($0.person) }
            let paragraph = OriginalDialogueLines(page: page, person: person).paragraph
            guard !paragraph.isEmpty else { continue }
            if !passage.isEmpty { passage.append(.init(text: "\n\n", colour: 0)) }
            passage.append(contentsOf: paragraph)
        }
        guard !passage.isEmpty else { return }
        passageRevision += 1
        furthestRevealedEnd = max(furthestRevealedEnd, reader.revealedEnd)
        if let index = ink.indices.first(where: { start in
            start + passage.count <= ink.count && Array(ink[start..<(start + passage.count)]) == passage
        }) {
            readingAnchor = ink[..<index].reduce(0) { $0 + ($1.text as NSString).length }
            reader.passageEnd = readingAnchor + passage.reduce(0) { $0 + ($1.text as NSString).length }
            reader.revealedEnd = readingAnchor
            followsNextPassage = false
            pendingLayout = true
            if let layout { configure(layout, singlePage: reader.pagesPerSpread == 1) }
            return
        }
        let wasRetracing = reader.passageEnd != nil
        reader.passageEnd = nil
        reader.revealedEnd = max(reader.revealedEnd, furthestRevealedEnd)
        if followsNextPassage || wasRetracing {
            readingAnchor = ink.reduce(0) { $0 + ($1.text as NSString).length } + (ink.isEmpty ? 0 : 2)
            reader.revealedEnd = max(reader.revealedEnd, readingAnchor)
            followsNextPassage = false
        }
        var next = ink
        if !next.isEmpty { next.append(.init(text: "\n\n", colour: 0)) }
        next.append(contentsOf: passage)
        pendingLayout = true
        ink = next
    }

    func configure(_ layout: DialogueNotebookLayout, singlePage: Bool = false) {
        // Empty cover geometry must not discard the last usable pagination.
        guard !layout.pages.isEmpty || ink.isEmpty else { return }
        let anchor = readingAnchor
        var next = reader
        next.pages = layout.pages
        next.pagesPerSpread = singlePage ? 1 : 2
        let anchorPage = layout.pages.firstIndex { NSLocationInRange(anchor, $0) } ?? max(0, layout.pages.count - 1)
        next.spreadIndex = anchorPage / next.pagesPerSpread
        if isTurning, next.pages != reader.pages {
            let sourceAnchor = isHoldingTurn || !turnWillComplete ? turnAnchor : readingAnchor
            let sourcePage = layout.pages.firstIndex { NSLocationInRange(sourceAnchor, $0) } ?? max(0, layout.pages.count - 1)
            next.spreadIndex = sourcePage / next.pagesPerSpread
            readingAnchor = sourceAnchor
            turnRevision += 1
            isTurning = false
            isHoldingTurn = false
        }
        self.layout = layout
        reader = next
        pendingLayout = !ink.isEmpty && layout.pages.isEmpty
    }

    func write(count: Int = 2) {
        guard !isTurning, !pendingLayout, reader.isWriting else { return }
        reader.revealedEnd = min(reader.spreadEnd, reader.revealedEnd + max(0, count))
        onSaveProgress?(false)
    }

    func finishWriting() {
        guard !isTurning, !pendingLayout, reader.isWriting else { return }
        reader.revealedEnd = reader.spreadEnd
        onSaveProgress?(true)
    }

    func finishTurn(revision: Int, completed: Bool? = nil) {
        guard revision == turnRevision else { return }
        if isTurning, !(completed ?? turnWillComplete) {
            reader.spreadIndex = turnFromSpread
            readingAnchor = turnAnchor
        }
        isHoldingTurn = false
        isTurning = false
        onSaveProgress?(true)
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
