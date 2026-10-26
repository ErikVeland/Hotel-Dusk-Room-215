import simd
import XCTest
@testable import HotelDuskDuoKit

@MainActor
enum OriginalChapterThreeRouteChecks {
    static func run(_ play: OriginalPlaySession) throws {
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(play.runner.game.chapter, 2)
        try walk(play, to: SIMD2(9500, -15000))
        try walk(play, to: SIMD2(9000, 7800))
        try walk(play, to: SIMD2(-15500, 7800))
        // Face the dresser and select the telephone through its original model hit mesh.
        play.holdLobbyTouch(x: 20, y: 128)
        for _ in 0..<10 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        play.inspectLobbyCounter()
        play.selectLobbyObject(x: 86, y: 165, confirmImmediately: true)
        drain(play)
        try choose(play, "Forget it, Rachel.")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try walk(play, to: SIMD2(9000, 7800))
        try walk(play, to: SIMD2(9994, -15811))
        try door(play, destination: 39)
        try walk(play, to: SIMD2(-75000, 7000))
        try walk(play, to: SIMD2(20700, 7000))
        try walk(play, to: SIMD2(20700, -48000))
        XCTAssertEqual(play.runner.game.mapID, 17)
        try walk(play, to: SIMD2(6000, 30000), interrupt: true)
        try conversation(play, answers: ["Everything OK?", "Nothing to apologize for.", "What is it?", "Nothing special."], topics: [1])
        try walk(play, to: SIMD2(6000, 30000))
        try walk(play, to: SIMD2(-8500, 30885))
        try door(play, destination: 26, interrupt: true)
        try conversation(play, answers: ["Six months?"], topics: [5, 4])
        try walk(play, to: SIMD2(-30000, -27000), interrupt: true)
        try conversation(play, answers: ["Six months?"], topics: [5, 4])
        try walk(play, to: SIMD2(-30000, -27000), interrupt: true)
        try walk(play, to: SIMD2(-35000, 10000), interrupt: true)
        play.holdLobbyTouch(x: 170, y: 128)
        for _ in 0..<8 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 9)
        play.talkToNearbyPerson()
        drain(play, interrupt: true)
        try conversation(play, answers: ["What is it?", "You seem upset.", "You mean Melissa?", "You're nuts."], topics: [9, 8, 10])
        try walk(play, to: SIMD2(-20000, 11000), interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 4)
        try walk(play, to: SIMD2(-4000, 20000))
        play.holdLobbyTouch(x: 96, y: 210)
        for _ in 0..<8 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let objectPoint = try stride(from: 8, to: 248, by: 8).flatMap { y in stride(from: 8, to: 184, by: 8).map { SIMD2<Float>(Float($0), Float(y)) } }
            .first { try counter.pickedCounterNode(page: $0) == "obj04" }
        let object = try XCTUnwrap(objectPoint)
        play.selectLobbyObject(x: object.x, y: object.y, confirmImmediately: true)
        drain(play)
        let closeup = try XCTUnwrap(play.closeup)
        let component = try XCTUnwrap(closeup.view.layers.firstIndex { $0.eventID == 32 }) + 1
        let dollPoint = stride(from: 8, to: 248, by: 4).flatMap { y in stride(from: 8, to: 184, by: 4).map { SIMD2<Int>($0, y) } }
            .first { play.closeupImage?.hit(pageX: $0.x, pageY: $0.y) == component }
        let doll = try XCTUnwrap(dollPoint)
        play.selectCloseupComponent(x: doll.x, y: doll.y, confirmImmediately: true)
        drain(play)
        XCTAssertEqual(try play.runner.game.inventory.itemStates[24], 1)
        play.leaveSearchCloseup()
        play.leaveLobbyCounter()
        try walk(play, to: SIMD2(5000, 5000), interrupt: true)
        try walk(play, to: SIMD2(17000, 5000), interrupt: true)
        try conversation(play, answers: ["Just looked at the cover.", "I think he's a writer.", "You know this guy?", "The Secret Word?"], topics: [12, 13, 14, 15, 17, 16])
        for topic: Int in [12, 13, 14] { XCTAssertTrue(play.runner.game.keywordAsked(topic, person: 8)) }
        for topic: Int in [15, 16, 17] { XCTAssertTrue(play.runner.game.keywordAsked(topic, person: 3)) }
        try walk(play, to: SIMD2(5000, 5000))
        try walk(play, to: SIMD2(-22000, 11000), interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        try walk(play, to: SIMD2(-30000, -27000), interrupt: true)
        try walk(play, to: SIMD2(50000, -27000), interrupt: true)
        play.holdLobbyTouch(x: 40, y: 50)
        for _ in 0..<24 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 4)
        play.talkToNearbyPerson()
        try conversation(play, answers: [], topics: [])
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        XCTAssertEqual(play.runner.game.nowTime, 2, "The post-dinner scene must reach 6:20 PM")
        if let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] {
            try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("dinner"))
                .save(play.walkingCheckpoint())
        }
    }

    static func walk(_ play: OriginalPlaySession, to target: SIMD2<Float>, interrupt: Bool = false) throws {
        let map = play.runner.game.mapID
        defer { play.releaseLobbyTouch() }
        for _ in 0..<700 {
            drain(play, interrupt: interrupt)
            if play.runner.game.mapID != map { return }
            if case .choice = play.runner.phase { return }
            if case .questions = play.runner.phase { return }
            if case .picture = play.runner.phase { return }
            guard case .exploration = play.runner.phase, let position = play.lobby?.position else {
                throw OriginalDataError.invalid("Walking toward \(target) stopped: \(play.runner.phase)")
            }
            let dx = target.x - position.x, dz = target.y - position.z
            let distance = hypot(dx, dz)
            if distance < 400 { return }
            play.holdLobbyTouch(x: 96 + dx / distance * 80, y: 128 + dz / distance * 80)
            play.advanceFrame()
        }
        throw OriginalDataError.invalid("Unreachable route point \(target): \(String(describing: play.lobby?.position))")
    }

    /// Walks to a target along an A* path over cells that the original wall probes leave unchanged.
    /// The path only chooses ordinary walking targets; collision still runs through normal movement.
    static func navigate(_ play: OriginalPlaySession, to target: SIMD2<Float>, interrupt: Bool = false) throws {
        for _ in 0..<4 where play.closeup != nil { play.leaveSearchCloseup() }
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        if play.door != nil { play.leaveDoor() }
        let lobby = try XCTUnwrap(play.lobby)
        let collision = lobby.collision, y = lobby.position.y, cell: Float = 1024
        let people = lobby.people(in: play.runner.game).map(\.position)
        var free = [SIMD2<Int32>: Bool]()
        func point(_ c: SIMD2<Int32>) -> SIMD3<Float> { SIMD3(Float(c.x) * cell, y, Float(c.y) * cell) }
        func walkable(_ c: SIMD2<Int32>) -> Bool {
            if let known = free[c] { return known }
            let p = point(c)
            let open = simd_distance(collision.resolve(p), p) < 1
                && collision.firstRegion(containing: p, prefix: "in_") == nil
                && people.allSatisfy { hypot($0.x - p.x, $0.z - p.z) > 9000 }
            free[c] = open
            return open
        }
        let start = SIMD2<Int32>(Int32((lobby.position.x / cell).rounded()), Int32((lobby.position.z / cell).rounded()))
        let exact = SIMD2<Int32>(Int32((target.x / cell).rounded()), Int32((target.y / cell).rounded()))
        // A target against a wall falls back to the nearest open cell.
        var goal = exact
        if !walkable(exact) {
            var nearest: SIMD2<Int32>?
            for radius in Int32(1)...12 where nearest == nil {
                for dz in -radius...radius { for dx in -radius...radius where max(abs(dx), abs(dz)) == radius {
                    let c = exact &+ SIMD2(dx, dz)
                    if walkable(c), nearest.map({ hypot(Float(c.x - exact.x), Float(c.y - exact.y)) < hypot(Float($0.x - exact.x), Float($0.y - exact.y)) }) ?? true { nearest = c }
                } }
            }
            goal = nearest ?? exact
        }
        func h(_ c: SIMD2<Int32>) -> Float { hypot(Float(c.x - goal.x), Float(c.y - goal.y)) }
        var open: [(SIMD2<Int32>, Float)] = [(start, h(start))]
        var cost: [SIMD2<Int32>: Float] = [start: 0], parent = [SIMD2<Int32>: SIMD2<Int32>]()
        var reached: SIMD2<Int32>?
        let steps: [SIMD2<Int32>] = [.init(1, 0), .init(-1, 0), .init(0, 1), .init(0, -1),
                                     .init(1, 1), .init(1, -1), .init(-1, 1), .init(-1, -1)]
        while !open.isEmpty, cost.count < 60000 {
            let best = open.indices.min { open[$0].1 < open[$1].1 }!
            let current = open.remove(at: best).0
            if h(current) <= 1.5 { reached = current; break }
            for step in steps {
                let next = current &+ step
                guard current == start || walkable(current), walkable(next) else { continue }
                let total = cost[current]! + hypot(Float(step.x), Float(step.y))
                if total < cost[next] ?? .infinity {
                    cost[next] = total
                    parent[next] = current
                    open.append((next, total + h(next)))
                }
            }
        }
        // An unreachable goal ends at the explored cell nearest to it.
        let found = reached != nil
        if reached == nil {
            reached = cost.keys.filter { $0 == start || walkable($0) }.min { h($0) < h($1) }
        }
        guard var node = reached else { throw OriginalDataError.invalid("No walkable path to \(target) via \(goal) from \(start); explored \(cost.count)") }
        var path = [node]
        while let previous = parent[node] { path.append(previous); node = previous }
        path.reverse()
        // Keep only the cells where the direction changes.
        var waypoints = [SIMD2<Float>]()
        for index in 1..<max(path.count, 1) {
            let direction = path[index] &- path[index - 1]
            if index + 1 < path.count, path[index + 1] &- path[index] == direction { continue }
            waypoints.append(SIMD2(Float(path[index].x) * cell, Float(path[index].y) * cell))
        }
        if found, goal == exact { waypoints.append(target) }
        let map = play.runner.game.mapID
        for (index, waypoint) in waypoints.enumerated() {
            // Intermediate waypoints only steer; a wall push near one moves on to the next.
            if index + 1 < waypoints.count {
                approach(play, to: waypoint, interrupt: interrupt)
            } else {
                try walk(play, to: waypoint, interrupt: interrupt)
            }
            guard case .exploration(map) = play.runner.phase else { return }
        }
    }

    /// Walks toward a point until close, an event starts, or 40 frames pass without progress.
    private static func approach(_ play: OriginalPlaySession, to target: SIMD2<Float>, interrupt: Bool) {
        let map = play.runner.game.mapID
        defer { play.releaseLobbyTouch() }
        var best = Float.infinity, stalled = 0
        for _ in 0..<700 {
            drain(play, interrupt: interrupt)
            guard play.runner.game.mapID == map, case .exploration = play.runner.phase,
                  let position = play.lobby?.position else { return }
            let dx = target.x - position.x, dz = target.y - position.z, distance = hypot(dx, dz)
            if distance < 400 { return }
            if distance < best - 50 { best = distance; stalled = 0 } else { stalled += 1 }
            if stalled > 40 { return }
            play.holdLobbyTouch(x: 96 + dx / distance * 80, y: 128 + dz / distance * 80)
            play.advanceFrame()
        }
    }

    /// World position of the in_ marker for a destination.
    static func doorMarker(_ play: OriginalPlaySession, _ destination: Int16) throws -> SIMD2<Float> {
        let name = "in_" + OriginalMapExploration.mapNames[Int(destination)].lowercased()
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == name }, "No marker \(name)")
        return SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
    }

    /// Navigates to the door marker for a destination, faces it and goes through.
    /// `expectArrival: false` allows a departure script that keeps Kyle in the room.
    static func exit(_ play: OriginalPlaySession, to destination: Int16, interrupt: Bool = false,
                     expectArrival: Bool = true) throws {
        let name = "in_" + OriginalMapExploration.mapNames[Int(destination)].lowercased()
        let target = try doorMarker(play, destination)
        let collision = try XCTUnwrap(play.lobby).collision, y = play.lobby?.position.y ?? 0
        // Stand on the nearest open cell within the original 12288-unit door range.
        let here = SIMD2<Float>(play.lobby?.position.x ?? 0, play.lobby?.position.z ?? 0)
        var candidates = [SIMD2<Float>]()
        for dz in stride(from: -10240, through: 10240, by: 1024) {
            for dx in stride(from: -10240, through: 10240, by: 1024) {
                let c = target + SIMD2<Float>(Float(dx), Float(dz))
                let p = SIMD3<Float>(c.x, y, c.y)
                let distance = simd_distance(c, target)
                guard distance > 3000, distance < 9000, simd_distance(collision.resolve(p), p) < 1,
                      collision.firstRegion(containing: p, prefix: "in_") == nil else { continue }
                candidates.append(c)
            }
        }
        candidates.sort { simd_distance($0, here) < simd_distance($1, here) }
        XCTAssertFalse(candidates.isEmpty, "No standing point near \(name)")
        let map = play.runner.game.mapID
        // A candidate behind the wall is unreachable; try the next nearest.
        for stand in candidates.prefix(8) {
            try navigate(play, to: stand, interrupt: interrupt)
            guard play.runner.game.mapID == map, case .exploration = play.runner.phase, let lobby = play.lobby else { break }
            if hypot(lobby.position.x - stand.x, lobby.position.z - stand.y) < 1500 { break }
        }
        guard play.runner.game.mapID == map, case .exploration = play.runner.phase else { return }
        face(play, x: target.x, z: target.y)
        if play.nearbyDoor == destination {
            guard expectArrival else {
                play.inspectNearbyDoor()
                drain(play, interrupt: interrupt)
                return
            }
            return try door(play, destination: destination, interrupt: interrupt)
        }
        // Walk-through exits change map when Kyle enters the marker's collision region.
        let standing = SIMD2<Float>(play.lobby?.position.x ?? 0, play.lobby?.position.z ?? 0)
        approach(play, to: target + (target - standing) * 4, interrupt: interrupt)
        if expectArrival { XCTAssertEqual(play.runner.game.mapID, destination) }
    }

    /// Opens the facing door view and confirms the component with an original hit index (1 knocks, 2 is the handle).
    static func doorComponent(_ play: OriginalPlaySession, _ component: Int, item: UInt8? = nil, interrupt: Bool = false) throws {
        if play.door == nil {
            play.inspectNearbyDoor()
            drain(play, interrupt: interrupt)
        }
        let points = stride(from: 8, to: 248, by: 2).flatMap { y in stride(from: 8, to: 184, by: 2).map { ($0, y) } }
        let point = try XCTUnwrap(points.first { play.doorImage?.hit(pageX: $0.0, pageY: $0.1) == component }, "No door component \(component)")
        if let item { play.useItemAtDoor(item) }
        play.selectDoorComponent(x: point.0, y: point.1, confirmImmediately: true)
        drain(play, interrupt: interrupt)
    }

    static func door(_ play: OriginalPlaySession, destination: Int16, interrupt: Bool = false) throws {
        XCTAssertEqual(play.nearbyDoor, destination)
        play.inspectNearbyDoor()
        drain(play, interrupt: interrupt)
        if play.door != nil {
            let point = [(158, 180), (32, 175)].first { play.doorImage?.hit(pageX: $0.0, pageY: $0.1) == 2 }
            let handle = try XCTUnwrap(point)
            play.selectDoorComponent(x: handle.0, y: handle.1, confirmImmediately: true)
            drain(play, interrupt: interrupt)
        }
        XCTAssertEqual(play.runner.game.mapID, destination)
    }

    /// With `itemsFirst`, items are presented before topics, and topics are asked again after each item.
    static func conversation(_ play: OriginalPlaySession, answers: [String], topics: [Int16], show items: [UInt8] = [],
                             itemsFirst: Bool = false) throws {
        var asked = Set<Int16>(), shown = Set<UInt8>()
        for _ in 0..<200 {
            drain(play, interrupt: true)
            switch play.runner.phase {
            case .choice(let choices):
                guard let choice = choices.first(where: { answers.contains($0.label) }) else {
                    throw OriginalDataError.invalid("Unexpected choices: \(choices)")
                }
                play.choose(choice.id)
            case .questions(let available):
                if itemsFirst, let item = items.first(where: { !shown.contains($0) }),
                   (try? play.runner.game.inventory.items.contains(item)) == true {
                    shown.insert(item)
                    asked.removeAll()
                    play.showItemInConversation(item)
                } else if let topic = topics.first(where: { candidate in !asked.contains(candidate) && available.contains(where: { $0.keyword == candidate }) }) {
                    // Select by the recovered keyword ID, without changing story state directly.
                    guard available.contains(where: { $0.keyword == topic }) else {
                        throw OriginalDataError.invalid("Missing topic \(topic): \(available)")
                    }
                    asked.insert(topic)
                    play.ask(topic)
                } else if (0..<32).contains(where: { play.runner.game.memoAvailable($0) && !play.runner.game.memoRead($0) }) {
                    // A new memo in the notebook answers the conversation (0x02078138).
                    play.openNotebook()
                    play.closeNotebook()
                } else if let item = items.first(where: { !shown.contains($0) }) {
                    // Present an item from the question menu's inventory.
                    shown.insert(item)
                    play.showItemInConversation(item)
                } else { play.leaveConversation() }
            case .picture: try picture(play, interrupt: true)
            case .process(73): try compareSignatures(play)
            case .process(38): try repairDoll(play)
            case .process(60): try searchLinenWagon(play)
            case .process(51): try solveCoins(play)
            case .process(58): try playJukebox(play, record: 25)
            case .process(53), .process(54): try solveMatchsticks(play)
            case .exploration: return
            default: throw OriginalDataError.invalid("Conversation stopped: \(play.runner.phase)")
            }
        }
        throw OriginalDataError.invalid("Conversation did not finish: \(play.runner.phase)")
    }

    static func drain(_ play: OriginalPlaySession, interrupt: Bool = false) {
        var interrupted = false
        for _ in 0..<1000 {
            if interrupt && !interrupted && play.runner.interruptAvailable {
                play.interrupt()
                interrupted = true
                continue
            }
            switch play.runner.phase {
            case .dialogue, .itemNotice:
                if ProcessInfo.processInfo.environment["HOTEL_DUSK_TRACE_ROUTE"] != nil,
                   case .dialogue(let packet) = play.runner.phase {
                    print(packet.pages.flatMap(\.entries).map { String(decoding: $0.bytes, as: UTF8.self) }.joined(separator: " "))
                }
                play.advanceDialogue()
            case .waiting, .process(126): play.advanceFrame()
            default: return
            }
        }
        XCTFail("Chapter 3 event did not return control")
    }

    /// Holds the walking touch toward a point for a fixed number of frames, stopping at walls.
    static func nudge(_ play: OriginalPlaySession, toward target: SIMD2<Float>, frames: Int = 30) {
        defer { play.releaseLobbyTouch() }
        for _ in 0..<frames {
            guard case .exploration = play.runner.phase, let position = play.lobby?.position else { return }
            let dx = target.x - position.x, dz = target.y - position.z, distance = hypot(dx, dz)
            if distance < 400 { return }
            play.holdLobbyTouch(x: 96 + dx / distance * 40, y: 128 + dz / distance * 40)
            play.advanceFrame()
        }
    }

    /// Walks up to a person, faces them and starts the conversation.
    static func talk(_ play: OriginalPlaySession, to person: Int16, interrupt: Bool = true) throws {
        let lobby = try XCTUnwrap(play.lobby)
        let target = try XCTUnwrap(lobby.people(in: play.runner.game).first { $0.id == person }, "Person \(person) is absent")
        let here = SIMD2<Float>(lobby.position.x, lobby.position.z)
        let there = SIMD2<Float>(target.position.x, target.position.z)
        // Stand on an open point inside the original talk range, nearest to Kyle.
        var stands = [SIMD2<Float>]()
        for radius: Float in [10000, 12000, 14000] {
            for step in 0..<24 {
                let angle = Float(step) * .pi / 12
                let point = there + SIMD2(sin(angle), cos(angle)) * radius
                let p = SIMD3<Float>(point.x, lobby.position.y, point.y)
                if simd_distance(lobby.collision.resolve(p), p) < 1,
                   lobby.collision.firstRegion(containing: p, prefix: "in_") == nil { stands.append(point) }
            }
        }
        stands.sort { simd_distance($0, here) < simd_distance($1, here) }
        for stand in stands.prefix(6) {
            // Character collision can stop Kyle short of the exact standing point.
            try? navigate(play, to: stand, interrupt: interrupt)
            guard case .exploration = play.runner.phase else { return }
            face(play, x: target.position.x, z: target.position.z)
            if play.lobby?.nearbyPerson(in: play.runner.game) == person { break }
        }
        XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), person)
        play.talkToNearbyPerson()
        drain(play, interrupt: interrupt)
    }

    /// Debug view of walls (#), event regions (letters a–z), search regions (digits) and exits (>).
    static func printMap(_ play: OriginalPlaySession, step: Int = 2048, range: ClosedRange<Int> = -100_000...100_000) {
        guard let lobby = play.lobby else { return }
        let c = lobby.collision
        for z in stride(from: range.upperBound, through: range.lowerBound, by: -step) {
            let row = stride(from: range.lowerBound, through: range.upperBound, by: step).map { x -> Character in
                let p = SIMD3<Float>(Float(x), lobby.position.y, Float(z))
                if abs(p.x - lobby.position.x) < Float(step / 2) + 1, abs(p.z - lobby.position.z) < Float(step / 2) + 1 { return "@" }
                if let r = c.firstRegion(containing: p, prefix: "event"), let n = Int(r.dropFirst(5).prefix(2)) {
                    return Character(UnicodeScalar(UInt8(96 + min(n, 26))))
                }
                if c.firstRegion(containing: p, prefix: "in_") != nil { return ">" }
                if let r = c.firstRegion(containing: p, prefix: "search") { return r.dropFirst(7).first ?? "?" }
                return simd_distance(c.resolve(p), p) < 1 ? "." : "#"
            }
            if row.contains(where: { $0 != "." }) { print("MAP", String(format: "%7d", z), String(row)) }
        }
    }

    /// Turns in place toward a world point.
    static func face(_ play: OriginalPlaySession, x: Float, z: Float) {
        let position = play.lobby?.position ?? .zero
        play.turnFirstPerson(by: atan2(x - position.x, z - position.z) - (play.lobby?.facing ?? 0))
    }

    /// Opens the facing search area, picks a model node and confirms a close-up layer by its event.
    static func search(_ play: OriginalPlaySession, node: String, closeupEvent: Int16? = nil, interrupt: Bool = false) throws {
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let points = stride(from: 8, to: 248, by: 4).flatMap { y in stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) } }
        let object = try XCTUnwrap(try points.first { try counter.pickedCounterNode(page: $0) == node }, "No visible \(node)")
        play.selectLobbyObject(x: object.x, y: object.y, confirmImmediately: true)
        drain(play, interrupt: interrupt)
        guard let closeupEvent else { return }
        try closeupLayer(play, event: closeupEvent, interrupt: interrupt)
    }

    /// Uses an inventory item on a model node in the facing search area.
    static func useItem(_ play: OriginalPlaySession, _ item: UInt8, on node: String, interrupt: Bool = false) throws {
        if play.lobby?.mode != .counter { play.inspectLobbyCounter() }
        let counter = try XCTUnwrap(play.lobby)
        let points = stride(from: 8, to: 248, by: 4).flatMap { y in stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) } }
        let object = try XCTUnwrap(try points.first { try counter.pickedCounterNode(page: $0) == node }, "No visible \(node)")
        play.useItemInSearchView(item)
        play.selectLobbyObject(x: object.x, y: object.y, confirmImmediately: true)
        drain(play, interrupt: interrupt)
    }

    /// Selects and confirms the open close-up layer with an original up-view event.
    static func closeupLayer(_ play: OriginalPlaySession, event closeupEvent: Int16, item: UInt8? = nil, interrupt: Bool = false) throws {
        let closeup = try XCTUnwrap(play.closeup)
        if let item { play.useItemInCloseup(item) }
        let component = try XCTUnwrap(closeup.view.layers.firstIndex { $0.eventID == closeupEvent }) + 1
        let point = try XCTUnwrap(stride(from: 8, to: 248, by: 2).flatMap { y in stride(from: 8, to: 184, by: 2).map { SIMD2<Int>($0, y) } }
            .first { play.closeupImage?.hit(pageX: $0.x, pageY: $0.y) == component })
        play.selectCloseupComponent(x: point.x, y: point.y, confirmImmediately: true)
        drain(play, interrupt: interrupt)
    }

    /// Slides the toilet tank lid open with slow leftward drags (process 48).
    static func openToiletTank(_ play: OriginalPlaySession, interrupt: Bool = false) throws {
        XCTAssertEqual(play.runner.phase, .process(id: 48))
        for _ in 0..<65 { play.advanceFrame() }
        for _ in 0..<20 where play.toiletTank?.stage == 1 {
            play.releaseToiletTankTouch(); play.advanceFrame()
            let rect = try XCTUnwrap(play.toiletTank?.lidRectangle)
            for i in 0..<20 {
                play.holdToiletTankTouch(x: Float(rect.z - 5 - i), y: Float((rect.y + rect.w) / 2))
                play.advanceFrame()
            }
        }
        play.releaseToiletTankTouch()
        for _ in 0..<400 where play.toiletTank != nil { play.advanceFrame() }
        drain(play, interrupt: interrupt)
    }

    /// Circles both signature differences with separate surrounding strokes (process 73).
    static func compareSignatures(_ play: OriginalPlaySession, interrupt: Bool = true) throws {
        XCTAssertEqual(play.runner.phase, .process(id: 73))
        for _ in 0..<65 { play.advanceFrame() }
        for rect in OriginalDifferencesProcess.targets {
            let points: [SIMD2<Int>] = [.init(rect.x - 5, rect.y - 5), .init(rect.z + 5, rect.y - 5),
                .init(rect.z + 5, rect.w + 5), .init(rect.x - 5, rect.w + 5), .init(rect.x - 5, rect.y - 5)]
            for point in points { play.holdDifferencesTouch(x: Float(point.x), y: Float(point.y)); play.advanceFrame() }
            play.releaseDifferencesTouch(); play.advanceFrame(); play.advanceFrame()
        }
        for _ in 0..<300 where play.differences != nil { play.advanceFrame() }
        XCTAssertNil(play.differences)
        drain(play, interrupt: interrupt)
    }

    /// Sews all three seam sections with one zigzag stroke (process 38).
    static func repairDoll(_ play: OriginalPlaySession, interrupt: Bool = true) throws {
        XCTAssertEqual(play.runner.phase, .process(id: 38))
        for _ in 0..<65 { play.advanceFrame() }
        for step in 0...10 {
            play.holdDollRepairTouch(x: step % 2 == 0 ? 150 : 180, y: Float(130 + step * 7)); play.advanceFrame()
        }
        play.releaseDollRepairTouch()
        for _ in 0..<300 where play.dollRepair != nil { play.advanceFrame() }
        XCTAssertNil(play.dollRepair)
        drain(play, interrupt: interrupt)
    }

    /// Throws off all six sheets, then uncovers and selects the gun in the linen cart (process 60).
    static func searchLinenWagon(_ play: OriginalPlaySession, interrupt: Bool = true) throws {
        XCTAssertEqual(play.runner.phase, .process(id: 60))
        for _ in 0..<65 { play.advanceFrame() }
        for index in 0..<6 {
            let point = try XCTUnwrap(play.linenWagon).pieces[index].pageCenter
            play.holdLinenWagonTouch(x: point.x.rounded(), y: point.y.rounded())
            for _ in 0..<3 { play.advanceFrame() }
            play.holdLinenWagonTouch(x: 0, y: point.y.rounded())
            for _ in 0..<3 { play.advanceFrame() }
            play.releaseLinenWagonTouch()
            for _ in 0..<65 { play.advanceFrame() }
        }
        XCTAssertEqual(play.linenWagon?.allSheetsRemoved, true)
        play.holdLinenWagonTouch(x: 96, y: 170); play.advanceFrame(); play.releaseLinenWagonTouch()
        for _ in 0..<35 { play.advanceFrame() }
        play.holdLinenWagonTouch(x: 96, y: 110); play.advanceFrame(); play.releaseLinenWagonTouch()
        for _ in 0..<100 { play.advanceFrame() }
        play.holdLinenWagonTouch(x: 110, y: 120); play.advanceFrame(); play.releaseLinenWagonTouch()
        for _ in 0..<350 where play.linenWagon != nil { play.advanceFrame() }
        XCTAssertNil(play.linenWagon)
        drain(play, interrupt: interrupt)
    }

    /// Opens the lower suitcase compartment and takes a stored object by double selection (process 35).
    static func takeFromSuitcase(_ play: OriginalPlaySession, lowerIndex: Int, interrupt: Bool = true) throws {
        XCTAssertEqual(play.runner.phase, .process(id: 35))
        for _ in 0..<70 { play.advanceFrame() }
        play.holdSuitcaseContentsTouch(x: 96, y: 160)
        play.advanceFrame()
        play.releaseSuitcaseContentsTouch()
        for _ in 0..<160 { play.advanceFrame() }
        let contents = try XCTUnwrap(play.suitcaseContents).contents
        let points = stride(from: 2, to: 254, by: 2).flatMap { y in stride(from: 2, to: 190, by: 2).map { SIMD2<Float>(Float($0), Float(y)) } }
        let point = try XCTUnwrap(try points.first { try contents.hit(page: $0, in: .lower, game: play.runner.game) == lowerIndex },
                                  "Suitcase object \(lowerIndex) is not visible")
        for _ in 0..<2 {
            play.holdSuitcaseContentsTouch(x: point.x, y: point.y)
            play.advanceFrame()
            play.releaseSuitcaseContentsTouch()
            play.advanceFrame()
        }
        for _ in 0..<300 {
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .process(35), .waiting: play.advanceFrame()
            default: break
            }
        }
        play.leaveSuitcaseContents()
        for _ in 0..<150 { play.advanceFrame() }
        play.leaveSuitcaseContents()
        for _ in 0..<250 {
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            default: play.advanceFrame()
            }
        }
        XCTAssertNil(play.suitcaseContents)
        drain(play, interrupt: interrupt)
    }

    /// Stacks the top coin on the centre coin and checks the answer (process 51).
    static func solveCoins(_ play: OriginalPlaySession, interrupt: Bool = true) throws {
        XCTAssertEqual(play.runner.phase, .process(id: 51))
        for _ in 0..<65 { play.advanceFrame() }
        play.holdCoinPuzzleTouch(x: 96, y: 51); play.advanceFrame()
        play.holdCoinPuzzleTouch(x: 96, y: 128); play.advanceFrame()
        play.releaseCoinPuzzleTouch(); play.advanceFrame()
        XCTAssertEqual(play.coinPuzzle?.isCorrect, true)
        play.checkCoinPuzzle()
        for _ in 0..<350 where play.coinPuzzle != nil { play.advanceFrame() }
        XCTAssertNil(play.coinPuzzle)
        drain(play, interrupt: interrupt)
    }

    /// Finds sticks whose removal satisfies the process's own completion test, then taps them (processes 53, 54).
    static func solveMatchsticks(_ play: OriginalPlaySession, interrupt: Bool = true) throws {
        let start = try XCTUnwrap(play.matchsticks)
        func removing(_ puzzle: OriginalMatchstickProcess, _ index: Int) -> OriginalMatchstickProcess {
            var puzzle = puzzle
            _ = puzzle.update(pageTouch: puzzle.sticks[index].center)
            for _ in 0..<200 where puzzle.sticks[index].state != 0 || puzzle.stage != 0 { _ = puzzle.update() }
            return puzzle
        }
        var model = OriginalMatchstickProcess(variant: start.variant)
        _ = model.update(); _ = model.update(fadeComplete: true)
        func search(_ puzzle: OriginalMatchstickProcess, from first: Int, removed: [Int]) -> [Int]? {
            if removed.count == puzzle.removalLimit { return puzzle.isCorrect ? removed : nil }
            for index in first..<puzzle.sticks.count {
                if let found = search(removing(puzzle, index), from: index + 1, removed: removed + [index]) { return found }
            }
            return nil
        }
        let solution = try XCTUnwrap(search(model, from: 0, removed: []), "No matchstick solution")
        for _ in 0..<65 where play.matchsticks?.phase == 0 { play.advanceFrame() }
        for index in solution {
            let point = try XCTUnwrap(play.matchsticks).sticks[index].center
            play.holdMatchsticksTouch(x: Float(point.x), y: Float(point.y)); play.advanceFrame()
            play.releaseMatchsticksTouch()
            for _ in 0..<80 { play.advanceFrame() }
        }
        for _ in 0..<500 where play.matchsticks != nil { play.advanceFrame() }
        XCTAssertNil(play.matchsticks)
        drain(play, interrupt: interrupt)
    }

    /// Plays one jukebox record, then leaves the jukebox (process 58).
    static func playJukebox(_ play: OriginalPlaySession, record: Int, interrupt: Bool = true) throws {
        XCTAssertEqual(play.runner.phase, .process(id: 58))
        play.advanceFrame()
        XCTAssertNotNil(play.jukebox)
        play.selectJukeboxRecord(record)
        XCTAssertEqual(play.runner.game.jukeboxSequence, Int16(record))
        play.quitJukebox()
        XCTAssertNil(play.jukebox)
        drain(play, interrupt: interrupt)
    }

    /// Selects and confirms a touch picture at the first point inside its original hit mask.
    static func picture(_ play: OriginalPlaySession, interrupt: Bool = false) throws {
        let picture = try XCTUnwrap(play.touchPicture)
        let points = stride(from: 8, through: 247, by: 2).flatMap { y in stride(from: 8, through: 183, by: 2).map { ($0, y) } }
        let point = try XCTUnwrap(points.first { picture.contains(pageX: $0.0, pageY: $0.1) })
        for _ in 0..<2 {
            play.touchPicture(pageX: point.0, pageY: point.1)
            play.releasePicture()
        }
        for _ in 0..<60 {
            guard case .picture = play.runner.phase else { break }
            play.advanceFrame()
        }
        drain(play, interrupt: interrupt)
    }

    static func choose(_ play: OriginalPlaySession, _ label: String, interrupt: Bool = false) throws {
        guard case .choice(let choices) = play.runner.phase,
              let choice = choices.first(where: { $0.label == label }) else {
            throw OriginalDataError.invalid("Missing choice \(label): \(play.runner.phase)")
        }
        play.choose(choice.id)
        drain(play, interrupt: interrupt)
    }
}
