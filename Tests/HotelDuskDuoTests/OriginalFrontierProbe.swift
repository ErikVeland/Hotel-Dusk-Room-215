import XCTest
@testable import HotelDuskDuoKit

/// Prints how far automatic play reaches. Processes return 0 and the first
/// option is taken; this is a recovery aid, not a story assertion.
final class OriginalFrontierProbe: XCTestCase {
    func testPrintChapterOneFrontier() throws {
        var runner = try OriginalEventRunner.chapterOneArrival(catalog: .bundled(), defaults: .bundled())
        var trail: [String] = []
        var looked = false
        var tried = Set<UInt16>()
        for _ in 0..<2000 {
            if let index = runner.eventIndex, trail.last != "e\(index)" { trail.append("e\(index)") }
            switch runner.phase {
            case .dialogue where runner.interruptAvailable: trail.append("hold"); runner.pressInterrupt()
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .choice(let choices):
                let pick = choices.first { !tried.contains($0.id) } ?? choices[0]
                tried.insert(pick.id); trail.append("pick\(pick.id)"); runner.choose(pick.id)
            case .questions(let topics):
                if let topic = topics.first { trail.append("ask\(topic.keyword)"); runner.ask(topic.keyword) }
                else { trail.append("leave"); runner.leave() }
            case .process(let id):
                trail.append("p\(id)")
                runner.finishProcess(returnValue: 0)
            case .waiting: runner.advanceWait()
            case .picture(let id):
                print("FRONTIER touch picture \(id) after \(trail.joined(separator: " "))"); return
            case .exploration where !looked:
                looked = true
                runner.lookInSearchView(area: 2, subarea: 2, table: try .bundled(map: "R102"))
            case .exploration(let map):
                print("FRONTIER exploration map \(map) after \(trail.joined(separator: " "))\nEVENTS \(runner.eventTrail)\nMISS \(String(describing: runner.lastSelectionMiss))"); return
            case .halted(let halt):
                print("FRONTIER halt \(halt) after \(trail.joined(separator: " "))\nEVENTS \(runner.eventTrail)"); return
            }
        }
        print("FRONTIER loop limit after \(trail.suffix(40).joined(separator: " "))")
    }
}
