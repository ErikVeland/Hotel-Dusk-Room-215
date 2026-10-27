import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalApplePaintingSessionTests: XCTestCase {
    private func mutedAudio() -> AudioController {
        let audio = AudioController()
        audio.isMuted = true
        return audio
    }

    func testEmbeddedPaintingCallRunsThroughSessionAndPersistsLetter() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP9_R117")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 84 })
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 11)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        XCTAssertEqual(runner.phase, .process(id: 64))

        let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertEqual(play.applePainting?.paintingIndex, 0)
        XCTAssertEqual(play.applePaintingImage?.width, 192)
        XCTAssertEqual(play.applePaintingImage?.height, 256)
        play.touchApplePainting(pageX: 82, pageY: 157)
        XCTAssertEqual(play.applePainting?.phase, .revealed("J"))
        XCTAssertEqual(play.runner.game.applePaintingFoundMask, 1)

        play.acknowledgeApplePaintingLetter()

        XCTAssertNil(play.applePainting)
        XCTAssertEqual(play.runner.game.applePaintingFoundMask, 1)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }

    func testSessionRunsAllFiveMapSelectedPaintingVariants() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP9_R117")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 84 })
        let library = try OriginalBitmapLibrary.bundled()
        let renderer = try OriginalApplePaintingRenderer(library: library)
        let mapIDs = OriginalApplePaintingSearch.paintingMapIDs

        for (index, mapID) in mapIDs.enumerated() {
            let mask = try renderer.mask(for: index)
            let pagePoint = try XCTUnwrap((0..<256).lazy.flatMap { y in
                (0..<192).lazy.map { x in (x, y) }
            }.first { x, y in
                guard let cameraPoint = OriginalApplePaintingSearch.cameraPoint(
                    pageX: Int32(x), pageY: Int32(y), cameraX: 0, cameraY: 0) else { return false }
                return OriginalApplePaintingSearch.containsPainting(at: index, cameraPoint: cameraPoint) &&
                    mask.contains(cameraPoint)
            })

            let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
            var selection = OriginalEventSelectionContext(
                sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
                nowTime: game.nowTime, mapID: mapID)
            selection.debugEventSelection = true
            let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
            let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog,
                saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)))
            defer { play.stop() }

            XCTAssertEqual(play.applePainting?.paintingIndex, index)
            play.touchApplePainting(pageX: pagePoint.0, pageY: pagePoint.1)
            XCTAssertEqual(play.applePainting?.phase,
                           .revealed(Array(OriginalApplePaintingSearch.targetWord)[index]))
            XCTAssertEqual(play.runner.game.applePaintingFoundMask, 1 << index)
            play.acknowledgeApplePaintingLetter()
            XCTAssertNil(play.applePainting)
            if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
        }
    }

    func testChapterNineProcess63CompletesAfterFoldCycle() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP9_R116")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 304 })
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 40)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        XCTAssertEqual(runner.phase, .process(id: 63))

        let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertEqual(play.cpr?.phase, .awaitingClose)
        play.receiveCPRFold(isClosed: true, isFullyOpen: false)
        play.receiveCPRFold(isClosed: false, isFullyOpen: false)
        XCTAssertEqual(play.cpr?.phase, .awaitingReopen)
        play.receiveCPRFold(isClosed: false, isFullyOpen: true)

        XCTAssertNil(play.cpr)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 39)), true)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }
}
