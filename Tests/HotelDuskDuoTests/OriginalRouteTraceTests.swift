import XCTest
@testable import HotelDuskDuoKit

final class OriginalRouteTraceTests: XCTestCase {
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
