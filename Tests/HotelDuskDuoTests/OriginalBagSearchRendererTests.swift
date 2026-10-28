import XCTest
import Metal
@testable import HotelDuskDuoKit

final class OriginalBagSearchRendererTests: XCTestCase {
    func testOverlayThreeModelAndBitmapResourcesDecode() throws {
        let models = try OriginalModelLibrary.bundled()
        let bitmaps = try OriginalBitmapLibrary.bundled()
        for modelName in ["p01", "p02", "p03", "kaban"] {
            let model = try models.load(path: "trick/bag/\(modelName).mdf")
            XCTAssertFalse(model.nodes.isEmpty)
            XCTAssertTrue(model.groups.contains { $0.render != nil })
        }
        for textureName in ["kaban", "kaban01", "table", "counter01", "kabe01", "yuka_01"] {
            _ = try bitmaps.loadLinear(path: "trick/bag/\(textureName).bin")
        }
    }

    func testCPUProjectionFindsTheRenderedTreeBoxSilhouetteAndGroundTarget() throws {
        let library = try OriginalModelLibrary.bundled()
        let models = try ["p01", "p02", "p03", "kaban"].map {
            try library.load(path: "trick/bag/\($0).mdf")
        }
        let projection = try OriginalBagSearchProjection(models: models)
        let process = OriginalBagSearchProcess()
        let treeBox = try XCTUnwrap(process.objects.firstIndex { $0.type == 3 })
        let masks = try projection.objectMasks(process: process)
        let treeBoxMask = try XCTUnwrap(masks.first { $0.0 == treeBox }?.1)
        var hitPoint: SIMD2<Float>?

        let minX = max(0, Int(treeBoxMask.bounds.minX))
        let maxX = min(192, Int(treeBoxMask.bounds.maxX.rounded(.up)))
        let minY = max(0, Int(treeBoxMask.bounds.minY))
        let maxY = min(256, Int(treeBoxMask.bounds.maxY.rounded(.up)))
        for y in stride(from: minY, to: maxY, by: 2) where hitPoint == nil {
            for x in stride(from: minX, to: maxX, by: 2) {
                let point = SIMD2(Float(x), Float(y))
                guard let depth = treeBoxMask.depth(at: point) else { continue }
                let frontDepth = masks.compactMap { $0.1.depth(at: point) }.min() ?? .infinity
                if depth <= frontDepth {
                    hitPoint = point
                    break
                }
            }
        }

        XCTAssertNotNil(hitPoint)
        let origin = try XCTUnwrap((0..<256).map { SIMD2<Float>(96, Float($0)) }.first { point in
            guard let fixed = projection.planePointFixed(at: point) else { return false }
            return abs(fixed.x) <= 24 && abs(fixed.y) <= 24
        })
        let fixed = try XCTUnwrap(projection.planePointFixed(at: origin))
        XCTAssertLessThanOrEqual(abs(fixed.x), 24)
        XCTAssertLessThanOrEqual(abs(fixed.y), 24)
    }

    @MainActor
    func testChapterSevenBagProcessReturnsThroughItsScriptTransition() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP7_R122")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 55
        })
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(sceneID: .max, blockID: 0, modeID: 15,
            eventID: UInt16(event.index), nowTime: game.nowTime, mapID: game.mapID)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .process(id: 55))
        XCTAssertNotNil(play.bagSearch)
        play.openBagSearchMenu()
        for _ in 0..<65 where play.bagSearch != nil { play.advanceFrame() }

        XCTAssertNil(play.bagSearch)
        XCTAssertNotEqual(play.runner.phase, .process(id: 55))
    }

    @MainActor
    func testOriginalModelsRenderAndExposeObjectShapedTouchMasks() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        let renderer = try OriginalBagSearchRenderer()
        let process = OriginalBagSearchProcess()
        let image = try renderer.render(process)

        XCTAssertEqual(image.width, 192)
        XCTAssertEqual(image.height, 256)

        let treeBox = try XCTUnwrap(process.objects.firstIndex { $0.type == 3 })
        let touches = stride(from: 0, to: 256, by: 4).flatMap { y in
            stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }
        XCTAssertTrue(try touches.contains { try renderer.object(at: $0, process: process) == treeBox })

        let origin = try XCTUnwrap(stride(from: 0, to: 256, by: 2).flatMap { y in
            stride(from: 0, to: 192, by: 2).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { point in
            guard let fixed = renderer.planePointFixed(at: point) else { return false }
            return abs(fixed.x) <= 24 && abs(fixed.y) <= 24
        })
        XCTAssertLessThanOrEqual(abs(renderer.planePointFixed(at: origin)!.x), 24)
        XCTAssertLessThanOrEqual(abs(renderer.planePointFixed(at: origin)!.y), 24)
    }
}
