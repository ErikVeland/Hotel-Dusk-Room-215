import CoreGraphics
import Foundation
import ImageIO
import Metal
import XCTest
@testable import HotelDuskDuoKit

final class Room215ArtworkCandidateTests: XCTestCase {
    @MainActor func testRenderCandidateAtOriginalDoorPosition() throws {
        guard let root = ProcessInfo.processInfo.environment["HOTEL_DUSK_DOOR_CANDIDATE"],
              let destination = ProcessInfo.processInfo.environment["HOTEL_DUSK_DOOR_PREVIEW"] else {
            throw XCTSkip("Set candidate and preview paths for the isolated visual check")
        }
        let artwork = OriginalArtwork(resourceRoot: URL(fileURLWithPath: root))
        let textures = try OriginalTextureLibrary.bundled()
        let door = try textures.load(path: "map/R213/R213/door.dtx")
        XCTAssertEqual(artwork.enhancedImage(rgba: door.rgba, width: door.storedWidth,
                                             height: door.storedHeight)?.width, door.storedWidth * 4)
        let upView = try XCTUnwrap(OriginalUpViewTable.bundled(map: "R213").views.first { $0.id == 341 })
        let bitmapLibrary = try OriginalBitmapLibrary.bundled()
        let layers = try ([upView.background] + upView.layers.map(\.asset)).map {
            try bitmapLibrary.loadLinear(path: "map/sdata/SearchUp/\($0).bin")
        }
        let inspection = try OriginalUpViewImage(bitmaps: layers, visible: [true, true, true, true], artwork: artwork)
        XCTAssertEqual(inspection.hit(pageX: 96, pageY: 45), 3)
        let inspectionURL = URL(fileURLWithPath: destination).deletingPathExtension()
            .appendingPathExtension("inspection.png")
        let inspectionWriter = try XCTUnwrap(CGImageDestinationCreateWithURL(inspectionURL as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(inspectionWriter, inspection.image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(inspectionWriter))

        let defaults = try OriginalStateDefaults.bundled()
        var game = try OriginalGameState.newGame(defaults: defaults, timestamp: nil)
        game.setMap(39, previous: 17)
        var map = try OriginalMapExploration.bundled(mapID: 39, previousMapID: 17)
        for _ in 0..<254 { map.update(heldPageTouch: .init(20, 128)) }
        for _ in 0..<9 { map.update(heldPageTouch: .init(96, 210)) }
        XCTAssertEqual(map.nearbyDoor(in: game, table: defaults.doorTable), 31)

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let model = try OriginalModelMetalPreview(modelPath: "map/R213/R213/R213.mdf",
            models: .bundled(), textures: textures, device: device, gameplayOnly: true,
            smoothTextures: true, artwork: artwork)
        let nodes = map.objectVisibility.visibleNodes(in: model.model, map: map.mapID, area: nil, game: game)
            .intersection(model.model.gameplayRenderNodes)
        for (index, angle) in [Float(-0.8), -0.4, 0, 0.4, 0.8, 0.8, 0.8, 0.8].enumerated() {
            var view = map
            view.turnView(by: angle)
            if index >= 5 {
                for _ in 0..<((index - 4) * 20) { view.update(firstPersonMovement: .init(0, -1)) }
            }
            let image = try model.render(width: 768, height: 1024, viewProjection: view.viewProjection, visibleNodes: nodes)
            let url = URL(fileURLWithPath: destination).deletingPathExtension()
                .appendingPathExtension("\(index).png")
            let writer = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(writer, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(writer))
        }
        // Check plaque orientation on both sides of the corridor.
        for (index, position, facing) in [(8, SIMD3<Float>(89_200, 12_288, 4_500), Float(0)),
                                          (9, SIMD3<Float>(113_700, 12_288, 5_000), Float.pi)] {
            game.setMapPosition(position, facing: facing)
            let view = try OriginalMapExploration.bundled(mapID: 39, previousMapID: 17, savedGame: game)
            let image = try model.render(width: 768, height: 1024, viewProjection: view.viewProjection, visibleNodes: nodes)
            let url = URL(fileURLWithPath: destination).deletingPathExtension().appendingPathExtension("\(index).png")
            let writer = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(writer, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(writer))
        }
    }
}
