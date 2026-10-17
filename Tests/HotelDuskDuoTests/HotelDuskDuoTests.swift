import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class HotelDuskDuoTests: XCTestCase {
    func testHingePostureTransitions() {
        let hinge = DuoHingeManager()
        XCTAssertEqual(hinge.posture, .bookOpen)

        hinge.setHingeAngle(110.0)
        XCTAssertEqual(hinge.posture, .tentOrLaptop)

        hinge.setHingeAngle(2.0)
        XCTAssertEqual(hinge.posture, .foldedClosed)
        XCTAssertNotNil(hinge.lastFoldTimestamp)
    }

    func testHandednessToggle() {
        let hinge = DuoHingeManager(initialHandedness: .rightHanded)
        XCTAssertEqual(hinge.handedness, .rightHanded)

        hinge.toggleHandedness()
        XCTAssertEqual(hinge.handedness, .leftHanded)

        hinge.toggleHandedness()
        XCTAssertEqual(hinge.handedness, .rightHanded)
    }

    func testNativeBuildDoesNotStartInventedGameplay() throws {
        let session = GameSession()
        XCTAssertNil(session.play)
        XCTAssertNil(session.originalProgram)
        XCTAssertNil(session.sourceError)
        try session.loadOriginalProgram("EP1_R102")
        XCTAssertEqual(session.originalProgram?.name, "EP1_R102")
        XCTAssertNil(session.play, "Loaded data is not recovered gameplay")
        // An explicit start enters the original arrival event, nothing else.
        XCTAssertTrue(session.canStartOriginalGame)
        session.startOriginalGame()
        XCTAssertEqual(session.play?.runner.program.name, "EP1_R102")
        XCTAssertEqual(session.play?.runner.eventIndex, 0)
        session.endOriginalGame()
        XCTAssertNil(session.play)
    }

    func testAssetCatalogLoading() {
        let catalog = AssetLoader.shared.loadCatalog()
        XCTAssertNotNil(catalog)
        XCTAssertNotNil(catalog?.items)
        XCTAssertTrue((catalog?.items?.count ?? 0) > 0)
    }

    func testHingeHysteresisIgnoresSensorJitter() {
        let hinge = DuoHingeManager()
        // ±5° noise around the 150° book threshold must not leave book mode
        for angle in [146.0, 152.0, 144.0, 149.0] {
            hinge.setHingeAngle(angle)
            XCTAssertEqual(hinge.posture, .bookOpen, "jitter at \(angle)°")
        }
        hinge.setHingeAngle(120.0)
        XCTAssertEqual(hinge.posture, .tentOrLaptop)

        hinge.setHingeAngle(3.0)
        XCTAssertEqual(hinge.posture, .foldedClosed)
        // Still closed while the lid rests slightly open
        hinge.setHingeAngle(12.0)
        XCTAssertEqual(hinge.posture, .foldedClosed)
        hinge.setHingeAngle(30.0)
        XCTAssertEqual(hinge.posture, .tentOrLaptop)
    }

    func testRomBackgroundLoadsUpright() throws {
        let code = "R213"
        let image = try XCTUnwrap(RomImageCache.shared.image(named: "\(code)_L"))
        // Decoded upright for book mode: portrait, 96×128
        XCTAssertEqual(image.width, 96)
        XCTAssertEqual(image.height, 128)
    }
}

