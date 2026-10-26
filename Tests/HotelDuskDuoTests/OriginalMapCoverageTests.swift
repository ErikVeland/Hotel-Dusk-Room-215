import XCTest
import Metal
@testable import HotelDuskDuoKit

final class OriginalMapCoverageTests: XCTestCase {
    func testRoomsWithoutChapterScriptsRemainAvailableForSystemInteractions() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let empty = try catalog.loadMapProgram(chapter: 2, mapID: 2)
        XCTAssertEqual(empty.name, "EP3_R102")
        XCTAssertTrue(try empty.blocks.tables.allSatisfy(\.isEmpty))
        let chapterRoom = try catalog.loadMapProgram(chapter: 2, mapID: 31)
        XCTAssertFalse(try chapterRoom.blocks.tables[2].isEmpty)
        XCTAssertThrowsError(try catalog.loadMapProgram(chapter: 10, mapID: 31))
        XCTAssertThrowsError(try catalog.loadMapProgram(chapter: 2, mapID: -1))
    }

    @MainActor func testSearchSceneCanUseAnUnambiguousTextureFromItsRoomArchive() throws {
        let textures = try OriginalTextureLibrary.bundled()
        let path = try textures.mapTexturePath(modelPath: "map/R126/R126_s01/R126_s01.mdf", textureName: "doorrest")
        XCTAssertEqual(path, "map/R126/R126/doorrest.dtx")
        XCTAssertThrowsError(try textures.mapTexturePath(modelPath: "map/R123/R123/R123.mdf", textureName: "r123_lamp02"),
                             "Different images with the same name must not be substituted")
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let preview = try OriginalModelMetalPreview(modelPath: "map/R126/R126_s01/R126_s01.mdf",
            models: .bundled(), textures: textures, device: device, gameplayOnly: true)
        XCTAssertTrue(preview.texturePaths.values.contains(path))
    }

    @MainActor func testSupportedRoomsLoadAtOriginalEntryMarkersAndRender() throws {
        let models = try OriginalModelLibrary.bundled()
        let defaults = try OriginalStateDefaults.bundled()
        for (id, name) in OriginalMapExploration.supportedMaps.sorted(by: { $0.key < $1.key }) {
            do {
                let room = try models.load(path: "map/\(name)/\(name)/\(name).mdf")
                let marker = try XCTUnwrap(room.nodes.first(where: { $0.name.hasPrefix("out_") }), name)
                var game = try OriginalGameState.newGame(defaults: defaults, timestamp: nil)
                game.setMap(id, previous: id)
                game.setMapPosition(SIMD3(Float(marker.worldFixed[12]), 12288, Float(marker.worldFixed[14])), facing: 0)
                let map = try OriginalMapExploration.bundled(mapID: id, previousMapID: id, savedGame: game)
                let renderer = try OriginalMapRenderer(mapName: name)
                let image = try renderer.render(map, game: game)
                XCTAssertEqual(image.width, 192, name)
                XCTAssertEqual(image.height, 256, name)
                XCTAssertGreaterThan(renderer.map.width, 0, name)
            } catch { XCTFail("\(name): \(error)") }
        }
    }

    @MainActor func testLateChapterSearchScenesLoadTheirOriginalModels() throws {
        let models = try OriginalModelLibrary.bundled(), textures = try OriginalTextureLibrary.bundled()
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        for name in ["R123", "R301", "R302", "R304"] {
            let room = try models.load(path: "map/\(name)/\(name)/\(name).mdf")
            for marker in room.nodes where marker.name.count == 3 && marker.name.hasPrefix("s0") {
                let path = "map/\(name)/\(name)_\(marker.name)/\(name)_\(marker.name).mdf"
                let scene = try OriginalModelMetalPreview(modelPath: path, models: models,
                    textures: textures, device: device, gameplayOnly: true)
                XCTAssertFalse(scene.model.gameplayRenderNodes.isEmpty, path)
                XCTAssertNotNil(try scene.model.cameraMarkers(index: 1), path)
                XCTAssertNotNil(try scene.model.cameraMarkers(index: 2), path)
            }
        }
    }
}
