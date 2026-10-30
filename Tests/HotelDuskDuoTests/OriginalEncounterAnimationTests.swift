import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalEncounterAnimationTests: XCTestCase {
    private func packet(person: Int8, pose: Int8, screen: UInt8 = 0, offset: Int = 10,
                        other: (Int8, Int8)? = nil, animationEnabled: Bool = true) throws -> OriginalDialoguePacket {
        let text = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102").text
        var raw = [UInt8](repeating: 0, count: 16)
        raw[0] = 4
        raw[1] = other == nil ? screen : 2
        raw[2] = UInt8(bitPattern: person)
        raw[3] = UInt8(bitPattern: pose)
        raw[5] = 255
        raw[6] = animationEnabled ? 0 : 1
        raw[10] = 10
        let record = OriginalBlockGraph.Record(index: 0, sourceOffset: offset, raw: Data(raw), children: nil)
        let following = other.map { person, pose -> OriginalBlockGraph.Record in
            var value = [UInt8](repeating: 0, count: 16)
            value[2] = UInt8(bitPattern: person)
            value[3] = UInt8(bitPattern: pose)
            value[5] = 255
            return .init(index: 1, sourceOffset: offset + 16, raw: Data(value), children: nil)
        }
        return try OriginalDialoguePacket(record: record, following: following, text: text)
    }

    func testJeffAndMilaUseTheirOriginalExpressionClips() throws {
        let animations = try OriginalEncounterAnimations(catalog: .bundled())
        try animations.present(packet(person: 6, pose: 1), program: "EP1_R213")
        XCTAssertEqual(animations.portraits.map(\.animationID), ["Jf_hanas_"])
        XCTAssertEqual(animations.portraits.first?.frame.frameIndex, 0)
        try animations.present(packet(person: 5, pose: 2, offset: 20), program: "EP1_R119")
        XCTAssertEqual(animations.portraits.map(\.animationID), ["Mi_kikuA_"])
        XCTAssertTrue(animations.portraits[0].frame.rgba.contains { $0 != 0 })
    }

    func testPairedDialogueStartsBothCharactersAndDoesNotRestartAnUnchangedPose() throws {
        let animations = try OriginalEncounterAnimations(catalog: .bundled())
        let source = try packet(person: 1, pose: 1, other: (6, 2))
        try animations.present(source, program: "conversation")
        XCTAssertEqual(animations.portraits.map(\.screen), [0, 1])
        XCTAssertEqual(animations.portraits.map(\.animationID), ["Jf_kikuA_", "Hy_hanas_"])
        for _ in 0..<12 { try animations.advance() }
        XCTAssertTrue(animations.portraits.allSatisfy { $0.frame.frameIndex > 0 })
        let frames = animations.portraits.map { $0.frame.frameIndex }
        try animations.present(source, program: "conversation")
        XCTAssertEqual(animations.portraits.map { $0.frame.frameIndex }, frames)
        try animations.present(packet(person: 1, pose: -1, offset: 30, other: (6, -1)), program: "conversation")
        XCTAssertEqual(animations.portraits.map { $0.frame.frameIndex }, frames)
    }

    func testHideAndKeepCommandsDoNotShowAStaleCharacterInTheNextEncounter() throws {
        let animations = try OriginalEncounterAnimations(catalog: .bundled())
        try animations.present(packet(person: 6, pose: 1), program: "Jeff")
        try animations.present(packet(person: -1, pose: -1, offset: 20), program: "Jeff")
        XCTAssertEqual(animations.portraits.first?.person, 6)
        try animations.present(packet(person: -2, pose: -1, offset: 30), program: "Jeff")
        XCTAssertTrue(animations.portraits.isEmpty)
        try animations.present(packet(person: 5, pose: 1, offset: 40), program: "Mila")
        animations.clear()
        XCTAssertTrue(animations.portraits.isEmpty)
        try animations.present(packet(person: 6, pose: 2), program: "Jeff")
        XCTAssertEqual(animations.portraits.map(\.animationID), ["Jf_kikuA_"])
        XCTAssertEqual(animations.portraits.first?.frame.frameIndex, 0)
    }

    func testEveryExplicitCharacterPoseInEveryBundledDialogueHasADecodableClip() throws {
        let scripts = try OriginalScriptCatalog.bundled()
        let expressions = try OriginalEncounterAnimationCatalog(catalog: scripts)
        let library = try OriginalAnimationLibrary.bundled()
        var checked = Set<String>()
        var dialogueCount = 0
        for name in scripts.programNames {
            let program = try scripts.loadProgram(name)
            let graph = try program.blocks
            for event in graph.tables[2] {
                let records = try graph.operations(forEvent: event.index)
                var index = 0
                while index < records.count {
                    let record = records[index]
                    guard record.raw[0] == 4 else { index += 1; continue }
                    let following = index + 1 < records.count ? records[index + 1] : nil
                    let dialogue = try OriginalDialoguePacket(record: record, following: following, text: program.text)
                    for presentation in dialogue.presentations where (1...17).contains(presentation.person) && presentation.pose > 0 {
                        let id = try expressions.animationID(person: Int(presentation.person), pose: Int(presentation.pose))
                        if checked.insert(id).inserted {
                            var decoder = OriginalAnimationDecoder(clip: try library.load(id: id))
                            XCTAssertNotNil(try decoder.advance(), "\(name) event \(event.index): \(id)")
                        }
                    }
                    dialogueCount += 1
                    index += dialogue.consumedRecordCount
                }
            }
        }
        XCTAssertGreaterThan(dialogueCount, 10_000)
        XCTAssertGreaterThan(checked.count, 200)
    }
}
