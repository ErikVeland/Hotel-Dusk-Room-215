import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalPageInputTests: XCTestCase {
    func testDisplayedDoorHandleResolvesToSameOriginalComponentAtDifferentSizes() throws {
        let view = try XCTUnwrap(OriginalUpViewTable.bundled(map: "R213").views.first { $0.id == 341 })
        let library = try OriginalBitmapLibrary.bundled()
        let bitmaps = try ([view.background] + view.layers.map(\.asset)).map {
            try library.loadLinear(path: "map/sdata/SearchUp/\($0).bin")
        }
        let image = try OriginalUpViewImage(bitmaps: bitmaps, visible: [true, true, true, true])
        for available in [CGSize(width: 170, height: 300), CGSize(width: 360, height: 420),
                          CGSize(width: 600, height: 800)] {
            let input = OriginalPageInput(available: available)
            for (pixel, expected) in [(CGPoint(x: 160, y: 175), 2), (CGPoint(x: 96, y: 100), 1),
                                      (CGPoint(x: 96, y: 45), 3)] {
                let touch = CGPoint(x: (pixel.x + 0.5) * input.scale, y: (pixel.y + 0.5) * input.scale)
                let point = try XCTUnwrap(input.point(touch))
                XCTAssertEqual(image.hit(pageX: Int(point.x), pageY: Int(point.y)), expected)
            }
            XCTAssertNil(input.point(CGPoint(x: -1, y: 100)))
            XCTAssertNil(input.point(CGPoint(x: input.size.width + 1, y: 100)))
        }
    }

    func testFingerDriftIsAcceptedButDraggingDoesNotSelectAnObject() {
        XCTAssertTrue(OriginalPageInput.isTap(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 115, y: 110)))
        XCTAssertFalse(OriginalPageInput.isTap(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 140, y: 100)))
        XCTAssertNil(OriginalPageInput(available: .zero).point(.zero))
    }
}
