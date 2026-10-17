import XCTest
@testable import HotelDuskDuoKit

final class OriginalSignProcessTests: XCTestCase {
    typealias Touch = OriginalSignProcess.Touch

    /// Right-handed raw DS touch for a rotated page point.
    private func raw(pageX: Int, pageY: Int) -> Touch { Touch(x: 255 - pageY, y: pageX) }

    private func ready() -> OriginalSignProcess {
        var sign = OriginalSignProcess()
        for _ in 0..<40 { _ = sign.update(.init()) }
        XCTAssertTrue(sign.awaitingStroke)
        return sign
    }

    /// Drag rightwards along a field's centre line, two pixels per update.
    private func stroke(_ sign: inout OriginalSignProcess, field: Int) -> [OriginalSignProcess.Effect] {
        let y = Int(OriginalSignProcess.fieldY[field] + OriginalSignProcess.fieldHeight[field] / 2)
        let x = Int(OriginalSignProcess.fieldX[field]) + 2
        var effects: [OriginalSignProcess.Effect] = []
        for step in 0..<4 { effects += sign.update(.init(heldTouch: raw(pageX: x + step * 3, pageY: y))).effects }
        effects += sign.update(.init()).effects
        while sign.stage == 2 { effects += sign.update(.init()).effects }
        return effects
    }

    func testATapDoesNotFillAField() {
        var sign = ready()
        _ = sign.update(.init(heldTouch: raw(pageX: 100, pageY: 100), newTouch: raw(pageX: 100, pageY: 100)))
        _ = sign.update(.init(heldTouch: raw(pageX: 100, pageY: 100)))
        XCTAssertEqual(sign.filled, [false, false, false, false])
    }

    func testRightwardStrokeFillsTheFieldAndDrawsToItsLimit() {
        var sign = ready()
        let effects = stroke(&sign, field: 0)
        XCTAssertEqual(sign.filled, [true, false, false, false])
        XCTAssertEqual(sign.strokes[0], 174)
        XCTAssertTrue(effects.contains(.sound(archive: 25, entry: 0)))
        XCTAssertTrue(sign.awaitingStroke)
    }

    func testCompletedCardReturnsZeroAfterItsFade() {
        var sign = ready()
        for field in 0..<4 { _ = stroke(&sign, field: field) }
        XCTAssertEqual(sign.filled, [true, true, true, true])
        var finished = false
        for _ in 0..<400 {
            let step = sign.update(.init(screen0FadeComplete: true))
            if step.status == 2 { finished = true; break }
        }
        XCTAssertTrue(finished)
        XCTAssertEqual(sign.processReturn, 0)
    }

    func testQuitReturnsTwoForABlankCardAndOneOtherwise() {
        let quit = raw(pageX: 170, pageY: 240)   // slot 5: x′ 228–252, y′ 156–188
        var blank = ready()
        _ = blank.update(.init(newTouch: quit))
        XCTAssertEqual(blank.processReturn, 2)
        var started = ready()
        _ = stroke(&started, field: 1)
        _ = started.update(.init(newTouch: quit))
        XCTAssertEqual(started.processReturn, 1)
        XCTAssertEqual(started.update(.init(screen0FadeComplete: true)).status, 0)
        XCTAssertEqual(started.update(.init(screen0FadeComplete: true)).status, 2)
    }
}
