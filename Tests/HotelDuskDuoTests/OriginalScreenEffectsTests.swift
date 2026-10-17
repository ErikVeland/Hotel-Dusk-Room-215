import XCTest
@testable import HotelDuskDuoKit

final class OriginalScreenEffectsTests: XCTestCase {
    func testOpeningBrightnessMatchesTwelveSuccessiveROMFrames() throws {
        var effects = OriginalScreenEffects.opening
        var queue = OriginalCinematicQueue(program: try .bundledOpening())
        // init04...init15 RAM, screen controller0x0210BC08+0x190.
        let source: [(Int32, Int32, UInt16, Bool, Bool)] = [
            (65536,-65536,0,false,false), (65536,-65536,0,false,false),
            (65536,-65536,0,false,false), (65536,-65536,0,false,false),
            (65536,-65536,1,true,true), (65536,-65536,1,true,false),
            (65536,-65536,0,false,false), (1365,-65536,48,true,true),
            (1365,-65536,48,true,false), (1365,-66901,47,true,false),
            (1365,-68266,46,true,false), (1365,-69631,45,true,false)
        ]
        for expected in source {
            effects.advanceOriginalFrame()
            try queue.update { record, _ in
                if let result = try effects.apply(record) { return result }
                XCTAssertTrue(record.handlerAddress == 0x020A3F84 || record.handlerAddress == 0x020A3FCC)
                return .complete
            }
            for screen in effects.brightness {
                XCTAssertEqual(screen.step, expected.0)
                XCTAssertEqual(screen.value, expected.1)
                XCTAssertEqual(screen.remaining, expected.2)
                XCTAssertEqual(screen.active, expected.3)
                XCTAssertEqual(screen.firstUpdate, expected.4)
                XCTAssertEqual(screen.mask, 63)
                XCTAssertEqual(screen.mode, 2)
            }
        }
    }

    func testFadeCheckpointPreservesFirstUpdateAndFixedPointRounding() throws {
        var effect = OriginalScreenEffects()
        try effect.beginBrightness(screen: 0, mask: 63, mode: 3, from: -16, frames: 30)
        let data = try JSONEncoder().encode(effect)
        var restored = try JSONDecoder().decode(OriginalScreenEffects.self, from: data)
        XCTAssertEqual(restored, effect)
        restored.advanceOriginalFrame()
        XCTAssertEqual(restored.brightness[0].value, -65536)
        XCTAssertEqual(restored.brightness[0].step, 2185)
        for _ in 0..<29 { restored.advanceOriginalFrame() }
        XCTAssertTrue(restored.brightness[0].active)
        restored.advanceOriginalFrame()
        XCTAssertFalse(restored.brightness[0].active)
        XCTAssertEqual(restored.brightness[0].value, 0)
    }

    func testAlphaSourceFixedEndpointsAndEightUnitToggle() throws {
        var effect = OriginalScreenEffects()
        try effect.beginAlpha(screen: 1, firstMask: 4, secondMask: 8, mode: 0, frames: 48)
        XCTAssertEqual(effect.alpha[1].step, 1365)
        for _ in 0..<48 { effect.advanceOriginalFrame() }
        XCTAssertEqual(effect.alpha[1].firstCoefficient, 16)
        XCTAssertEqual(effect.alpha[1].secondCoefficient, 0)
        try effect.beginAlpha(screen: 1, firstMask: 4, secondMask: 8, mode: 2, frames: 10)
        for _ in 0..<10 { effect.advanceOriginalFrame() }
        XCTAssertEqual(effect.alpha[1].value, 0)
        try effect.beginAlpha(screen: 1, firstMask: 4, secondMask: 8, mode: 2, frames: 10)
        for _ in 0..<10 { effect.advanceOriginalFrame() }
        XCTAssertEqual(effect.alpha[1].firstCoefficient, 8)
    }
}
