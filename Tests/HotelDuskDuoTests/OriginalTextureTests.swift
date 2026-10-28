import CryptoKit
import Foundation
import XCTest
@testable import HotelDuskDuoKit

final class OriginalTextureTests: XCTestCase {
    private func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func testEveryRecoveredTextureMatchesIndependentPythonDecoder() throws {
        let library = try OriginalTextureLibrary.bundled()
        XCTAssertEqual(library.manifest.coverage.textures, 2957)
        XCTAssertEqual(library.manifest.coverage.decoded, 2952)
        XCTAssertEqual(library.manifest.coverage.unsupported, 5)
        var checked = 0
        for record in library.manifest.textures where record.status == "decoded" {
            let texture = try library.load(path: record.source)
            XCTAssertEqual(texture.mode, record.mode, record.source)
            XCTAssertEqual(texture.storedWidth, record.storedWidth, record.source)
            XCTAssertEqual(texture.storedHeight, record.storedHeight, record.source)
            XCTAssertEqual(sha(texture.decodedPayload), record.decodedSHA256, record.source)
            XCTAssertEqual(sha(texture.originalPaletteData), record.paletteSHA256, record.source)
            XCTAssertEqual(sha(texture.originalPixelData), record.pixelDataSHA256, record.source)
            XCTAssertEqual(sha(texture.rgba), record.rgbaSHA256, record.source)
            checked += 1
        }
        XCTAssertEqual(checked, 2952)
    }

    func testPaddedStorageRetainsOriginalDimensions() throws {
        let texture = try OriginalTextureLibrary.bundled().load(path: "map/R109/R109_s03/r109_paper01.dtx")
        XCTAssertEqual(texture.allocatedWidth, 32)
        XCTAssertEqual(texture.allocatedHeight, 64)
        XCTAssertEqual(texture.logicalWidth, 32)
        XCTAssertEqual(texture.logicalHeight, 44)
        XCTAssertEqual(texture.storedWidth, 32)
        XCTAssertEqual(texture.storedHeight, 64)
        XCTAssertEqual(texture.originalPixelData.count, 2048)
    }

    func testUnknownCompressedCropsDoNotProduceReplacementArt() throws {
        let library = try OriginalTextureLibrary.bundled()
        for record in library.manifest.textures where record.status == "unsupported" {
            XCTAssertThrowsError(try library.load(path: record.source), record.source)
        }
        XCTAssertThrowsError(try OriginalTexture(data: Data(repeating: 0, count: 31)))
    }

    func testChapterSixLabelPeelAssetsDecodeAsOriginalTextures() throws {
        let library = try OriginalBitmapLibrary.bundled()
        for name in ["bottle", "label_01", "label_02", "label_03", "label_04"] {
            let texture = try library.loadTexture(path: "trick/LabelPeel/\(name).bin")
            XCTAssertGreaterThan(texture.logicalWidth, 0, name)
            XCTAssertGreaterThan(texture.logicalHeight, 0, name)
            XCTAssertFalse(texture.rgba.isEmpty, name)
        }
    }

    func testChapterTenPicturePeelAssetsDecodeAsOriginalTextures() throws {
        let library = try OriginalBitmapLibrary.bundled()
        for name in ["bg1", "bg2", "pic", "pic_sample"] {
            let texture = try library.loadTexture(path: "trick/picturepeel/\(name).bin")
            XCTAssertGreaterThan(texture.logicalWidth, 0, name)
            XCTAssertGreaterThan(texture.logicalHeight, 0, name)
            XCTAssertFalse(texture.rgba.isEmpty, name)
        }
    }

    func testChapterTenTypewriterAssetsDecodeAsOriginalTextures() throws {
        let library = try OriginalBitmapLibrary.bundled()
        for name in ["bg_1", "bg_2", "dial"] {
            let texture = try library.loadTexture(path: "trick/typewriter/\(name).bin")
            XCTAssertEqual(texture.storedWidth, name == "dial" ? 1024 : 256, name)
            XCTAssertEqual(texture.storedHeight, name == "dial" ? 32 : 192, name)
            XCTAssertFalse(texture.rgba.isEmpty, name)
        }
    }

    func testChapterTenBrickWallAssetsDecodeAsOriginalTextures() throws {
        let library = try OriginalBitmapLibrary.bundled()
        let expectedDimensions = [
            "bgrenga": (256, 192), "siku": (32, 16), "sita": (32, 16),
            "soku": (32, 16), "soku2": (32, 16), "soku3": (32, 16), "soku4": (32, 16)
        ]

        for (name, expected) in expectedDimensions {
            let texture = try library.loadTexture(path: "trick/brick/\(name).bin")
            XCTAssertEqual(texture.logicalWidth, expected.0, name)
            XCTAssertEqual(texture.logicalHeight, expected.1, name)
            XCTAssertFalse(texture.rgba.isEmpty, name)
        }
    }

    func testChapterTenAfterConfessAssetsDecodeAsOriginalTextures() throws {
        let library = try OriginalBitmapLibrary.bundled()
        let dimensions = [
            "AC_01L": (256, 256), "AC_01R1": (256, 96), "AC_01R2": (128, 256),
            "AC_02L1": (256, 192), "AC_02L2": (128, 128), "AC_02R": (256, 192),
            "AC_03L1": (256, 192), "AC_03L2": (128, 128)
        ]

        for (name, expected) in dimensions {
            let texture = try library.loadTexture(path: "show/AfterConfess/\(name).bin")
            XCTAssertEqual(texture.logicalWidth, expected.0, name)
            XCTAssertEqual(texture.logicalHeight, expected.1, name)
            XCTAssertFalse(texture.rgba.isEmpty, name)
        }
    }

    func testChapterTenVSSceneAssetsDecodeAsOriginalTextures() throws {
        let library = try OriginalBitmapLibrary.bundled()
        let dimensions = [
            "ED02_01": (256, 171), "ED02_02": (256, 480), "ED02_03": (256, 108),
            "ED04_01": (256, 192), "ED04_02": (256, 288), "ED05_01": (256, 256),
            "ED06_1": (256, 192), "ED06_2": (256, 192),
            "ED08_1": (256, 256), "ED08_2": (256, 256),
            "ED08_3": (256, 256), "ED08_4": (256, 256),
            "ED_A_01L": (256, 192), "ED_A_01L1": (256, 256), "ED_A_01L2": (256, 256),
            "ED_A_03L": (256, 192), "ED_A_03R": (256, 192),
            "ED_A_04L": (256, 192), "ED_A_04L2": (256, 192), "ED_A_04R": (256, 192),
            "ED_A_05L": (256, 192), "ED_A_05R": (256, 192), "Reserve": (256, 128)
        ]

        for (name, expected) in dimensions {
            let texture = try library.loadTexture(path: "show/VSScene/\(name).bin")
            XCTAssertEqual(texture.storedWidth, expected.0, name)
            XCTAssertEqual(texture.storedHeight, expected.1, name)
            XCTAssertFalse(texture.rgba.isEmpty, name)
        }
    }

    func testChapterSevenChristmasTreeAssetsDecodeAsOriginalTextures() throws {
        let library = try OriginalBitmapLibrary.bundled()
        let names = ["tree", "tree_s"] + (1...11).map { String(format: "kazari%02d", $0) }
            + (1...4).map { String(format: "hook%02d", $0) }

        for name in names {
            let texture = try library.loadTexture(path: "trick/ChristmasTree/\(name).bin")
            XCTAssertGreaterThan(texture.storedWidth, 0, name)
            XCTAssertGreaterThan(texture.storedHeight, 0, name)
        }
    }

    func testChapterSevenTreeBoxSearchAssetsDecodeAsOriginalTextures() throws {
        let library = try OriginalBitmapLibrary.bundled()
        let names = ["kabe01", "sita", "sita2"] + (0...6).map { String(format: "soku%02d", $0) }
            + ["switch", "tenjoh", "ue", "ue2", "yuka"]

        for name in names {
            let texture = try library.loadTexture(path: "trick/searchshed/\(name).bin")
            XCTAssertGreaterThan(texture.storedWidth, 0, name)
            XCTAssertGreaterThan(texture.storedHeight, 0, name)
            XCTAssertFalse(texture.rgba.isEmpty, name)
        }
    }

    func testLobbyBlockStreamRetainsPartialRowWithoutFillingMissingBlocks() throws {
        let texture = try OriginalTextureLibrary.bundled().load(path: "map/R102/R102/laungr.dtx")
        XCTAssertEqual(texture.logicalHeight, 162)
        XCTAssertEqual(texture.storedHeight, 164)
        XCTAssertEqual(texture.originalPixelData.count / 6, 1296)
        for y in 160..<164 {
            for x in 64..<128 {
                XCTAssertEqual(texture.rgba[(y * 128 + x) * 4 + 3], 0)
            }
        }
    }

    func testLouieRoomCropsRetainSourceBlocksAndTransparentTail() throws {
        let library = try OriginalTextureLibrary.bundled()
        for (asset, width, height, blocks) in [("kanbeer02", 32, 32, 62),
                                               ("r114_kabe01_crop0", 128, 72, 553),
                                               ("radicase", 64, 40, 152)] {
            let texture = try library.load(path: "map/R114/R114/\(asset).dtx")
            XCTAssertEqual(texture.storedWidth, width)
            XCTAssertEqual(texture.storedHeight, height)
            XCTAssertEqual(texture.originalPixelData.count / 6, blocks)
            for block in blocks..<(width * height / 16) {
                let x = (block % (width / 4)) * 4, y = (block / (width / 4)) * 4
                for dy in 0..<4 {
                    for dx in 0..<4 { XCTAssertEqual(texture.rgba[((y + dy) * width + x + dx) * 4 + 3], 0) }
                }
            }
        }
    }
}
