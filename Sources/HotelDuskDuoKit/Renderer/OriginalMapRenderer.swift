import CoreGraphics
import Metal

/**
 * Draws the recovered lobby and counter through the existing native model renderer.
 */
@MainActor
final class OriginalMapRenderer {
    let map: CGImage
    private let room: OriginalModelMetalPreview
    private var counter: OriginalModelMetalPreview?
    private let mapName: String
    private let initialSearchArea: UInt16?

    init(mapName: String = "R102", searchArea: UInt16? = nil) throws {
        self.mapName = mapName
        initialSearchArea = searchArea
        guard let device = MTLCreateSystemDefaultDevice() else { throw OriginalDataError.missing("Metal device") }
        let models = try OriginalModelLibrary.bundled(), textures = try OriginalTextureLibrary.bundled()
        room = try OriginalModelMetalPreview(modelPath: "map/\(mapName)/\(mapName)/\(mapName).mdf", models: models, textures: textures, device: device, gameplayOnly: true)
        guard let image = try OriginalBitmapLibrary.bundled().loadMap(path: "map/fmapscr/\(mapName).bin").makeCGImage() else {
            throw OriginalDataError.invalid("Lobby map image")
        }
        map = image
    }

    func render(_ state: OriginalMapExploration, game: OriginalGameState) throws -> CGImage {
        let scene: OriginalModelMetalPreview
        if state.mode == .walking { scene = room }
        else {
            if counter == nil {
                guard let device = MTLCreateSystemDefaultDevice() else { throw OriginalDataError.missing("Metal device") }
                let area = String(format: "%02d", initialSearchArea ?? state.searchAreaID)
                counter = try OriginalModelMetalPreview(modelPath: "map/\(mapName)/\(mapName)_s\(area)/\(mapName)_s\(area).mdf",
                    models: .bundled(), textures: .bundled(), device: device, gameplayOnly: true)
            }
            guard let counter else { throw OriginalDataError.missing("Search scene") }
            scene = counter
        }
        let visible = state.objectVisibility.visibleNodes(in: scene.model, map: state.mapID,
            area: state.mode == .walking ? nil : state.searchAreaID, game: game)
            .intersection(scene.model.gameplayRenderNodes)
        return try scene.render(width: 192, height: 256, viewProjection: state.viewProjection,
            visibleNodes: visible)
    }
}
