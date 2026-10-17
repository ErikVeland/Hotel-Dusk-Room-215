import XCTest
import SwiftUI
#if os(macOS)
import AppKit
#endif
@testable import HotelDuskDuoKit

/// Renders the container at iPhone Duo inner-display sizes so the open layouts
/// can be checked without unfolding a simulator. Set SNAPSHOT_DIR to write PNGs.
@MainActor
final class LayoutSnapshotTests: XCTestCase {
    func testRenderInnerDisplayLayouts() throws {
        let cases: [(String, CGSize, Double, Handedness, DynamicTypeSize)] = [
            ("book_landscape", CGSize(width: 951, height: 669), 180, .rightHanded, .large),
            ("book_portrait", CGSize(width: 669, height: 951), 180, .rightHanded, .large),
            ("partly_open_book", CGSize(width: 951, height: 669), 110, .rightHanded, .large),
            ("book_left_handed", CGSize(width: 951, height: 669), 180, .leftHanded, .large),
            ("book_large_text", CGSize(width: 951, height: 669), 180, .rightHanded, .accessibility1),
            ("native_recovery", CGSize(width: 951, height: 669), 180, .rightHanded, .large),
            ("novel_notebook", CGSize(width: 951, height: 669), 180, .rightHanded, .large),
        ]
        for (name, size, angle, handedness, typeSize) in cases {
            let session = GameSession()
            if name == "novel_notebook" { session.isMemoPadOpen = true }
            session.hingeManager.setHingeAngle(angle)
            session.hingeManager.handedness = handedness
            let view = DuoBookContainerView(session: session)
                .environment(\.dynamicTypeSize, typeSize)
                .frame(width: size.width, height: size.height)
            let image = try capture(view, size: size, name: name)
            try assertPaperAtOuterEdges(image)
        }
    }

    func testRenderOriginalJigsawAssemblyAndFoldSequence() throws {
        let size = CGSize(width: 951, height: 669)
        let coverSize = CGSize(width: 420, height: 630)
        let manifest = JigsawManifest.bundled
        XCTAssertEqual(manifest.boardWidth, 192)
        XCTAssertEqual(manifest.boardHeight, 256)
        XCTAssertEqual(manifest.pieces.count, 20)
        for name in [manifest.frontImage, manifest.reverseImage, manifest.tableImage,
                     manifest.trayImage, manifest.foldTrayImage] {
            let image = try XCTUnwrap(JigsawArt.image(named: name), name)
            XCTAssertEqual(image.width, 192)
            XCTAssertEqual(image.height, 256)
        }
        for piece in manifest.pieces {
            XCTAssertNotNil(JigsawArt.image(named: piece.image), piece.image)
        }
        XCTAssertNotNil(JigsawArt.image(named: manifest.rotateLeftImage))
        XCTAssertNotNil(JigsawArt.image(named: manifest.rotateRightImage))

        for hand in Handedness.allCases {
            let suffix = hand == .rightHanded ? "right" : "left"
            let session = GameSession(hingeManager: DuoHingeManager(initialHandedness: hand))
            session.isJigsawPuzzleOpen = true
            let assembly = DuoBookContainerView(session: session).frame(width: size.width, height: size.height)
            try assertPaperAtOuterEdges(capture(assembly, size: size, name: "jigsaw_\(suffix)_assembly"))

            assemble(session.jigsawPuzzleManager)
            XCTAssertEqual(session.jigsawPuzzleManager.phase, .assembled)
            let front = DuoBookContainerView(session: session).frame(width: size.width, height: size.height)
            try assertPaperAtOuterEdges(capture(front, size: size, name: "jigsaw_\(suffix)_assembled"))

            session.hingeManager.receiveHardwareState(.closed, angleDegrees: 0)
            XCTAssertEqual(session.jigsawPuzzleManager.phase, .folded)
            let closed = DuoBookContainerView(session: session).frame(width: coverSize.width, height: coverSize.height)
            _ = try capture(closed, size: coverSize, name: "jigsaw_\(suffix)_closed_cover")

            session.hingeManager.receiveHardwareState(.partiallyOpen, angleDegrees: 45)
            XCTAssertEqual(session.jigsawPuzzleManager.phase, .reverseRevealed)
            let reopened = DuoBookContainerView(session: session).frame(width: size.width, height: size.height)
            try assertPaperAtOuterEdges(capture(reopened, size: size, name: "jigsaw_\(suffix)_revealed_45"))
        }
    }

    func testRenderJigsawWithAsymmetricSafeAreas() throws {
        let size = CGSize(width: 951, height: 669)
        for hand in Handedness.allCases {
            let session = GameSession(hingeManager: DuoHingeManager(initialHandedness: hand))
            session.isJigsawPuzzleOpen = true
            let view = ZStack {
                JigsawPuzzleView(session: session, puzzleManager: session.jigsawPuzzleManager,
                                 safeArea: EdgeInsets(top: 24, leading: 10, bottom: 34, trailing: 62))
                BookSpineView(angleDegrees: 90)
            }
            .frame(width: size.width, height: size.height)
            let suffix = hand == .rightHanded ? "right" : "left"
            let image = try capture(view, size: size, name: "jigsaw_\(suffix)_safe_areas")
            try assertPaperAtOuterEdges(image)
        }
    }

    func testRenderSpineAcrossOpeningAngles() throws {
        let size = CGSize(width: 951, height: 669)
        for angle in [30.0, 90, 180] {
            let session = GameSession()
            session.hingeManager.receiveHardwareAngle(angle)
            let view = DuoBookContainerView(session: session).frame(width: size.width, height: size.height)
            let image = try capture(view, size: size, name: "book_spine_\(Int(angle))")
            try assertPaperAtOuterEdges(image)
        }
    }

    func testRenderPaperbackOnCoverDisplays() throws {
        let image = try XCTUnwrap(PaperbackCoverArt.image)
        XCTAssertEqual(image.width, 1024)
        XCTAssertEqual(image.height, 1536)
        for (name, size) in [("paperback_cover", CGSize(width: 420, height: 630)),
                             ("paperback_cover_tall", CGSize(width: 390, height: 844)),
                             ("paperback_cover_rotated", CGSize(width: 680, height: 420))] {
            let session = GameSession()
            session.hingeManager.receiveHardwareAngle(0)
            let view = DuoBookContainerView(session: session).frame(width: size.width, height: size.height)
            _ = try capture(view, size: size, name: name)
        }
    }

    func testRenderPaperMaterialAtRestAndWhileSettling() throws {
        let size = CGSize(width: 951, height: 669)
        for (name, flex) in [("paper_stock_rest", 0.0), ("paper_stock_settling", 0.4)] {
            let view = HStack(spacing: 0) {
                ForEach(0..<2) { index in
                    let side: PaperPageSide = index == 0 ? .left : .right
                    ZStack {
                        PaperSurface(side: side)
                        PaperCurvatureLight(side: side, hingeAngle: 90, flex: index == 0 ? flex : -flex)
                    }
                    .frame(width: size.width / 2, height: size.height)
                }
            }
            .overlay { BookSpineView(angleDegrees: 90) }
            .frame(width: size.width, height: size.height)
            try assertPaperAtOuterEdges(capture(view, size: size, name: name))
        }
    }

    private func assemble(_ puzzle: JigsawPuzzleManager) {
        for piece in puzzle.manifest.pieces {
            puzzle.movePiece(piece.id, to: piece.centre)
            for _ in 0..<4 {
                if puzzle.placements[piece.id]?.quarterTurns == 0 { break }
                puzzle.rotatePiece(piece.id)
            }
            XCTAssertTrue(puzzle.releasePiece(piece.id))
        }
    }

    @discardableResult
    private func capture<V: View>(_ view: V, size: CGSize, name: String) throws -> CGImage {
        let image = try snapshot(view, size: size, name: name)
        XCTAssertEqual(image.width, Int(size.width))
        XCTAssertEqual(image.height, Int(size.height))
        if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            let directory = URL(fileURLWithPath: dir)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("\(name).png")
            let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(dest, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(dest))
        }
        return image
    }

    /// Paper must reach all four corners, even when the content has safe insets.
    private func assertPaperAtOuterEdges(_ image: CGImage, file: StaticString = #filePath, line: UInt = #line) throws {
        let right = CGFloat(image.width - 3)
        let bottom = CGFloat(image.height - 3)
        let points = [CGPoint(x: 2, y: 2), CGPoint(x: right, y: 2),
                      CGPoint(x: 2, y: bottom), CGPoint(x: right, y: bottom)]
        for point in points {
            let sample = try XCTUnwrap(image.cropping(to: CGRect(origin: point, size: CGSize(width: 1, height: 1))))
            let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                                  space: CGColorSpaceCreateDeviceRGB(),
                                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            let rgba = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
            XCTAssertGreaterThan(rgba[0], 180, "Missing paper at \(point)", file: file, line: line)
            XCTAssertGreaterThan(rgba[1], 160, "Missing paper at \(point)", file: file, line: line)
            XCTAssertGreaterThan(rgba[2], 140, "Missing paper at \(point)", file: file, line: line)
            XCTAssertEqual(rgba[3], 255, file: file, line: line)
        }
    }

    private func snapshot<V: View>(_ view: V, size: CGSize, name: String) throws -> CGImage {
        #if os(macOS)
        // ImageRenderer omits AppKit-backed scroll content. Host a real view so
        // previews include the dialogue, inventory and navigation rows.
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds), name)
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let image = try XCTUnwrap(bitmap.cgImage, name)
        // Native capture uses the Mac display's backing scale. Export at 1× so
        // fixture dimensions are independent of the machine running the tests.
        let context = try XCTUnwrap(CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                              bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return try XCTUnwrap(context.makeImage(), name)
        #else
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try XCTUnwrap(renderer.cgImage, name)
        #endif
    }
}
