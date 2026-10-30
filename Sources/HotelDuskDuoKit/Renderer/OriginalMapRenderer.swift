import CoreGraphics
import Metal

@MainActor
public protocol OriginalMapRendering: AnyObject {
    var map: CGImage { get }
    func render(_ state: OriginalMapExploration, game: OriginalGameState) throws -> CGImage
}

public typealias OriginalMapRendererFactory = @MainActor (String, UInt16?) throws -> any OriginalMapRendering

/**
 * Draws the recovered lobby and counter through the existing native model renderer.
 */
@MainActor
public final class OriginalMapRenderer: OriginalMapRendering {
    public let map: CGImage
    private let room: OriginalModelMetalPreview
    private var counter: OriginalModelMetalPreview?
    private let mapName: String
    private let initialSearchArea: UInt16?
    private var previousCamera: [Float]?

    public init(mapName: String = "R102", searchArea: UInt16? = nil) throws {
        self.mapName = mapName
        initialSearchArea = searchArea
        guard let device = MTLCreateSystemDefaultDevice() else { throw OriginalDataError.missing("Metal device") }
        let models = try OriginalModelLibrary.bundled(), textures = try OriginalTextureLibrary.bundled()
        room = try OriginalModelMetalPreview(modelPath: "map/\(mapName)/\(mapName)/\(mapName).mdf", models: models, textures: textures, device: device, gameplayOnly: true, smoothTextures: true)
        guard let image = try OriginalBitmapLibrary.bundled().loadMap(path: "map/fmapscr/\(mapName).bin").makeCGImage() else {
            throw OriginalDataError.invalid("Lobby map image")
        }
        map = image
    }

    public func render(_ state: OriginalMapExploration, game: OriginalGameState) throws -> CGImage {
        let scene: OriginalModelMetalPreview
        if state.mode == .walking { scene = room }
        else {
            if counter == nil {
                guard let device = MTLCreateSystemDefaultDevice() else { throw OriginalDataError.missing("Metal device") }
                let area = String(format: "%02d", initialSearchArea ?? state.searchAreaID)
                counter = try OriginalModelMetalPreview(modelPath: "map/\(mapName)/\(mapName)_s\(area)/\(mapName)_s\(area).mdf",
                    models: .bundled(), textures: .bundled(), device: device, gameplayOnly: true, smoothTextures: true)
            }
            guard let counter else { throw OriginalDataError.missing("Search scene") }
            scene = counter
        }
        let visible = state.objectVisibility.visibleNodes(in: scene.model, map: state.mapID,
            area: state.mode == .walking ? nil : state.searchAreaID, game: game)
            .intersection(scene.model.gameplayRenderNodes)
        let camera = [state.position.x, state.position.z, state.facing, state.pan, state.mode == .walking ? 0 : 1]
        let scale = previousCamera == nil || previousCamera == camera ? 4 : 2
        previousCamera = camera
        return try scene.render(width: 192 * scale, height: 256 * scale, viewProjection: state.viewProjection,
            visibleNodes: visible)
    }
}
