import XCTest
import CoreText
@testable import HotelDuskDuoKit

@MainActor
final class DialogueNotebookTests: XCTestCase {
    func testSourceParticipantsSurviveWrappingAndKeepSemanticColours() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102")
        let book = DialogueNotebook()
        for start in [120, 178, 181, 184] {
            let entries = Array(program.text.entries[start..<(start + 3)])
            let tokens = try entries.flatMap { entry in
                try OriginalDialogueControl.tokens(for: entry) + [
                    OriginalDialogueToken(textIndex: entry.index, byteOffset: entry.bytes.count, kind: .glyph(10))
                ]
            }
            book.record(.itemNotice(itemID: 1, page: .init(page: 0, entries: entries, tokens: tokens)), program: program.name)
        }
        XCTAssertTrue(book.ink.contains { $0.person == 1 && $0.colour == 2 && $0.text.contains("Dunning Smith?") })
        XCTAssertTrue(book.ink.contains { $0.person == 2 && $0.text.contains("just t'hear me jaw?") })
        let styled = layout(book, width: 140, height: 115)
        func ink(_ phrase: String) throws -> CGColor {
            let range = (styled.text.string as NSString).range(of: phrase)
            XCTAssertNotEqual(range.location, NSNotFound)
            return try XCTUnwrap(styled.text.attribute(NSAttributedString.Key(kCTForegroundColorAttributeName as String),
                                                      at: range.location, effectiveRange: nil)) as! CGColor
        }
        XCTAssertNotEqual(try ink("So! Ya"), try ink("A room."))
        XCTAssertEqual(try ink("So! Ya"), try ink("What kinda"))
        XCTAssertEqual(try ink("Dunning Smith?"), CGColor(red: 0.20, green: 0.27, blue: 0.42, alpha: 1))
        let neutral = DialogueNotebookLayout(runs: book.ink.map { .init(text: $0.text, colour: $0.colour) },
                                            size: styled.size, fontSize: 18)
        XCTAssertEqual(styled.pages, neutral.pages, "Speaker ink must not change pagination")
        XCTAssertEqual(styled.text.string, neutral.text.string)

        let emphasis = DialogueNotebookLayout(runs: [.init(text: "Keyword", colour: 1, person: 2)],
                                             size: styled.size, fontSize: 18)
        XCTAssertEqual(try XCTUnwrap(emphasis.text.attribute(NSAttributedString.Key(kCTForegroundColorAttributeName as String),
                                              at: 0, effectiveRange: nil)) as! CGColor,
                       CGColor(red: 0.48, green: 0.19, blue: 0.15, alpha: 1))
    }

    func testInlineParticipantOverridesPresentationWithoutLeakingToNextPage() throws {
        let entry = OriginalTextTable.Entry(index: 0, offset: 0, bytes: Data("First %p0000201second".utf8))
        let page = OriginalDialoguePacket.Page(page: 0, entries: [entry], tokens: try OriginalDialogueControl.tokens(for: entry))
        let lines = OriginalDialogueLines(page: page, person: 1)
        XCTAssertEqual(lines.lines.first?.map(\.person), [1, 2])
        let unattributed = OriginalDialoguePacket.Page(page: 0, entries: [], tokens: [.init(textIndex: 0, byteOffset: 0, kind: .glyph(65))])
        XCTAssertNil(OriginalDialogueLines(page: unattributed).lines.first?.first?.person)
    }

    func testWritingRevealsFixedGlyphsWithoutMovingEarlierInk() throws {
        let layout = DialogueNotebookLayout(runs: [.init(text: "Office files. The name's Kyle Hyde.\n\nA second paragraph.", colour: 0)],
                                            size: CGSize(width: 240, height: 180), fontSize: 18)
        let page = try XCTUnwrap(layout.pages.first)
        func pixels(_ end: Int) throws -> [UInt8] {
            let context = try XCTUnwrap(CGContext(data: nil, width: 240, height: 180,
                bitsPerComponent: 8, bytesPerRow: 960, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            layout.draw(page: page, revealedEnd: end, in: context)
            return Array(UnsafeBufferPointer(start: try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self), count: 240 * 180 * 4))
        }
        let blank = try pixels(0)
        let partial = try pixels(13)
        let full = try pixels(NSMaxRange(page))
        let alphas = stride(from: 3, to: full.count, by: 4)
        XCTAssertTrue(alphas.allSatisfy { blank[$0] == 0 })
        XCTAssertGreaterThan(alphas.filter { partial[$0] > 0 }.count, 0)
        XCTAssertLessThan(alphas.filter { partial[$0] > 0 }.count, alphas.filter { full[$0] > 0 }.count)
        for offset in alphas where partial[offset] > 0 {
            XCTAssertEqual(partial[offset], full[offset], "Written glyphs must stay in place")
        }
    }

    private func phase(_ text: String, screen: UInt8 = 1) -> OriginalEventRunner.Phase {
        let tokens = Array(text.utf8).enumerated().map {
            OriginalDialogueToken(textIndex: 0, byteOffset: $0.offset, kind: .glyph($0.element))
        }
        return .itemNotice(itemID: 1, page: .init(page: screen, entries: [], tokens: tokens))
    }

    private func layout(_ book: DialogueNotebook, width: CGFloat = 240, height: CGFloat = 300, fontSize: CGFloat = 18) -> DialogueNotebookLayout {
        DialogueNotebookLayout(runs: book.ink, size: CGSize(width: width, height: height), fontSize: fontSize)
    }

    func testPassagesAccumulateWithoutRepeatingOnResume() {
        let book = DialogueNotebook()
        let first = phase("It's been three years since\nI quit the force.\n\n")
        book.record(first, program: "opening")
        book.record(first, program: "opening")
        XCTAssertEqual(layout(book).text.string, "It's been three years since I quit the force.")
        book.record(phase("The name's Kyle Hyde."), program: "opening")
        XCTAssertEqual(layout(book).text.string, "It's been three years since I quit the force.\n\nThe name's Kyle Hyde.")
        book.endPresentation()
        book.record(phase("The name's Kyle Hyde."), program: "opening")
        XCTAssertEqual(layout(book).text.string.components(separatedBy: "The name's Kyle Hyde.").count, 3,
                       "A line spoken again is a new passage, even when its bytes match")
    }

    func testTapFinishesBothLeavesThenTurnsEveryOverflowSpread() {
        let book = DialogueNotebook()
        book.record(phase(String(repeating: "The name's Kyle Hyde. ", count: 40)), program: "opening")
        XCTAssertFalse(book.consumeTap(), "A rapid second tap must wait for pagination")
        let laidOut = layout(book, width: 140, height: 115)
        XCTAssertGreaterThan(laidOut.pages.count, 3)
        book.configure(laidOut)
        XCTAssertFalse(book.canTurnForward, "A swipe must not skip unwritten text")
        book.turnForward()
        XCTAssertEqual(book.reader.spreadIndex, 0)
        for index in stride(from: 0, to: laidOut.pages.count, by: 2) {
            XCTAssertEqual(book.reader.leftIndex, index)
            XCTAssertEqual(book.tapLabel, "Finish writing")
            XCTAssertFalse(book.consumeTap())
            XCTAssertEqual(book.reader.revealedEnd, book.reader.spreadEnd)
            if index + 2 < laidOut.pages.count {
                XCTAssertEqual(book.tapLabel, "Turn spread")
                XCTAssertFalse(book.consumeTap())
                XCTAssertTrue(book.isTurning)
                let end = book.reader.revealedEnd
                book.write(count: 100)
                XCTAssertEqual(book.reader.revealedEnd, end)
                XCTAssertFalse(book.consumeTap(), "Rapid taps cannot skip the curl")
                book.finishTurn(revision: book.turnRevision - 1)
                XCTAssertTrue(book.isTurning, "Stale animation completions cannot unlock input")
                book.finishTurn(revision: book.turnRevision)
            }
        }
        XCTAssertEqual(book.tapLabel, "Continue")
        XCTAssertTrue(book.consumeTap())
    }

    func testWritingCrossesFromLeftToRightWithoutTurning() {
        let book = DialogueNotebook()
        book.record(phase(String(repeating: "A room at Hotel Dusk. ", count: 20), screen: 0), program: "opening")
        let laidOut = layout(book, width: 140, height: 115)
        book.configure(laidOut)
        let leftEnd = NSMaxRange(laidOut.pages[0])
        book.write(count: leftEnd - 1)
        XCTAssertLessThan(book.reader.revealedEnd, laidOut.pages[1].location)
        book.write(count: 1)
        XCTAssertEqual(book.reader.revealedEnd, laidOut.pages[1].location)
        book.write(count: 1)
        XCTAssertEqual(book.reader.revealedEnd, laidOut.pages[1].location + 1)
        XCTAssertEqual(book.reader.spreadIndex, 0)
        XCTAssertFalse(book.isTurning)
    }

    func testPaginationPreservesEveryCharacterAtDifferentSizes() {
        let runs = [OriginalDialogueLines.Run(text: String(repeating: "A long passage with names, emphasis, and several lines.\n\n", count: 30), colour: 1)]
        for fontSize: CGFloat in [18, 28, 38] {
            for width: CGFloat in [160, 300, 420] {
                let layout = DialogueNotebookLayout(runs: runs, size: CGSize(width: width, height: 400), fontSize: fontSize)
                var end = 0
                for page in layout.pages {
                    XCTAssertEqual(page.location, end)
                    XCTAssertGreaterThan(page.length, 0)
                    end = NSMaxRange(page)
                }
                XCTAssertEqual(end, layout.text.length)
                XCTAssertEqual(layout.pages.map { layout.accessibleText(page: $0) }.joined(), runs[0].text)
            }
        }
    }

    func testReadingPositionSurvivesRemountResizeAndNewPassages() {
        let book = DialogueNotebook()
        book.record(phase(String(repeating: "A room at Hotel Dusk. ", count: 35)), program: "opening")
        let original = layout(book, height: 140)
        book.configure(original)
        XCTAssertFalse(book.consumeTap())
        XCTAssertFalse(book.consumeTap())
        book.finishTurn(revision: book.turnRevision)
        book.write(count: 12)
        let before = book.reader
        book.configure(original)
        XCTAssertEqual(book.reader, before)
        let resized = layout(book, width: 180, height: 160, fontSize: 24)
        book.configure(resized)
        let after = book.reader
        let anchor = before.page(at: before.leftIndex).location
        XCTAssertTrue(NSLocationInRange(anchor, after.page(at: after.leftIndex)) ||
                      NSLocationInRange(anchor, after.page(at: after.leftIndex + 1)))
        XCTAssertEqual(after.revealedEnd, before.revealedEnd)
        XCTAssertFalse(book.isTurning)
        book.record(phase("The next passage."), program: "opening")
        book.configure(layout(book, width: 180, height: 160, fontSize: 24))
        XCTAssertEqual(book.reader.leftIndex, after.leftIndex)
        XCTAssertEqual(book.reader.revealedEnd, before.revealedEnd)
    }

    func testFoldSizeRoundTripDoesNotDriftToEarlierPages() {
        let book = DialogueNotebook()
        book.record(phase(String(repeating: "A room at Hotel Dusk. ", count: 70)), program: "opening")
        let original = layout(book, width: 140, height: 115)
        book.configure(original)
        for _ in 0..<3 {
            book.finishWriting()
            book.turnForward()
            book.finishTurn(revision: book.turnRevision)
        }
        book.write(count: 12)
        let before = book.reader
        for _ in 0..<4 {
            book.configure(layout(book, width: 420, height: 700))
            book.configure(layout(book, width: 0, height: 0))
            book.configure(layout(book, width: 180, height: 300))
            book.configure(original)
            XCTAssertEqual(book.reader, before, "Repeated fold layouts must preserve the source bookmark")
        }
    }

    func testPreviousPagesRetainInkAndReturnToUnfinishedPassage() {
        let book = DialogueNotebook()
        book.record(phase(String(repeating: "A room at Hotel Dusk. ", count: 70)), program: "opening")
        book.configure(layout(book, width: 140, height: 115))
        book.finishWriting()
        book.turnForward()
        book.finishTurn(revision: book.turnRevision)
        book.write(count: 12)
        let before = book.reader
        XCTAssertTrue(book.canTurnBack)
        book.turnBack()
        XCTAssertTrue(book.turnsBackward)
        XCTAssertEqual(book.turnFromSpread, 1)
        XCTAssertEqual(book.reader.spreadIndex, 0)
        XCTAssertEqual(book.reader.revealedEnd, before.revealedEnd)
        book.finishTurn(revision: book.turnRevision)
        XCTAssertFalse(book.consumeTap(), "Reading old pages must not advance the script")
        XCTAssertFalse(book.turnsBackward)
        book.finishTurn(revision: book.turnRevision)
        XCTAssertEqual(book.reader, before)
    }

    func testHistoryCannotRevealFutureInkAndRestoresItsBookmarkDuringATurn() {
        let book = DialogueNotebook()
        book.record(phase(String(repeating: "A room at Hotel Dusk. ", count: 70)), program: "opening")
        book.configure(layout(book, width: 140, height: 115))
        book.finishWriting()
        book.turnForward()
        book.finishTurn(revision: book.turnRevision)
        book.write(count: 12)
        let before = book.reader
        book.beginReview()
        XCTAssertFalse(book.canTurnForward, "History must stop at the last revealed spread")
        XCTAssertFalse(book.consumeTap())
        XCTAssertEqual(book.reader, before)
        book.turnBack()
        let interruptedRevision = book.turnRevision
        book.endReview()
        XCTAssertFalse(book.isTurning)
        XCTAssertEqual(book.reader, before)
        book.finishTurn(revision: interruptedRevision)
        XCTAssertEqual(book.reader, before)
    }

    func testChoiceShowsTheResponseWithoutAnotherContinue() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner.chapterOneArrival(catalog: catalog, defaults: .bundled())
        while case .dialogue = runner.phase { runner.acknowledgeDialogue() }
        runner.finishProcess(returnValue: 0)
        while case .dialogue = runner.phase { runner.acknowledgeDialogue() }
        runner.lookInSearchView(area: 2, subarea: 2, table: try .bundled(map: "R102"))
        runner.acknowledgeDialogue()
        runner.finishProcess(returnValue: 0)
        while case .dialogue = runner.phase { runner.acknowledgeDialogue() }
        guard case .choice(let choices) = runner.phase else { return XCTFail("Expected the suite offer") }
        for choice in choices {
            let audio = AudioController()
            audio.isMuted = true
            let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
            defer { play.stop() }
            let book = play.dialogueNotebook
            book.record(phase(String(repeating: "An earlier conversation. ", count: 70)), program: "opening")
            book.configure(layout(book, width: 140, height: 115))
            play.choose(choice.id)
            guard case .dialogue(let response) = play.runner.phase else { return XCTFail("Expected the response") }
            let text = response.pages.flatMap { OriginalDialogueLines(page: $0).lines }
                .map { $0.map(\.text).joined() }.joined(separator: " ")
            XCTAssertNotEqual(text.trimmingCharacters(in: .whitespacesAndNewlines), choice.label,
                              "Selecting an answer must also acknowledge its repeated line")
            book.configure(layout(book, width: 140, height: 115))
            XCTAssertGreaterThan(book.reader.spreadIndex, 0, "The response must appear immediately after a choice")
            XCTAssertTrue(book.reader.isWriting)
            XCTAssertLessThanOrEqual(book.reader.page(at: book.reader.leftIndex).location, book.reader.revealedEnd)
        }
    }

    func testFoldPausesAtTheSameDialogueAndHistoryIsBlockedByPuzzles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = GameSession(saveStore: OriginalChapterFileStore(directory: root),
                                  resumeStore: OriginalResumeFileStore(directory: root))
        session.startOriginalGame()
        defer { session.endOriginalGame() }
        let play = try XCTUnwrap(session.play)
        let book = play.dialogueNotebook
        for _ in 0..<10 where book.ink.isEmpty { play.advanceDialogue() }
        XCTAssertFalse(book.ink.isEmpty)
        book.configure(layout(book, width: 140, height: 115))
        book.write(count: 12)
        let reader = book.reader
        let phase = play.runner.phase
        session.hingeManager.setHingeAngle(0)
        XCTAssertTrue(play.isPaused)
        session.setApplicationActive(false)
        session.hingeManager.setHingeAngle(70)
        XCTAssertTrue(play.isPaused)
        session.setApplicationActive(true)
        XCTAssertFalse(play.isPaused)
        XCTAssertEqual(play.runner.phase, phase)
        XCTAssertEqual(book.reader, reader)
        session.reviewConversations()
        XCTAssertTrue(session.isReviewingConversations)
        XCTAssertTrue(play.isPaused)
        session.closeConversationHistory()
        XCTAssertFalse(play.isPaused)
        // The entrance is a mandatory interactive process after the opening.
        for _ in 0..<20 {
            guard case .dialogue = play.runner.phase else { break }
            play.advanceDialogue()
        }
        guard case .process = play.runner.phase else { return XCTFail("Expected the entrance process") }
        XCTAssertFalse(play.canReviewConversations)
        session.reviewConversations()
        XCTAssertFalse(session.isReviewingConversations)
    }

    func testOriginalScreensShareOneChronologicalTranscript() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102")
        let records = try program.blocks.operations(forEvent: 0)
        let packet = try OriginalDialoguePacket(record: records[2], following: records[3], text: program.text)
        let book = DialogueNotebook()
        book.record(.dialogue(packet), program: program.name)
        let expected = packet.pages.map { page in
            OriginalDialogueLines(page: page).lines.filter { !$0.allSatisfy { $0.text.trimmingCharacters(in: .whitespaces).isEmpty } }
                .map { $0.map(\.text).joined() }.joined(separator: " ")
        }.filter { !$0.isEmpty }.joined(separator: "\n\n")
        XCTAssertEqual(layout(book).text.string, expected)
        book.record(phase("A notice from the right screen.", screen: 0), program: "opening")
        book.record(phase("Then the left screen.", screen: 1), program: "opening")
        XCTAssertTrue(layout(book).text.string.hasSuffix("A notice from the right screen.\n\nThen the left screen."))
    }

    func testCurlBeginsAndEndsFlatWithAnUprightReverse() {
        let size = CGSize(width: 300, height: 600)
        for u: CGFloat in [0, 0.25, 0.5, 1] {
            let start = NotebookCurlGeometry.point(u: u, v: 0, progress: 0, pageSize: size)
            let end = NotebookCurlGeometry.point(u: u, v: 1, progress: 1, pageSize: size)
            XCTAssertEqual(start.position.x, 300 + u * 300, accuracy: 0.001)
            XCTAssertEqual(start.position.y, 0, accuracy: 0.001)
            XCTAssertTrue(start.facesFront)
            XCTAssertEqual(end.position.x, 300 - u * 300, accuracy: 0.001)
            XCTAssertEqual(end.position.y, 600, accuracy: 0.001)
            XCTAssertFalse(end.facesFront)
        }
        XCTAssertGreaterThan(NotebookCurlGeometry.point(u: 1, v: 0, progress: 0.5, pageSize: size).depth, 0)
    }

    func testSessionRecordsBeforeRenderingAndDoesNotSkipUnwrittenDialogue() throws {
        let audio = AudioController()
        audio.isMuted = true
        let play = try OriginalPlaySession.chapterOne(audio: audio)
        defer { play.stop() }
        for _ in 0..<10 where play.dialogueNotebook.ink.isEmpty { play.advanceDialogue() }
        let before = play.runner.phase
        play.advanceWrittenDialogue()
        XCTAssertEqual(play.runner.phase, before)
        play.dialogueNotebook.configure(layout(play.dialogueNotebook))
        play.advanceWrittenDialogue()
        XCTAssertEqual(play.runner.phase, before, "First tap finishes the ink")
        play.pause()
        let ink = play.dialogueNotebook.ink
        play.resume()
        XCTAssertEqual(play.dialogueNotebook.ink, ink)
        play.advanceWrittenDialogue()
        XCTAssertNotEqual(play.runner.phase, before, "The next tap acknowledges the source packet")
    }
}
