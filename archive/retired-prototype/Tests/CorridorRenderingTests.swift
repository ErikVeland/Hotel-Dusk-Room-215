import XCTest
import SceneKit
import Metal
import ImageIO
@testable import HotelDuskDuoKit

@MainActor
final class CorridorRenderingTests: XCTestCase {
    func testRenderedCorridorHasNoWhiteOpenings() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("A Metal device is required to inspect corridor rendering.")
        }
        let manager = HotelScene3DManager()
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = manager.scene
        renderer.pointOfView = manager.cameraNode
        renderer.autoenablesDefaultLighting = false
        let size = CGSize(width: 480, height: 640)
        let poses: [(String, CGFloat, CGFloat)] = [
            ("forward", 0, 0),
            ("backward", 0, .pi),
            ("left_wall", -3, .pi / 2),
            ("right_wall", -3, -.pi / 2),
            ("far_end", -13.5, 0),
            ("near_end", 1.5, .pi)
        ]
        var brightestRenderedChannel: UInt8 = 0
        for (name, z, yaw) in poses {
            manager.cameraNode.position = SCNVector3(0, 1.5, HotelScene3DManager.SCNScalar(z))
            manager.cameraNode.eulerAngles = SCNVector3(0, HotelScene3DManager.SCNScalar(yaw), 0)
            let snapshot = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .none)
            #if os(macOS)
            let image = try XCTUnwrap(snapshot.cgImage(forProposedRect: nil, context: nil, hints: nil), name)
            #else
            let image = try XCTUnwrap(snapshot.cgImage, name)
            #endif
            let result = try inspectPixels(image)
            brightestRenderedChannel = max(brightestRenderedChannel, result.brightestChannel)
            // Ignore isolated antialiasing or specular pixels. An exposed render
            // surface forms one large white area instead of a few small glints.
            XCTAssertLessThan(result.largestWhiteArea, image.width * image.height / 2_000,
                              "White opening in corridor_\(name)")
            XCTAssertEqual(result.transparentPixels, 0, "Uncovered render surface in corridor_\(name)")
            try export(image, name: "corridor_\(name)")
        }
        // A blank black capture must not pass the missing-geometry check.
        XCTAssertGreaterThan(brightestRenderedChannel, 24, "SceneKit did not render visible corridor geometry.")
    }

    func testCorridorEndsAreOpaqueAndCameraCannotLeaveThem() throws {
        let manager = HotelScene3DManager()
        let root = manager.scene.rootNode
        let nearWall = try XCTUnwrap(root.childNode(withName: "corridor-near-wall", recursively: false))
        let farWall = try XCTUnwrap(root.childNode(withName: "corridor-far-wall", recursively: false))
        let background = try XCTUnwrap(manager.scene.background.contents as? PlatformColor)
        #if os(macOS)
        let rgb = try XCTUnwrap(background.usingColorSpace(.deviceRGB))
        XCTAssertLessThan(max(rgb.redComponent, rgb.greenComponent, rgb.blueComponent), 0.1)
        XCTAssertEqual(rgb.alphaComponent, 1)
        #else
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(background.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertLessThan(max(red, green, blue), 0.1)
        XCTAssertEqual(alpha, 1)
        #endif

        for wall in [nearWall, farWall] {
            let geometry = try XCTUnwrap(wall.geometry as? SCNBox)
            XCTAssertGreaterThanOrEqual(geometry.width, 3.6)
            XCTAssertGreaterThanOrEqual(geometry.height, 2.8)
            XCTAssertEqual(geometry.firstMaterial?.transparency, 1)
        }

        manager.panCamera(deltaYaw: 0, deltaZ: 1_000)
        XCTAssertLessThan(manager.cameraNode.position.z, nearWall.position.z - 0.1)
        manager.panCamera(deltaYaw: 0, deltaZ: -2_000)
        XCTAssertGreaterThan(manager.cameraNode.position.z, farWall.position.z + 0.1)

        // Turning around must also keep the camera within the same closed shell.
        manager.panCamera(deltaYaw: .pi, deltaZ: -2_000)
        XCTAssertLessThan(manager.cameraNode.position.z, nearWall.position.z - 0.1)
        XCTAssertGreaterThan(manager.cameraNode.position.z, farWall.position.z + 0.1)
    }

    private func inspectPixels(_ image: CGImage) throws ->
        (largestWhiteArea: Int, transparentPixels: Int, brightestChannel: UInt8) {
        let width = image.width
        let height = image.height
        let count = width * height
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                                              bitsPerComponent: 8, bytesPerRow: width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                                                CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        var white = [UInt8](repeating: 0, count: count)
        var transparentPixels = 0
        var brightestChannel: UInt8 = 0
        for index in 0..<count {
            let offset = index * 4
            brightestChannel = max(brightestChannel, pixels[offset], pixels[offset + 1], pixels[offset + 2])
            if pixels[offset + 3] < 250 { transparentPixels += 1 }
            if min(pixels[offset], pixels[offset + 1], pixels[offset + 2]) >= 245 {
                white[index] = 1
            }
        }
        var largestWhiteArea = 0
        var queue: [Int] = []
        for start in 0..<count where white[start] == 1 {
            queue.removeAll(keepingCapacity: true)
            queue.append(start)
            white[start] = 0
            var cursor = 0
            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1
                let x = index % width
                let neighbors = [x > 0 ? index - 1 : -1,
                                 x + 1 < width ? index + 1 : -1,
                                 index >= width ? index - width : -1,
                                 index + width < count ? index + width : -1]
                for neighbor in neighbors where neighbor >= 0 && white[neighbor] == 1 {
                    white[neighbor] = 0
                    queue.append(neighbor)
                }
            }
            largestWhiteArea = max(largestWhiteArea, queue.count)
        }
        return (largestWhiteArea, transparentPixels, brightestChannel)
    }

    private func export(_ image: CGImage, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
