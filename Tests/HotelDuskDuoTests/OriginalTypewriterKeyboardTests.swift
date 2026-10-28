import XCTest
@testable import HotelDuskDuoKit

final class OriginalTypewriterKeyboardTests: XCTestCase {
    func testSourceKeyRegionsAndInclusiveEdges() {
        XCTAssertEqual(OriginalTypewriterKeyboard.keys.map(\.value),
                       Array("ABCDEFGHbIJKLMNOPQRSTUVWXYZes"))
        XCTAssertEqual(OriginalTypewriterKeyboard.keys.count, 29)

        for key in OriginalTypewriterKeyboard.keys {
            XCTAssertTrue(key.contains(SIMD2(key.x, key.y)))
            XCTAssertTrue(key.contains(SIMD2(key.x + key.width, key.y + key.height)))
        }
        XCTAssertFalse(OriginalTypewriterKeyboard.keys.contains { $0.contains(SIMD2(135, 6)) })
    }

    func testKeyEntryLineAdvanceBackspaceAndSubmit() throws {
        var keyboard = OriginalTypewriterKeyboard()
        let typedKeys = Array(OriginalTypewriterKeyboard.keys.prefix(8)) +
            Array(OriginalTypewriterKeyboard.keys.dropFirst(9).prefix(7))
        for key in typedKeys {
            _ = keyboard.tap(at: SIMD2(key.x + 1, key.y + 1))
        }
        XCTAssertEqual(keyboard.text(on: 0), "ABCDEFGHIJKLMNO")
        let p = try XCTUnwrap(OriginalTypewriterKeyboard.keys.first { $0.value == "P" })
        XCTAssertEqual(keyboard.tap(at: SIMD2(p.x + 1, p.y + 1)), .inserted("P", line: 1))
        XCTAssertEqual(keyboard.text(on: 1), "P")

        let backspace = try XCTUnwrap(OriginalTypewriterKeyboard.keys.first { $0.value == "b" })
        XCTAssertEqual(keyboard.tap(at: SIMD2(backspace.x + 1, backspace.y + 1)),
                       .backspaced(line: 1))
        XCTAssertEqual(keyboard.text(on: 1), "")
        XCTAssertEqual(keyboard.tap(at: SIMD2(backspace.x + 1, backspace.y + 1)),
                       .backspaced(line: 0))
        XCTAssertEqual(keyboard.text(on: 0), "ABCDEFGHIJKLMN")

        let enter = try XCTUnwrap(OriginalTypewriterKeyboard.keys.first { $0.value == "e" })
        XCTAssertEqual(keyboard.tap(at: SIMD2(enter.x + 1, enter.y + 1)), .advancedToSecondLine)
        XCTAssertEqual(keyboard.tap(at: SIMD2(enter.x + 1, enter.y + 1)), .submit)
    }

    func testCipherUsesStoredRandomInfoAndRecoveredAnswers() {
        let first = OriginalTypewriterCipher(variant: .first, randomInfo: 0x00A7)
        XCTAssertEqual(first.expectedShift, 17)
        XCTAssertEqual(first.decode("FJKVIQFEV ZJ", shift: 17), "OSTERZONE IS")
        XCTAssertTrue(first.matchesDecodedLines(["OSTERZONE IS", "DUNNING SMITH"], shift: 17))
        XCTAssertTrue(first.matchesDecodedLines(["OSTERZONE IS DU", "NNING SMITH"], shift: 17))
        XCTAssertFalse(first.matchesDecodedLines(["OSTERZONE IS", "DUNNING SMITH"], shift: 16))

        let memento = OriginalTypewriterCipher(variant: .memento, randomInfo: 0x00A7)
        XCTAssertTrue(memento.matchesDecodedLines(["A MEMENTO IN A ", "ROOM OF LOVE"], shift: 17))
        let opening = OriginalTypewriterCipher(variant: .opening, randomInfo: 0x00A7)
        XCTAssertFalse(opening.matchesDecodedLines(["OSTERZONE IS", "DUNNING SMITH"], shift: 17))
    }

    func testTypewriterProcessAcceptsTheRecoveredTwoLineCipherAndReturnsZero() throws {
        let cipher = OriginalTypewriterCipher(variant: .first, randomInfo: 0x00A7)
        var process = OriginalTypewriterProcess(cipher: cipher)
        process.adjustShift(by: cipher.expectedShift)

        for character in "FJKVIQFEV ZJ" {
            let value: Character = character == " " ? "s" : character
            let key = try XCTUnwrap(OriginalTypewriterKeyboard.keys.first { $0.value == value })
            _ = process.tap(at: SIMD2(key.x + 1, key.y + 1))
        }
        let enter = try XCTUnwrap(OriginalTypewriterKeyboard.keys.first { $0.value == "e" })
        _ = process.tap(at: SIMD2(enter.x + 1, enter.y + 1))
        for character in "ULEEZEX JDZKY" {
            let value: Character = character == " " ? "s" : character
            let key = try XCTUnwrap(OriginalTypewriterKeyboard.keys.first { $0.value == value })
            _ = process.tap(at: SIMD2(key.x + 1, key.y + 1))
        }
        XCTAssertEqual(process.tap(at: SIMD2(enter.x + 1, enter.y + 1)), .accepted)
        XCTAssertEqual(process.result, 0)
    }

    func testTypewriterProcessKeepsWrongAndUnresolvedAnswersOpen() throws {
        let cipher = OriginalTypewriterCipher(variant: .first, randomInfo: 0x00A7)
        var wrong = OriginalTypewriterProcess(cipher: cipher)
        wrong.adjustShift(by: cipher.expectedShift)
        let enter = try XCTUnwrap(OriginalTypewriterKeyboard.keys.first { $0.value == "e" })
        _ = wrong.tap(at: SIMD2(enter.x + 1, enter.y + 1))
        XCTAssertEqual(wrong.tap(at: SIMD2(enter.x + 1, enter.y + 1)),
                       .rejected(decodedLines: ["", ""]))
        XCTAssertNil(wrong.result)

        var opening = OriginalTypewriterProcess(cipher: .init(variant: .opening, randomInfo: 0x00A7))
        _ = opening.tap(at: SIMD2(enter.x + 1, enter.y + 1))
        XCTAssertEqual(opening.tap(at: SIMD2(enter.x + 1, enter.y + 1)), .unresolvedVariant)
        XCTAssertNil(opening.result)
    }

    func testTypewriterShiftWrapsAndExitReturnsTwo() {
        var process = OriginalTypewriterProcess(cipher: .init(variant: .first, randomInfo: 0))
        process.adjustShift(by: -1)
        XCTAssertEqual(process.shift, 29)
        process.adjustShift(by: 31)
        XCTAssertEqual(process.shift, 0)
        XCTAssertEqual(process.requestExit(), 2)
    }
}
