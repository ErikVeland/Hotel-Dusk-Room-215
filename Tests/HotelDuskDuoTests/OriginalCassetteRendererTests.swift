import Foundation
import ImageIO
import Metal
import XCTest
@testable import HotelDuskDuoKit

final class OriginalCassetteRendererTests: XCTestCase {
    @MainActor func testCassetteSceneRendersFromBundledResources() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        try exportSourceTexturesIfRequested()
        let image = try OriginalCassetteRenderer(tool: .pencil).render()
        XCTAssertEqual(image.width, 192)
        XCTAssertEqual(image.height, 256)
        let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertGreaterThan(Set(pixels).count, 16)
        if let output = ProcessInfo.processInfo.environment["HOTEL_DUSK_CASSETTE_PREVIEW"] {
            let url = URL(fileURLWithPath: output)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }

    @MainActor func testCassetteInteractionMasksFollowRenderedMeshes() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        let renderer = try OriginalCassetteRenderer(tool: .pencil)
        for object in [OriginalCassetteRenderer.MaskedObject.tape, .tool] {
            let mask = try renderer.hitMask(for: object)
            XCTAssertGreaterThan(mask.triangleCount, 0)
            XCTAssertGreaterThan(mask.bounds.width, 0)
            XCTAssertGreaterThan(mask.bounds.height, 0)
        }
    }

    @MainActor func testCassetteHitTestingUsesNearestProjectedObjectMask() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        let renderer = try OriginalCassetteRenderer(tool: .pencil)
        let tape = try renderer.hitMask(for: .tape)
        let tool = try renderer.hitMask(for: .tool)
        var checkedPoints = 0

        for y in stride(from: 0, to: 192, by: 4) {
            for x in stride(from: 0, to: 256, by: 4) {
                let sourcePoint = SIMD2(Float(x), Float(y))
                let tapeDepth = tape.depth(at: sourcePoint, padding: 2)
                let toolDepth = tool.depth(at: sourcePoint, padding: 2)
                guard tapeDepth != nil || toolDepth != nil else { continue }
                let expected: OriginalCassetteRenderer.MaskedObject
                if let tapeDepth, let toolDepth {
                    expected = tapeDepth <= toolDepth ? .tape : .tool
                } else {
                    expected = tapeDepth == nil ? .tool : .tape
                }

                XCTAssertEqual(try renderer.hitTest(
                    pagePoint: SIMD2(Float(y), Float(255 - x))), expected)
                checkedPoints += 1
            }
        }

        XCTAssertGreaterThan(checkedPoints, 0)
    }

    private func exportSourceTexturesIfRequested() throws {
        guard let output = ProcessInfo.processInfo.environment["HOTEL_DUSK_CASSETTE_TEXTURES"] else { return }
        let directory = URL(fileURLWithPath: output, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bitmaps = try OriginalBitmapLibrary.bundled()
        for name in ["bg", "table"] {
            let texture = try bitmaps.loadTexture(path: "trick/cassette/\(name).bin")
            let image = try XCTUnwrap(texture.makeCGImage())
            let url = directory.appendingPathComponent("\(name).png")
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }
}
