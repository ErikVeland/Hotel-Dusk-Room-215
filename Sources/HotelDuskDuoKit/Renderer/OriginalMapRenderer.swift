import CoreGraphics
import Metal

/**
 * Draws the recovered lobby and counter through the existing native model renderer.
 */
@MainActor
final class OriginalMapRenderer {
    let map: CGImage
    private let room: OriginalModelMetalPreview
    private let counter: OriginalModelMetalPreview

    init(mapName: String = "R102", searchArea: UInt16? = nil) throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw OriginalDataError.missing("Metal device") }
        let models = try OriginalModelLibrary.bundled(), textures = try OriginalTextureLibrary.bundled()
        room = try OriginalModelMetalPreview(modelPath: "map/\(mapName)/\(mapName)/\(mapName).mdf", models: models, textures: textures, device: device)
        let area = String(format: "%02d", searchArea ?? (mapName == "R205" ? 1 : 2))
        counter = try OriginalModelMetalPreview(modelPath: "map/\(mapName)/\(mapName)_s\(area)/\(mapName)_s\(area).mdf", models: models, textures: textures, device: device)
        guard let image = try OriginalBitmapLibrary.bundled().loadMap(path: "map/fmapscr/\(mapName).bin").makeCGImage() else {
            throw OriginalDataError.invalid("Lobby map image")
        }
        map = image
    }

    func render(_ state: OriginalMapExploration, game: OriginalGameState) throws -> CGImage {
        let scene = state.mode == .walking ? room : counter
        let visible = state.objectVisibility.visibleNodes(in: scene.model, map: state.mapID,
            area: state.mode == .walking ? nil : state.searchAreaID, game: game)
            .intersection(scene.model.gameplayRenderNodes)
        return try scene.render(width: 192, height: 256, viewProjection: state.viewProjection,
            visibleNodes: visible)
    }
}
