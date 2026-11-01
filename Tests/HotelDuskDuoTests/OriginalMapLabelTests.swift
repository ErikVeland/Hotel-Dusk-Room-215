import XCTest
@testable import HotelDuskDuoKit

final class OriginalMapLabelTests: XCTestCase {
    func testGuestRoomLabelsMatchDestinationMapIDs() {
        for room in 211...220 {
            XCTAssertEqual(OriginalMapExploration.displayName(for: Int16(room - 184)), "2F Room \(room)")
        }
    }

    func testLabelsRemainAlignedAcrossUnusedMaps() {
        let expected: [Int16: String] = [
            19: "1F Left Hallway", 22: "1F Storage", 25: "1F Room 111",
            26: "1F Restaurant", 37: "2F Linens", 38: "2F Utility Closet",
            39: "2F Hallway", 40: "BF Basement", 41: "BF Secret Room",
            43: "BF Hallway", 44: "BF Basement", 45: "RF Roof"
        ]
        for (mapID, label) in expected {
            XCTAssertEqual(OriginalMapExploration.displayName(for: mapID), label, "Map \(mapID)")
        }
        XCTAssertEqual(OriginalMapExploration.displayName(for: 0), "Door")
        XCTAssertEqual(OriginalMapExploration.displayName(for: 47), "Door")
    }
}
