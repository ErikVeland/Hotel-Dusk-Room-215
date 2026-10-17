import XCTest
import SwiftUI
@testable import HotelDuskDuoKit

final class DuoBookLayoutTests: XCTestCase {
    func testPagesMeetAtDisplayCentreInBothWindowShapes() {
        for size in [CGSize(width: 951, height: 669), CGSize(width: 669, height: 951)] {
            let layout = DuoBookLayout(size: size, safeArea: EdgeInsets(), handedness: .rightHanded)
            let left = layout.frame(at: 0)
            let right = layout.frame(at: 1)
            XCTAssertEqual(left.maxX, size.width / 2)
            XCTAssertEqual(right.minX, left.maxX)
            XCTAssertEqual(right.maxX, size.width)
            XCTAssertEqual(left.height, size.height)
            XCTAssertEqual(right.height, size.height)
            XCTAssertEqual(layout.pages, [.exploration, .touch])
        }
    }

    func testSafeAreasInsetContentWithoutMovingSpine() {
        let layout = DuoBookLayout(size: CGSize(width: 951, height: 669),
                                   safeArea: EdgeInsets(top: 24, leading: 0, bottom: 21, trailing: 62),
                                   handedness: .leftHanded)
        XCTAssertEqual(layout.frame(at: 0).maxX, 475.5)
        XCTAssertEqual(layout.frame(at: 1).minX, 475.5)
        XCTAssertEqual(layout.insets(at: 0).leading, 12)
        XCTAssertEqual(layout.insets(at: 1).trailing, 62)
        XCTAssertEqual(layout.insets(at: 0).trailing, 16)
        XCTAssertEqual(layout.insets(at: 1).leading, 16)
        for index in 0...1 {
            XCTAssertEqual(layout.insets(at: index).top, 24)
            XCTAssertEqual(layout.insets(at: index).bottom, 21)
        }
        XCTAssertEqual(layout.pages, [.touch, .exploration])
    }
}
