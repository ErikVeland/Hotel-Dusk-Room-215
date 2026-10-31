import CoreGraphics
import simd
import XCTest
@testable import HotelDuskDuoKit

@MainActor
func originalRouteTestAudio() -> AudioController {
    let audio = AudioController(musicOutputFactory: { _, _, _ in ProgressMusicOutput() })
    audio.isMuted = true
    _ = try? audio.applyOriginalCommand(.disableNewEffects(true))
    return audio
}

@MainActor
final class OriginalRouteBitmapMapRenderer: OriginalMapRendering {
    let map: CGImage

    init(mapName: String) throws {
        guard let image = try OriginalBitmapLibrary.bundled()
            .loadMap(path: "map/fmapscr/\(mapName).bin").makeCGImage() else {
            throw OriginalDataError.invalid("Route map image")
        }
        map = image
    }

    func render(_ state: OriginalMapExploration, game: OriginalGameState) throws -> CGImage { map }
}

@MainActor
final class OriginalRouteBitmapToiletTankRenderer: OriginalToiletTankRendering {
    private let image: CGImage

    init() throws {
        guard let image = try OriginalBitmapLibrary.bundled()
            .loadMap(path: "map/fmapscr/R205.bin").makeCGImage() else {
            throw OriginalDataError.invalid("Route toilet-tank image")
        }
        self.image = image
    }

    func render(_ puzzle: OriginalToiletTankProcess) throws -> CGImage { image }
}

@MainActor
final class OriginalRouteBitmapSuitcaseContentsRenderer: OriginalSuitcaseContentsRendering {
    let initialContents: OriginalSuitcaseContents
    private let image: CGImage

    init() throws {
        let bitmaps = try OriginalBitmapLibrary.bundled()
        let masks = try OriginalSuitcaseContents.lowerObjects.map { object in
            try bitmaps.loadTexture(path: "trick/searchbag/\(object.texture).bin").originalPixelData
        }
        initialContents = try OriginalSuitcaseContents(lowerHitMasks: masks)
        guard let image = try bitmaps.loadMap(path: "map/fmapscr/R205.bin").makeCGImage() else {
            throw OriginalDataError.invalid("Route suitcase image")
        }
        self.image = image
    }

    func render(_ process: OriginalSuitcaseContentsProcess, game: OriginalGameState) throws -> CGImage { image }
}

@MainActor
final class OriginalRouteBitmapBagSearchRenderer: OriginalBagSearchRendering {
    private let projection: OriginalBagSearchProjection
    private let image: CGImage

    init() throws {
        let library = try OriginalModelLibrary.bundled()
        let model = try library.load(path: "trick/searchshed/soko.mdf")
        projection = try OriginalBagSearchProjection(models: [model])
        guard let image = CGContext(data: nil, width: 192, height: 256, bitsPerComponent: 8,
            bytesPerRow: 192 * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage() else {
            throw OriginalDataError.invalid("Route bag-search image")
        }
        self.image = image
    }

    func render(_ process: OriginalBagSearchProcess) throws -> CGImage { image }
    func object(at point: SIMD2<Float>, process: OriginalBagSearchProcess) throws -> Int? {
        try projection.object(at: point, process: process)
    }
    func planePointFixed(at point: SIMD2<Float>) -> SIMD2<Int32>? {
        projection.planePointFixed(at: point)
    }
}
