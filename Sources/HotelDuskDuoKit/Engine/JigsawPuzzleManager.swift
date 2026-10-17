import Foundation
import Combine
import CoreGraphics

/// Melissa's assembled jigsaw turns over when the closed device is opened.
/// Piece positions belong to the session so a fold cannot discard an unfinished move.
@MainActor
public final class JigsawPuzzleManager: ObservableObject {
    public enum Phase: String, Sendable {
        case assembling, assembled, folded, reverseRevealed
    }

    public struct Placement: Equatable, Sendable {
        public var centre: CGPoint
        public var quarterTurns: Int
        public var isPlaced: Bool
    }

    @Published public private(set) var phase: Phase = .assembling
    @Published public private(set) var placements: [String: Placement] = [:]
    @Published public private(set) var selectedPieceID: String?
    public let manifest: JigsawManifest
    public var hasRevealedReverse: Bool { phase == .reverseRevealed }

    public init(manifest: JigsawManifest = JigsawManifest.bundled) {
        self.manifest = manifest
        for (index, piece) in manifest.pieces.enumerated() {
            // Scatter the original pieces across the original tabletop. No target
            // markers or solved-picture overlay are shown during assembly.
            let slot = (index * 7 + 3) % max(1, manifest.pieces.count)
            let column = slot % 4
            let row = slot / 4
            let centre = CGPoint(x: 25 + Double(column) * 46,
                                 y: 32 + Double(row) * 46)
            placements[piece.id] = Placement(centre: centre, quarterTurns: (index * 3 + 1) % 4, isPlaced: false)
        }
    }

    public func selectPiece(_ id: String) {
        guard phase == .assembling, placements[id]?.isPlaced == false else { return }
        selectedPieceID = id
    }

    public func movePiece(_ id: String, to centre: CGPoint) {
        guard phase == .assembling, var placement = placements[id], !placement.isPlaced,
              centre.x.isFinite, centre.y.isFinite else { return }
        selectedPieceID = id
        placement.centre = CGPoint(x: max(0, min(manifest.boardWidth, centre.x)),
                                   y: max(0, min(manifest.boardHeight, centre.y)))
        placements[id] = placement
    }

    public func rotatePiece(_ id: String, clockwise: Bool = true) {
        guard phase == .assembling, var placement = placements[id], !placement.isPlaced else { return }
        selectedPieceID = id
        placement.quarterTurns = (placement.quarterTurns + (clockwise ? 1 : 3)) % 4
        placements[id] = placement
    }

    /// A piece seats only when its own outline is aligned and upright.
    @discardableResult
    public func releasePiece(_ id: String) -> Bool {
        guard phase == .assembling, var placement = placements[id], !placement.isPlaced,
              let piece = manifest.pieces.first(where: { $0.id == id }) else { return false }
        let distance = hypot(placement.centre.x - piece.centre.x, placement.centre.y - piece.centre.y)
        guard placement.quarterTurns == 0, distance <= 8 else { return false }
        placement.centre = piece.centre
        placement.isPlaced = true
        placements[id] = placement
        selectedPieceID = nil
        if !placements.isEmpty && placements.values.allSatisfy(\.isPlaced) {
            phase = .assembled
        }
        return true
    }

    public func onDeviceFoldedShut() {
        if phase == .assembled { phase = .folded }
    }

    @discardableResult
    public func onDeviceReopened() -> Bool {
        guard phase == .folded else { return false }
        phase = .reverseRevealed
        return true
    }

    public func cancelPendingFold() {
        if phase == .folded { phase = .assembled }
    }
}

public struct JigsawManifest: Decodable, Sendable {
    public struct Piece: Decodable, Identifiable, Sendable {
        public let id: String
        public let image: String
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double
        public var centre: CGPoint { CGPoint(x: x + width / 2, y: y + height / 2) }
    }
    public let boardWidth: Double
    public let boardHeight: Double
    public let pieces: [Piece]
    public let frontImage: String
    public let reverseImage: String
    public let tableImage: String
    public let trayImage: String
    public let foldTrayImage: String
    public let rotateLeftImage: String
    public let rotateRightImage: String

    public static let bundled: JigsawManifest = {
        guard let url = Bundle.module.url(forResource: "JigsawManifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(JigsawManifest.self, from: data) else {
            preconditionFailure("The original jigsaw asset manifest is missing or invalid.")
        }
        return manifest
    }()
}
