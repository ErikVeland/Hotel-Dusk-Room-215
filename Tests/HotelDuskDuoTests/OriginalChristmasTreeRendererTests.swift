import XCTest
@testable import HotelDuskDuoKit

final class OriginalChristmasTreeRendererTests: XCTestCase {
    @MainActor func testEveryTrayDecorationCanBePickedFromItsVisibleAlphaMask() throws {
        let renderer = try OriginalChristmasTreeRenderer(library: .bundled())
        var process = OriginalChristmasTreeProcess()
        _ = process.update()

        for slot in 0..<10 {
            let decoration = process.decorationOrder[slot]
            XCTAssertNotNil(pickPoint(decoration, in: slot, renderer: renderer, process: process),
                            "Decoration \(decoration) needs a touchable visible pixel")
        }

        XCTAssertNil(pickPoint(10, in: 10, renderer: renderer, process: process))
        for decoration in 0..<10 {
            _ = process.dropDecoration(decoration,
                                       at: OriginalChristmasTreeLayout.modelDecorationTargets[decoration])
        }
        XCTAssertNotNil(pickPoint(10, in: 10, renderer: renderer, process: process),
                        "The star needs a touchable pixel after the decorations are placed")
        XCTAssertNil(renderer.decoration(at: SIMD2(0, 0), process: process))
    }

    @MainActor private func pickPoint(_ decoration: Int, in slot: Int,
                                     renderer: OriginalChristmasTreeRenderer,
                                     process: OriginalChristmasTreeProcess) -> SIMD2<Float>? {
        let centreX = 9 + slot * 17
        for y in 232...248 {
            for x in (centreX - 8)...(centreX + 8) {
                let point = SIMD2(Float(x), Float(y))
                if renderer.decoration(at: point, process: process) == decoration { return point }
            }
        }
        return nil
    }
}
