import XCTest
@testable import HotelDuskDuoKit

final class OriginalPantryTraceTests: XCTestCase {
    @MainActor
    func testCardsReadSeedTracesPantryAreaThreeObjectSix() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(8)
        game.applyTimeChange(4)
        game.setMap(12, previous: 23)
        game.markEventCompleted(group: 23, event: 4)
        try game.apply(.addInventory(id: 41))
        try game.apply(.addInventory(id: 60))
        game.setMapPosition(SIMD3(0, 12288, 0), facing: 0)
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP9_R112"), game: game,
            deferArrival: true)
        let traceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotel-dusk-pantry-probe-\(UUID().uuidString).jsonl")
        let play = OriginalPlaySession(runner: runner, audio: originalRouteTestAudio(), catalog: catalog,
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        try play.enableRouteTracing(to: traceURL, runID: "chapter9-pantry-probe", checkpointName: "cards-read-seed")

        let pantry = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(pantry.room.nodes.first { $0.name == "s03" })
        let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        play.panLobbyCounter(0)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj06", interrupt: true)

        XCTAssertEqual(play.runner.game.mapID, 12)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 12))
        let trace = try String(contentsOf: traceURL, encoding: .utf8)
        XCTAssertTrue(trace.contains("\"pickedNode\":\"obj06\""))
        XCTAssertTrue(trace.contains("\"candidateEventID\":\"2\""))
        XCTAssertTrue(trace.contains("\"conditionResult\":\"pass\""))
    }
}
