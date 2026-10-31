import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import XCTest
@testable import HotelDuskDuoKit

final class PencilCharacterRenderingTests: XCTestCase {
    @MainActor
    func testDefaultPencilWhitesRevealPaperAndPreserveSoftShading() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let frame = OriginalAnimationFrame(width: 3, height: 1, frameIndex: 0,
            rgba: Data([255, 255, 255, 255, 128, 128, 128, 255, 0, 0, 0, 0]),
            originalIndexData: Data(), originalPaletteData: Data())
        let view = ZStack {
            Color(red: 0.8, green: 0.7, blue: 0.5)
            OriginalAnimationFrameView(frame: frame)
        }.frame(width: 90, height: 30).defaultAppStorage(defaults)
        let renderer = ImageRenderer(content: view)
        let image = try XCTUnwrap(renderer.cgImage)
        let renderedPixels = try pixels(image)
        func rgb(_ x: Int) -> [Int] {
            let offset = (15 * image.width + x) * 4
            return renderedPixels[offset..<offset + 3].map(Int.init)
        }
        let paper = rgb(75)
        let white = rgb(15)
        let graphite = rgb(45)
        for channel in 0..<3 {
            XCTAssertEqual(white[channel], paper[channel], accuracy: 2,
                "White character fill must reveal the unchanged paper")
            XCTAssertLessThan(graphite[channel], paper[channel] - 25)
            XCTAssertGreaterThan(graphite[channel], 25, "Soft shading must not be crushed to black")
        }
        let faded = ZStack {
            Color(red: 0.8, green: 0.7, blue: 0.5)
            OriginalAnimationFrameView(frame: frame).opacity(0.42)
        }.frame(width: 90, height: 30).defaultAppStorage(defaults)
        let fadedImage = try XCTUnwrap(ImageRenderer(content: faded).cgImage)
        let fadedPixels = try pixels(fadedImage)
        for channel in 0..<3 {
            XCTAssertEqual(Int(fadedPixels[(15 * fadedImage.width + 15) * 4 + channel]), paper[channel], accuracy: 2,
                "Dialogue portrait opacity must not isolate the Multiply blend from the page")
        }
        defaults.set(false, forKey: "pencilCharacterAnimations")
        let original = try XCTUnwrap(ImageRenderer(content: view).cgImage)
        let originalPixels = try pixels(original)
        let whiteOffset = (15 * original.width + 15) * 4
        XCTAssertGreaterThan(originalPixels[whiteOffset], 250)
    }

    @MainActor
    func testCharacterComparisonOnBookPaper() throws {
        guard let folder = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        let library = try OriginalAnimationLibrary.bundled()
        let original = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        original.set(false, forKey: "pencilCharacterAnimations")
        let pencil = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        pencil.set(true, forKey: "pencilCharacterAnimations")
        for id in ["Hy_hanas_", "Dn_mae_"] {
            var decoder = OriginalAnimationDecoder(clip: try library.load(id: id))
            let frame = try XCTUnwrap(decoder.advance())
            let view = HStack(spacing: 0) {
                comparison(frame: frame, label: "Original", defaults: original)
                comparison(frame: frame, label: "Pencil on paper", defaults: pencil)
            }
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.cgImage)
            let url = URL(fileURLWithPath: folder).appendingPathComponent("pencil-\(id).png")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }

    @MainActor
    private func comparison(frame: OriginalAnimationFrame, label: String, defaults: UserDefaults) -> some View {
        ZStack {
            PaperSurface()
            VStack(spacing: 16) {
                Text(label).font(.system(size: 18, design: .serif)).foregroundStyle(NovelStyle.ink)
                OriginalAnimationFrameView(frame: frame).frame(width: 288, height: 384)
            }
        }.frame(width: 336, height: 464).defaultAppStorage(defaults)
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }
}
