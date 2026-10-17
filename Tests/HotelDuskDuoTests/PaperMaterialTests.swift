import XCTest
@testable import HotelDuskDuoKit

final class PaperMaterialTests: XCTestCase {
    func testSettlingHasAFiniteRestAndCanStopImmediately() {
        let opened = Date(timeIntervalSince1970: 1_000)
        var response = PaperSettlingResponse()
        XCTAssertEqual(response.displacement(at: opened), 0)

        response.newOpening(seed: 215, at: opened)
        XCTAssertTrue(response.isActive)
        XCTAssertNotEqual(response.displacement(at: opened), 0)
        for interval in stride(from: 0.0, through: 1.8, by: 0.05) {
            XCTAssertLessThanOrEqual(abs(response.displacement(at: opened.addingTimeInterval(interval))), 1)
        }
        XCTAssertEqual(response.displacement(at: opened.addingTimeInterval(PaperSettlingResponse.duration)), 0,
                       accuracy: 1e-12)
        XCTAssertEqual(response.displacement(at: opened.addingTimeInterval(30)), 0)

        response.stop()
        XCTAssertFalse(response.isActive)
        XCTAssertEqual(response.displacement(at: opened.addingTimeInterval(0.1)), 0)
    }

    func testOpeningVariesTheFlexWithoutChangingItsDeterministicSeed() {
        let opened = Date(timeIntervalSince1970: 1_000)
        var first = PaperSettlingResponse()
        var second = PaperSettlingResponse()
        var matching = PaperSettlingResponse()
        first.newOpening(seed: 215, at: opened)
        second.newOpening(seed: 219, at: opened)
        matching.newOpening(seed: 215, at: opened)

        let sample = opened.addingTimeInterval(0.18)
        XCTAssertEqual(first.displacement(at: sample), matching.displacement(at: sample))
        XCTAssertNotEqual(first.displacement(at: sample), second.displacement(at: sample))

        let previousEvent = first.event
        first.respond(to: 0.2, at: sample)
        XCTAssertGreaterThan(first.event, previousEvent)
        XCTAssertLessThanOrEqual(abs(first.displacement(at: sample)), 0.2)
    }
}
