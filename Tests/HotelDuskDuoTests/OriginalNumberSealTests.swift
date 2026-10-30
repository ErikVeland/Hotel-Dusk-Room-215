import CoreGraphics
import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalNumberSealTests: XCTestCase {
    private final class MapRenderer: OriginalMapRendering {
        let map: CGImage

        init() throws {
            map = try XCTUnwrap(CGContext(data: nil, width: 192, height: 256,
                bitsPerComponent: 8, bytesPerRow: 768, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage())
        }

        func render(_ state: OriginalMapExploration, game: OriginalGameState) throws -> CGImage { map }
    }

    private func stickerRunner() throws -> OriginalEventRunner {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(2, previous: 3)
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"),
            game: game, deferArrival: true)
        runner.lookInSearchView(area: 1, subarea: 12, table: try .bundled(map: "R102"))
        var response = try XCTUnwrap(runner.searchFallback(catalog: catalog))
        XCTAssertEqual(response.eventIndex, 228)
        for _ in 0..<20 {
            guard case .dialogue = response.phase else { break }
            response.acknowledgeDialogue()
        }
        XCTAssertEqual(response.eventIndex, 229)
        XCTAssertEqual(response.phase, .process(id: 87))
        return response
    }

    private func session() throws -> OriginalPlaySession {
        let audio = AudioController()
        audio.isMuted = true
        return try OriginalPlaySession(runner: stickerRunner(), audio: audio, catalog: .bundled(),
            puzzleSeed: { 42 }, mapRendererFactory: { _, _ in try MapRenderer() })
    }

    func testVendingMachineStickerStartsSystemEvent229WithoutHalting() throws {
        let play = try session()
        defer { play.stop() }
        XCTAssertEqual(play.runner.phase, .process(id: 87))
        XCTAssertNotNil(play.numberSeal)
        XCTAssertEqual(play.numberSealImage?.width, 192)
        XCTAssertEqual(play.numberSealImage?.height, 256)
    }

    func testRoomSpecificCluesUseSavedRandomValueAndSecondPlayShift() {
        for (map, random, shifted, expected): (Int16, UInt16, Bool, Int) in [
            (2, 1, false, 11), (3, 1, false, -40), (17, 10, false, -43),
            (26, 1, false, -49), (4, 1, false, 33), (5, 1, false, 22),
            (39, 1, false, 34), (2, 9, true, 10), (17, 2, true, 22)
        ] {
            XCTAssertEqual(OriginalNumberSealProcess(mapID: map, randomInfo: random, shifted: shifted).number,
                expected)
        }
    }

    func testStickerArtworkKeepsTheNumberUprightInsideTheStar() throws {
        let process = OriginalNumberSealProcess(mapID: 3, randomInfo: 10, shifted: false)
        let renderer = try OriginalNumberSealRenderer(process: process, library: .bundled())
        let pixels = try XCTUnwrap(renderer.image.dataProvider?.data) as Data
        XCTAssertEqual(OriginalScriptCatalog.digest(pixels),
            "b999943c8a52c66526bf0e4a775e564e75aea639b4d9fdfd62ed7017d5aa9896")
    }

    func testStickerWaitsForExitAndReturnsAfterFade() {
        var process = OriginalNumberSealProcess(mapID: 2, randomInfo: 1, shifted: false)
        for _ in 0..<60 { process.update(touch: .init(172, 240)) }
        XCTAssertEqual(process.phase, .awaitingExit)
        for _ in 0..<120 { process.update() }
        XCTAssertNil(process.result)
        process.update(touch: .init(100, 100))
        XCTAssertEqual(process.phase, .awaitingExit)
        process.update(touch: .init(172, 240))
        XCTAssertEqual(process.phase, .fadingOut(remaining: 60))
        for _ in 0..<59 { process.update() }
        XCTAssertNil(process.result)
        process.update()
        XCTAssertEqual(process.result, 2)
    }

    func testEncodedInteractionReplayKeepsClueAndReturnsToExploration() throws {
        let play = try session()
        let restored = try session()
        defer { play.stop(); restored.stop() }
        let clue = try XCTUnwrap(play.numberSeal?.number)
        let randomState = Array(play.runner.game.bytes[0x13D4..<0x13D6])
        let inputs: [OriginalProgressInput] = [
            .frames(count: 60, microphone: 0),
            .touchNumberSeal(pageX: 172, pageY: 240),
            .frames(count: 61, microphone: 0)
        ]
        let encoded = try JSONEncoder().encode(inputs)
        let decoded = try JSONDecoder().decode([OriginalProgressInput].self, from: encoded)
        for input in decoded { restored.applyProgressInput(input) }
        for _ in 0..<60 { play.advanceFrame() }
        XCTAssertEqual(play.numberSeal?.number, clue)
        play.touchNumberSeal(pageX: 172, pageY: 240)
        play.advanceFrame()
        for _ in 0..<60 { play.advanceFrame() }
        XCTAssertNil(play.numberSeal)
        XCTAssertNil(play.numberSealImage)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
        XCTAssertEqual(restored.runner.phase, play.runner.phase)
        XCTAssertEqual(restored.runner.game.bytes, play.runner.game.bytes)
        XCTAssertEqual(Array(play.runner.game.bytes[0x13D4..<0x13D6]), randomState)
        XCTAssertTrue(play.runner.processRequests.contains { $0.kind == 5 })
    }
}
