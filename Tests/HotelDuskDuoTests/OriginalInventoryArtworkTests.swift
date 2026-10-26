import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalInventoryArtworkTests: XCTestCase {
    func testNamedItemsHaveVisibleArtworkOrAnExplicitMissingPicture() throws {
        let artwork = OriginalInventoryArtwork()
        XCTAssertEqual(artwork.names.count, 82)
        XCTAssertEqual(artwork.names.keys.filter { !artwork.hasOriginalPicture(for: $0) }, [51],
                       "The source archive omits only the Message Card picture")
        for item in artwork.names.keys.sorted() {
            guard artwork.hasOriginalPicture(for: item) else {
                XCTAssertThrowsError(try artwork.image(for: item))
                continue
            }
            let image = try artwork.image(for: item)
            XCTAssertGreaterThan(image.width, 0)
            XCTAssertGreaterThan(image.height, 0)
            let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
            XCTAssertTrue(stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 },
                          "Missing pixels for \(artwork.name(for: item))")
        }
    }

    func testBrowsingDoesNotMoveThePlayerUseItemsOrAdvanceTheScript() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(2, previous: 1)
        let map = try OriginalMapExploration.bundled(mapID: 2, previousMapID: 1)
        game.setMapPosition(map.position, facing: map.facing)
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"), game: game, deferArrival: true)
        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog, restoredExploration: map)
        defer { play.stop() }
        play.holdFirstPersonMovement(strafe: 0, forward: 1)
        play.beginInventoryBrowsing()
        XCTAssertTrue(play.isBrowsingInventory)
        let before = play.runner
        let position = play.lobby?.position
        for item in try play.runner.game.inventory.items {
            _ = try OriginalInventoryArtwork.shared.image(for: item)
        }
        play.holdFirstPersonMovement(strafe: 1, forward: 1)
        play.turnFirstPerson(by: .pi)
        play.holdLobbyTouch(x: 140, y: 80)
        for _ in 0..<60 { play.advanceFrame() }
        XCTAssertEqual(play.lobby?.position, position)
        XCTAssertEqual(play.lobby?.facing, map.facing)
        XCTAssertEqual(play.runner.game, before.game)
        XCTAssertEqual(play.runner.phase, before.phase)
        XCTAssertEqual(play.runner.eventTrail, before.eventTrail)
        XCTAssertNil(play.searchItem)
        play.pause()
        play.resume()
        XCTAssertTrue(play.isBrowsingInventory, "Folding and reopening must retain inventory browsing")
        play.endInventoryBrowsing()
        play.advanceFrame()
        XCTAssertEqual(play.lobby?.position, position, "Closing inventory must not restore a held movement")
        play.holdFirstPersonMovement(strafe: 0, forward: 1)
        play.advanceFrame()
        XCTAssertNotEqual(play.lobby?.position, position, "Movement must work again after closing inventory")
    }
}
