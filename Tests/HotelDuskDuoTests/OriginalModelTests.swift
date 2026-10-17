import CryptoKit
import Foundation
import XCTest
@testable import HotelDuskDuoKit

final class OriginalModelTests: XCTestCase {
    private func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func testEveryRecoveredModelMatchesIndependentPythonDecoder() throws {
        let library = try OriginalModelLibrary.bundled()
        XCTAssertEqual(library.manifest.coverage.models, 296)
        XCTAssertEqual(library.manifest.coverage.decoded, 235)
        XCTAssertEqual(library.manifest.coverage.unsupported, 61)
        var vertices = 0, hitVertices = 0, nodes = 0
        for record in library.manifest.models where record.status == "decoded" {
            let model = try library.load(path: record.source)
            XCTAssertEqual(sha(model.decodedPayload), record.decodedSHA256, record.source)
            XCTAssertEqual(sha(model.geometryData), record.geometrySHA256, record.source)
            let expected = try XCTUnwrap(record.nodes)
            XCTAssertEqual(model.nodes.count, expected.count, record.source)
            for (node, reference) in zip(model.nodes, expected) {
                XCTAssertEqual(node.name, reference.name, record.source)
                XCTAssertEqual(node.parent, reference.parent, record.source)
                XCTAssertEqual(node.localFixed, reference.localFixed, record.source)
                XCTAssertEqual(node.worldFixed, reference.worldFixed, record.source)
            }
            vertices += model.groups.reduce(0) { $0 + ($1.render?.vertexCount ?? 0) }
            hitVertices += model.groups.reduce(0) { $0 + ($1.hit?.vertexCount ?? 0) }
            nodes += model.nodes.count
        }
        XCTAssertEqual(vertices, 621884)
        XCTAssertEqual(hitVertices, 594401)
        XCTAssertEqual(nodes, 7123)
    }

    func testOriginalRoomRetainsInteractionNodesAndSeparateHitGeometry() throws {
        let model = try OriginalModelLibrary.bundled().load(path: "map/R212/R212/R212.mdf")
        XCTAssertTrue(model.nodes.contains { $0.name == "in_r213" })
        XCTAssertTrue(model.nodes.contains { $0.name == "hyde_point00" })
        XCTAssertTrue(model.nodes.contains { $0.name == "search01" })
        XCTAssertTrue(model.groups.contains { $0.render != nil && $0.hit != nil })
        XCTAssertEqual(model.materials.count, 68)
        XCTAssertThrowsError(try model.cameraMarkers(index: 1))
        let search = try OriginalModelLibrary.bundled().load(path: "map/R102/R102_s01/R102_s01.mdf")
        let camera = try search.cameraMarkers(index: 1)
        XCTAssertEqual(camera.positionFixed, [-6136, 10969, -582])
        XCTAssertEqual(camera.targetFixed, [-21250, 8603, 8512])
        XCTAssertEqual(try search.cameraMarkers(index: 2).targetFixed, camera.targetFixed)
    }

    func testUnsupportedVariantsAndMalformedCommandsFailExplicitly() throws {
        let library = try OriginalModelLibrary.bundled()
        for record in library.manifest.models where record.status == "unsupported" {
            XCTAssertThrowsError(try library.load(path: record.source), record.source)
        }
        XCTAssertThrowsError(try OriginalModel(data: Data(repeating: 0, count: 48)))
        XCTAssertThrowsError(try OriginalModelGeometry(data: Data([0x23, 0, 0, 0]), textured: true))
        XCTAssertThrowsError(try OriginalModelGeometry(data: Data([0x41, 0, 0, 0]), textured: true))
    }
}
