import Foundation

/**
 * Page projection for the camera at 0x021FE6A0 and touch ray at 0x022008D4.
 * DS fixed-point ray rounding and per-piece depth remain presentation approximations.
 */
public enum OriginalJigsawProjection {
    public static let pixelsPerUnit: Float = 128 / (3 * 1.33 * tan(Float.pi / 6))

    public static func world(pageX: Float, pageY: Float) -> OriginalJigsawProcess.Point {
        .init(Int32(((pageX - 96) / pixelsPerUnit * 4096).rounded()),
              Int32(((128 - pageY) / pixelsPerUnit * 4096 - 2048).rounded()))
    }

    public static func centre(_ piece: OriginalJigsawProcess.Piece) -> SIMD2<Float> {
        SIMD2(96 + (Float(piece.position.x) / 4096 + 0.5) * pixelsPerUnit,
              128 - (Float(piece.position.y) / 4096 + 1) * pixelsPerUnit)
    }

    public static func imageName(_ index: Int) -> String {
        "JigsawPiece\(4 - index / 4)\(3 - index % 4)"
    }
}
