import CoreGraphics
import XCTest
import Metal
@testable import HotelDuskDuoKit

final class OriginalChapterTenSearchShedSessionTests: XCTestCase {
    @MainActor
    private final class CPUSearchShedRenderer: OriginalSearchShedRendering {
        private let model: OriginalModel
        private let image: CGImage

        init() throws {
            model = try OriginalModelLibrary.bundled().load(path: "trick/searchshed/soko.mdf")
            guard let image = CGContext(data: nil, width: 192, height: 256, bitsPerComponent: 8,
                bytesPerRow: 192 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage() else {
                throw OriginalDataError.invalid("Search-shed test image")
            }
            self.image = image
        }

        func render(_ process: OriginalSearchShedProcess) throws -> CGImage { image }

        func object(at point: SIMD2<Float>, process: OriginalSearchShedProcess) -> Int? {
            OriginalSearchShedRenderer.object(at: point, process: process, model: model)
        }
    }

    func testR304SearchShedTransitionTableHasOnlyReturnZero() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP10_R304")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 79
        })
        let validResults = (0...3).compactMap { result -> Int16? in
            guard case .completed = try? OriginalEventCompletion.stateOnlyExit(
                event: event, conditions: program.conditions, processReturn: Int16(result)) else { return nil }
            return Int16(result)
        }

        XCTAssertEqual(validResults, [0])
    }

    @MainActor
    func testCPUProjectedTouchSolvesSearchShedThroughTheSession() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R304")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 79
        })
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(43, previous: 42)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15,
            eventID: UInt16(event.index), nowTime: game.nowTime, mapID: 43)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController()
        try audio.applyOriginalCommand(.disableMusic(true))
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let renderer = try CPUSearchShedRenderer()
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
            searchShedRendererFactory: { renderer })
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .process(id: 79))
        play.advanceFrame()
        let process = try XCTUnwrap(play.searchShed)
        let centre = SIMD2<Float>(96, 128)
        let targets = stride(from: 16, to: 240, by: 8).flatMap { y in
            stride(from: 16, to: 176, by: 8).compactMap { x -> SIMD2<Float>? in
                let point = SIMD2<Float>(Float(x), Float(y))
                guard let object = renderer.object(at: point, process: process),
                      OriginalSearchShedProcess.isAcceptedIndex(object) else { return nil }
                return point
            }
        }
        let touch = try XCTUnwrap(targets.min { left, right in
            let leftX = left.x - centre.x, leftY = left.y - centre.y
            let rightX = right.x - centre.x, rightY = right.y - centre.y
            return leftX * leftX + leftY * leftY < rightX * rightX + rightY * rightY
        }, "The recovered hit mesh must expose a valid interior search target")

        for _ in 0..<OriginalSearchShedProcess.requiredHitCount {
            play.holdSearchShedTouch(x: touch.x, y: touch.y)
            play.releaseSearchShedTouch()
        }
        XCTAssertEqual(play.searchShed?.hitCount, OriginalSearchShedProcess.requiredHitCount)
        XCTAssertEqual(play.searchShed?.phase, .responding)
        for _ in 0..<30 { play.advanceFrame() }
        XCTAssertTrue(play.searchShed?.canConfirmFoundSearch == true)
        play.openSearchShedTreeBox()

        XCTAssertNil(play.searchShed)
        XCTAssertNotEqual(play.runner.phase, .process(id: 79))
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }

    @MainActor
    func testChapterTenSearchShedUsesOverlayFortyHandler() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R304")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 79
        })
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(43, previous: 42)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15,
            eventID: UInt16(event.index), nowTime: game.nowTime, mapID: 43)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController()
        audio.isMuted = true
        _ = try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .process(id: 79))
        XCTAssertEqual(play.searchShed?.objects.count, 90)
        XCTAssertEqual(play.searchShedImage?.width, 768)
        XCTAssertEqual(play.searchShedImage?.height, 1024)

        play.advanceFrame()
        let process = try XCTUnwrap(play.searchShed)
        let model = try OriginalModelLibrary.bundled().load(path: "trick/searchshed/soko.mdf")
        let touch = try XCTUnwrap((0..<256).flatMap { y in
            (0..<192).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { point in
            guard let object = OriginalSearchShedRenderer.object(at: point, process: process, model: model) else {
                return false
            }
            return OriginalSearchShedProcess.isAcceptedIndex(object)
        }, "The board must expose at least one valid search target")

        for _ in 0..<5 {
            play.holdSearchShedTouch(x: touch.x, y: touch.y)
            play.releaseSearchShedTouch()
        }
        XCTAssertEqual(play.searchShed?.hitCount, 5)
        XCTAssertEqual(play.searchShed?.phase, .responding)
        for _ in 0..<30 { play.advanceFrame() }
        XCTAssertTrue(play.searchShed?.canConfirmFoundSearch == true)
        play.openSearchShedTreeBox()

        XCTAssertNil(play.searchShed)
        XCTAssertNotEqual(play.runner.phase, .process(id: 79))
    }
}
