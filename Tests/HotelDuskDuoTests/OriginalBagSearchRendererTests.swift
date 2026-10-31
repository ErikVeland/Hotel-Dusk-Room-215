import XCTest
import Metal
import simd
@testable import HotelDuskDuoKit

final class OriginalBagSearchRendererTests: XCTestCase {
    func testOverlayThirtyCubeModelAndTextureDecode() throws {
        let models = try OriginalModelLibrary.bundled()
        let bitmaps = try OriginalBitmapLibrary.bundled()
        let model = try models.load(path: "trick/searchshed/soko.mdf")
        XCTAssertFalse(model.nodes.isEmpty)
        XCTAssertTrue(model.groups.contains { $0.render != nil })
        for textureName in ["yuka", "kabe01", "tenjoh"] {
            _ = try bitmaps.loadTexture(path: "trick/searchshed/\(textureName).bin")
        }
    }

    func testCPUProjectionFindsTheRenderedTreeBoxSilhouetteAndGroundTarget() throws {
        let library = try OriginalModelLibrary.bundled()
        let models = [try library.load(path: "trick/searchshed/soko.mdf")]
        let projection = try OriginalBagSearchProjection(models: models)
        var process = OriginalBagSearchProcess()
        for index in process.objects.indices where index != 9 {
            let object = process.objects[index]
            let start = SIMD2(object.positionFixed.x, object.positionFixed.z)
            process.beginDrag(object: index, at: start)
            process.drag(to: SIMD2(start.x + 40_960, start.y + 40_960))
            _ = process.endDrag()
        }
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
        _ = try XCTUnwrap((0..<256).flatMap { y in
            (0..<192).compactMap { x in projection.planePointFixed(at: SIMD2(Float(x), Float(y))) }
        }.first)
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
        let process = try XCTUnwrap(play.bagSearch)
        let library = try OriginalModelLibrary.bundled()
        let models = [try library.load(path: "trick/searchshed/soko.mdf")]
        let projection = try OriginalBagSearchProjection(models: models)
        var masks = try projection.objectMasks(process: process)
        func visibleTouch(for objectIndex: Int) -> SIMD2<Float>? {
            guard let mask = masks.first(where: { $0.0 == objectIndex })?.1 else { return nil }
            for y in stride(from: max(0, Int(mask.bounds.minY)),
                            to: min(256, Int(mask.bounds.maxY.rounded(.up))), by: 2) {
                for x in stride(from: max(0, Int(mask.bounds.minX)),
                                to: min(192, Int(mask.bounds.maxX.rounded(.up))), by: 2) {
                    let point = SIMD2<Float>(Float(x), Float(y))
                    guard let depth = mask.depth(at: point),
                          depth <= (masks.compactMap { $0.1.depth(at: point) }.min() ?? .infinity) else { continue }
                    return point
                }
            }
            return nil
        }

        let blocker = 5
        let start = try XCTUnwrap(visibleTouch(for: blocker))
        let startPlane = try XCTUnwrap(projection.planePointFixed(at: start))
        let targetPlane = SIMD2(startPlane.x + 4_096, startPlane.y)
        let clip = projection.viewProjection * SIMD4(Float(targetPlane.x) / 4_096, 0,
                                                       Float(targetPlane.y) / 4_096, 1)
        let target = SIMD2((clip.x / clip.w + 1) * 96, (1 - clip.y / clip.w) * 128)
        XCTAssertEqual(projection.planePointFixed(at: target), targetPlane)
        play.holdBagSearchTouch(x: start.x, y: start.y)
        XCTAssertEqual(play.bagSearch?.draggedObject, blocker)
        play.holdBagSearchTouch(x: target.x, y: target.y)
        XCTAssertEqual(play.bagSearch?.objects[blocker].positionFixed.x,
                       process.objects[blocker].positionFixed.x + 4_096)
        play.releaseBagSearchTouch()

        masks = try projection.objectMasks(process: try XCTUnwrap(play.bagSearch))
        let treeBoxTouch = try XCTUnwrap(visibleTouch(for: 9))
        play.holdBagSearchTouch(x: treeBoxTouch.x, y: treeBoxTouch.y)
        play.releaseBagSearchTouch()
        XCTAssertEqual(play.bagSearch?.phase, .found)

        play.openBagSearchMenu()
        for _ in 0..<65 where play.bagSearch != nil { play.advanceFrame() }

        XCTAssertNil(play.bagSearch)
        XCTAssertNotEqual(play.runner.phase, .process(id: 55))
    }

    @MainActor
    func testOriginalCubeModelRendersAndExposesObjectShapedTouchMasks() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        let renderer = try OriginalBagSearchRenderer()
        let process = OriginalBagSearchProcess()
        let image = try renderer.render(process)

        XCTAssertEqual(image.width, 768)
        XCTAssertEqual(image.height, 1024)

        let treeBox = 9
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
