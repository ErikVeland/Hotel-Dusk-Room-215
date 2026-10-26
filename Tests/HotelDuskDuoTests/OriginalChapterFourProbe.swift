import XCTest
@testable import HotelDuskDuoKit

/// Temporary route probe; prints state reached from a checkpoint.
@MainActor
final class OriginalChapterFourProbe: XCTestCase {
    private typealias Route = OriginalChapterThreeRouteChecks

    func report(_ play: OriginalPlaySession, _ label: String) {
        let g = play.runner.game
        print("PROBE", label, play.runner.phase, "map", g.mapID, "time", g.nowTime, "pos", play.lobby.map { ($0.position.x, $0.position.z) } as Any)
        print("PROBE people", play.lobby?.people(in: g).map { ($0.id, $0.position.x, $0.position.z) } as Any)
        print("PROBE done", (0..<120).filter { g.value(for: .eventFlag(group: UInt16(g.mapID), index: UInt16($0))) == true })
        print("PROBE items", (try? g.inventory.items) as Any)
        print("PROBE whereabouts", (0..<18).compactMap { p in g.personMarker(p).map { "\(p)@\($0)" } }.joined(separator: " "))
    }

    func testProbe() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] else { throw XCTSkip("no checkpoint") }
        let audio = AudioController(); audio.isMuted = true
        let play: OriginalPlaySession
        if let from = ProcessInfo.processInfo.environment["PROBE_FROM"],
           let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent(from)).load() {
            play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
                saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        } else {
            let chapterDirectory = URL(fileURLWithPath: directory).appendingPathComponent(ProcessInfo.processInfo.environment["PROBE_CHAPTER"] ?? "chapter6")
            let save = try XCTUnwrap(try OriginalChapterFileStore(directory: chapterDirectory).load(slot: 0))
            play = try OriginalPlaySession.restoring(save, audio: audio,
                saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
            play.continueChapterTitle()
        }
        defer { play.stop() }
        let answers = (ProcessInfo.processInfo.environment["PROBE_ANSWERS"] ?? "").components(separatedBy: "|")
        Route.drain(play, interrupt: true)
        report(play, "start")
        let names = try OriginalItemNames.bundled().names
        for id in (ProcessInfo.processInfo.environment["PROBE_ITEMS"] ?? "").split(separator: ",").compactMap({ UInt8($0) }) { print("PROBE item", id, names[id] as Any) }
        // Step script: commands separated by ";", arguments by spaces.
        for command in (ProcessInfo.processInfo.environment["PROBE_STEPS"] ?? "").components(separatedBy: ";") {
            let f = command.split(separator: " ").map(String.init)
            guard let op = f.first else { continue }
            let n = f.dropFirst().compactMap { Float($0) }
            print("PROBE >", command)
            switch op {
            case "nav": try Route.navigate(play, to: .init(n[0], n[1]), interrupt: true)
            case "nudge": Route.nudge(play, toward: .init(n[0], n[1]))
            case "face": Route.face(play, x: n[0], z: n[1])
            case "exit": try Route.exit(play, to: Int16(n[0]), interrupt: true)
            case "door": try Route.door(play, destination: Int16(n[0]), interrupt: true)
            case "knock": try Route.doorComponent(play, Int(n.first ?? 1), interrupt: true)
            case "talk": try Route.talk(play, to: Int16(n[0]))
            case "conv": try Route.conversation(play, answers: answers, topics: Array(0..<128), show: n.map { UInt8($0) })
            case "convi": try Route.conversation(play, answers: answers, topics: Array(0..<128), show: n.map { UInt8($0) }, itemsFirst: true)
            case "search": try Route.search(play, node: f[1], closeupEvent: f.count > 2 ? Int16(f[2]) : nil, interrupt: true)
            case "layer": try Route.closeupLayer(play, event: Int16(n[0]), item: n.count > 1 ? UInt8(n[1]) : nil, interrupt: true)
            case "use": try Route.useItem(play, UInt8(n[0]), on: f[2], interrupt: true)
            case "pic": try Route.picture(play, interrupt: true)
            case "suitcase": try Route.takeFromSuitcase(play, lowerIndex: Int(n[0]))
            case "matches": try Route.solveMatchsticks(play)
            case "jukebox": try Route.playJukebox(play, record: Int(n[0]))
            case "wagon": try Route.searchLinenWagon(play)
            case "phone": play.inspectLobbyCounter(); play.selectLobbyObject(x: 86, y: 165, confirmImmediately: true); Route.drain(play, interrupt: true)
            case "leave": for _ in 0..<4 where play.closeup != nil { play.leaveSearchCloseup() }; if play.lobby?.mode == .counter { play.leaveLobbyCounter() }; if play.door != nil { play.leaveDoor() }
            case "notebook":
                play.openNotebook()
                print("PROBE notebook page", play.notebook?.page as Any, "of", play.notebook?.pageCount as Any, "unread", play.notebook?.unreadMemo as Any)
                play.closeNotebook()
                Route.drain(play, interrupt: true)
            case "nodes":
                print("PROBE search area", play.lobby?.nearbySearchArea as Any)
                if play.lobby?.mode != .counter { play.inspectLobbyCounter() }
                if let lobby = play.lobby {
                    var names = Set<String>()
                    for y in stride(from: 8, to: 248, by: 6) { for x in stride(from: 8, to: 184, by: 6) { if let n = try lobby.pickedCounterNode(page: SIMD2(Float(x), Float(y))) { names.insert(n) } } }
                    print("PROBE nodes", names.sorted())
                }
            case "ask": play.ask(Int16(n[0])); Route.drain(play, interrupt: true)
            case "show": play.showItemInConversation(UInt8(n[0])); Route.drain(play, interrupt: true)
            case "choose": try Route.choose(play, f.dropFirst().joined(separator: " "), interrupt: true)
            case "bye": play.leaveConversation(); Route.drain(play, interrupt: true)
            case "drain": Route.drain(play, interrupt: true)
            case "wait": for _ in 0..<Int(n[0]) { play.advanceFrame() }; Route.drain(play, interrupt: true)
            case "map": Route.printMap(play, step: Int(n.first ?? 2048), range: -Int(n.count > 1 ? n[1] : 100000)...Int(n.count > 1 ? n[1] : 100000))
            case "chara": print("PROBE chara", play.lobby?.room.nodes.filter { $0.name.hasPrefix("chara") }.map { "\($0.name)(\($0.worldFixed[12]),\($0.worldFixed[14]))" } as Any)
            case "markers":
                for node in play.lobby?.room.nodes ?? [] where node.name.hasPrefix("in_") || (node.name.hasPrefix("s") && node.name.count <= 4) { print("PROBE marker", node.name, node.worldFixed[12], node.worldFixed[14]) }
                if let lobby = play.lobby {
                    for area in try OriginalSearchTable.bundled(map: lobby.mapName).areas { print("PROBE area", area.areaID, area.entries.filter { $0.upViewID != 0xFFFF }.map { ($0.subareaID, $0.upViewID) }) }
                    for view in try OriginalUpViewTable.bundled(map: lobby.mapName).views { print("PROBE view", view.id, view.background, view.layers.map { ($0.asset, $0.eventID, $0.itemID, $0.processID) }) }
                }
            case "save": try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent(f[1])).save(play.walkingCheckpoint())
            default: XCTFail("Unknown step \(op)")
            }
            report(play, op)
        }
    }
}
