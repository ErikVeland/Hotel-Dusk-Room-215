import XCTest
@testable import HotelDuskDuoKit

final class OriginalRouteTraceTests: XCTestCase {
    @MainActor
    func testPlaySessionTracesNearbyDoorInspection() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(8)
        game.applyTimeChange(4)
        game.setMap(12, previous: 23)
        game.markEventCompleted(group: 23, event: 4)
        try game.apply(.addInventory(id: 41))
        try game.apply(.addInventory(id: 60))
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP9_R112"), game: game,
            deferArrival: true)
        let play = OriginalPlaySession(runner: runner, audio: originalRouteTestAudio(), catalog: catalog,
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotel-dusk-door-trace-\(UUID().uuidString).jsonl")
        try play.enableRouteTracing(to: url, runID: "door-trace-test", checkpointName: "cards-read-seed")

        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "in_r123" })
        let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        XCTAssertEqual(play.nearbyDoor, 23)
        play.inspectNearbyDoor()

        let trace = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(trace.contains("\"kind\":\"doorInspection\""))
        XCTAssertTrue(trace.contains("\"destinationMap\":\"23\""))
        XCTAssertTrue(trace.contains("\"doorID\":\"45\""))
        XCTAssertTrue(trace.contains("\"doorArea\":\"7\""))
        XCTAssertTrue(trace.contains("\"upViewID\":\"78\""))
    }

    @MainActor
    func testPlaySessionRecordsInputBoundariesOnlyWhenTracingIsEnabled() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R301")
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(40, previous: 39)
        let runner = try OriginalEventRunner(program: program, game: game, deferArrival: true)
        let play = OriginalPlaySession(runner: runner, audio: AudioController(), catalog: catalog,
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotel-dusk-input-trace-\(UUID().uuidString).jsonl")
        try play.enableRouteTracing(to: url, runID: "input-trace-test", checkpointName: "r301-entry")

        play.inspectLobbyCounter()

        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        XCTAssertTrue(lines.contains { $0.contains("\"kind\":\"input\"") })
        XCTAssertTrue(lines.contains { $0.contains("\"kind\":\"inputState\"") })
        XCTAssertTrue(lines.contains { $0.contains("\"kind\":\"inputComplete\"") })
    }

    func testRouteTraceRecordsSelectorWithoutChangingSelectionResults() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R301")
        let table = try OriginalSearchTable.bundled(map: "R301")
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(40, previous: 39)
        var traced = try OriginalEventRunner(program: program, game: game, deferArrival: true)
        var plain = try OriginalEventRunner(program: program, game: game, deferArrival: true)
        let traceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotel-dusk-route-\(UUID().uuidString).jsonl")
        let trace = try OriginalRouteTraceLog(url: traceURL, runID: "route-trace-test", checkpointName: "r301-entry")
        traced.attachRouteTrace(trace)
        trace.beginInput("look(area:1,subarea:4)")

        traced.lookInSearchView(area: 1, subarea: 4, table: table)
        plain.lookInSearchView(area: 1, subarea: 4, table: table)

        XCTAssertEqual(traced.phase, plain.phase)
        XCTAssertEqual(traced.game.bytes, plain.game.bytes)
        XCTAssertEqual(traced.session, plain.session)
        let lines = try String(contentsOf: traceURL, encoding: .utf8).split(separator: "\n")
        XCTAssertTrue(lines.contains { $0.contains("\"kind\":\"candidate\"") })
        XCTAssertTrue(lines.contains { $0.contains("\"kind\":\"selection\"") })
        XCTAssertTrue(lines.contains { $0.contains("\"kind\":\"operation\"") })
        XCTAssertTrue(lines.allSatisfy { $0.contains("route-trace-test") && $0.contains("r301-entry") })
    }
}
