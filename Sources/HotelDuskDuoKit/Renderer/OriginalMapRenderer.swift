import CoreGraphics
import Dispatch
import Metal

@MainActor
public protocol OriginalMapRendering: AnyObject {
    var map: CGImage { get }
    func setDisplayScale(_ scale: CGFloat)
    func render(_ state: OriginalMapExploration, game: OriginalGameState) throws -> CGImage
}

public extension OriginalMapRendering {
    func setDisplayScale(_ scale: CGFloat) {}
}

public typealias OriginalMapRendererFactory = @MainActor (String, UInt16?) throws -> any OriginalMapRendering

/**
 * Draws the recovered lobby and counter through the existing native model renderer.
 */
public final class OriginalMapRenderer: OriginalMapRendering, @unchecked Sendable {
    public let map: CGImage
    nonisolated(unsafe) private let room: OriginalModelMetalPreview
    nonisolated(unsafe) private var counter: OriginalModelMetalPreview?
    private let mapName: String
    private let initialSearchArea: UInt16?
    nonisolated(unsafe) private var renderScale = 4
    private let renderLock = NSRecursiveLock()

    public init(mapName: String = "R102", searchArea: UInt16? = nil) throws {
        self.mapName = mapName
        initialSearchArea = searchArea
        guard let device = MTLCreateSystemDefaultDevice() else { throw OriginalDataError.missing("Metal device") }
        let models = try OriginalModelLibrary.bundled(), textures = try OriginalTextureLibrary.bundled()
        room = try OriginalModelMetalPreview(modelPath: "map/\(mapName)/\(mapName)/\(mapName).mdf", models: models, textures: textures, device: device, gameplayOnly: true, smoothTextures: OriginalArtwork.isHDGraphicsEnabled)
        guard let image = try OriginalBitmapLibrary.bundled().loadMap(path: "map/fmapscr/\(mapName).bin").makeCGImage() else {
            throw OriginalDataError.invalid("Lobby map image")
        }
        map = image
    }

    public func render(_ state: OriginalMapExploration, game: OriginalGameState) throws -> CGImage {
        try renderInternal(state, game: game)
    }

    /**
     * Renders a map snapshot from the serial background queue.
     */
    nonisolated func renderOnWorker(_ state: OriginalMapExploration, game: OriginalGameState) throws -> CGImage {
        try renderInternal(state, game: game)
    }

    nonisolated private func renderInternal(_ state: OriginalMapExploration, game: OriginalGameState) throws -> CGImage {
        renderLock.lock()
        defer { renderLock.unlock() }
        let scene: OriginalModelMetalPreview
        if state.mode == .walking { scene = room }
        else {
            if counter == nil {
                guard let device = MTLCreateSystemDefaultDevice() else { throw OriginalDataError.missing("Metal device") }
                let area = String(format: "%02d", initialSearchArea ?? state.searchAreaID)
                counter = try OriginalModelMetalPreview(modelPath: "map/\(mapName)/\(mapName)_s\(area)/\(mapName)_s\(area).mdf",
                    models: .bundled(), textures: .bundled(), device: device, gameplayOnly: true,
                    smoothTextures: OriginalArtwork.isHDGraphicsEnabled)
            }
            guard let counter else { throw OriginalDataError.missing("Search scene") }
            scene = counter
        }
        let visible = state.objectVisibility.visibleNodes(in: scene.model, map: state.mapID,
            area: state.mode == .walking ? nil : state.searchAreaID, game: game)
            .intersection(scene.model.gameplayRenderNodes)
        return try scene.render(width: 192 * renderScale, height: 256 * renderScale, viewProjection: state.viewProjection,
            visibleNodes: visible)
    }

    public func setDisplayScale(_ scale: CGFloat) {
        setRenderScale(scale)
    }

    /**
     * Sets the output scale from the serial background queue.
     */
    nonisolated func setDisplayScaleOnWorker(_ scale: CGFloat) {
        setRenderScale(scale)
    }

    nonisolated private func setRenderScale(_ scale: CGFloat) {
        guard scale.isFinite, scale > 0 else { return }
        renderLock.lock()
        defer { renderLock.unlock() }
        renderScale = OriginalArtwork.isHDGraphicsEnabled ? min(16, max(4, Int(ceil(scale)))) : 1
    }
}

/**
 * Serializes map renders away from the UI thread and keeps only the latest pending state.
 */
final class OriginalMapRenderQueue: @unchecked Sendable {
    typealias Completion = @MainActor @Sendable (UInt64, CGImage?, String?) -> Void

    struct Request: @unchecked Sendable {
        let id: UInt64
        let renderer: OriginalMapRenderer
        let state: OriginalMapExploration
        let game: OriginalGameState
        let scale: CGFloat
        let completion: Completion
    }

    private let queue = DispatchQueue(label: "HotelDusk.OriginalMapRender")
    private let lock = NSLock()
    private var pending: Request?
    private var isRendering = false

    init() {}

    /**
     * Replaces the pending render with the latest map snapshot.
     */
    func submit(_ request: Request) {
        lock.lock()
        pending = request
        let shouldStart = !isRendering
        if shouldStart { isRendering = true }
        lock.unlock()
        if shouldStart { queue.async { self.drain() } }
    }

    /**
     * Renders the latest pending snapshot without blocking the caller.
     */
    private func drain() {
        while true {
            lock.lock()
            guard let request = pending else {
                isRendering = false
                lock.unlock()
                return
            }
            pending = nil
            lock.unlock()

            let image: CGImage?
            let failure: String?
            do {
                request.renderer.setDisplayScaleOnWorker(request.scale)
                image = try request.renderer.renderOnWorker(request.state, game: request.game)
                failure = nil
            } catch {
                image = nil
                failure = String(describing: error)
            }
            Task { @MainActor in request.completion(request.id, image, failure) }
        }
    }
}
