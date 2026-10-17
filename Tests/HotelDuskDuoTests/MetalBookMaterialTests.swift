import XCTest
import Metal
import ImageIO
@testable import HotelDuskDuoKit

final class MetalBookMaterialTests: XCTestCase {
    func testActualMetalPaperAndHingePasses() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal device unavailable") }
        let pipeline = try MetalPaperPipeline.shared.get()
        let stock = try pipeline.snapshot(width: 384, height: 512, parameters: MetalPaperParameters())
        let repeated = try pipeline.snapshot(width: 384, height: 512, parameters: MetalPaperParameters())
        let stockBytes = try pixels(stock)
        XCTAssertEqual(stockBytes, try pixels(repeated), "Paper grain must not shimmer across frames")
        for offset in stride(from: 3, to: stockBytes.count, by: 4) { XCTAssertEqual(stockBytes[offset], 255) }
        let resting = try pipeline.snapshot(width: 384, height: 512,
                                           parameters: MetalPaperParameters(pass: 1, angle: 180))
        let flexed = try pipeline.snapshot(width: 384, height: 512,
                                          parameters: MetalPaperParameters(pass: 1, angle: 65, flex: 0.6))
        XCTAssertNotEqual(try pixels(resting), try pixels(flexed), "Physical hinge and settling must reach the shader")
        let spine = try pipeline.snapshot(width: 100, height: 512,
                                         parameters: MetalPaperParameters(pass: 2, angle: 65))
        let spineBytes = try pixels(spine)
        XCTAssertGreaterThan(spineBytes[(256*100+50)*4+3], spineBytes[(256*100)*4+3])
        for (name,image) in [("metal_paper",stock),("metal_light_open",resting),
                             ("metal_light_settling",flexed),("metal_spine",spine)] {
            try export(image, name: name)
        }
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width*4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0,y: 0,width: image.width,height: image.height))
        let pointer = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: pointer,count: image.width*image.height*4))
    }

    private func export(_ image: CGImage, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name+".png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil))
        CGImageDestinationAddImage(destination,image,nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
