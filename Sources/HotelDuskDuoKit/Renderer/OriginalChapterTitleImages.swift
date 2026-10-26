import CoreGraphics

/**
 * Original chapter still artwork. The native page supplies its text separately.
 */
@MainActor
public struct OriginalChapterTitleImages {
    public let left: CGImage
    public let right: CGImage
    public let clock: CGImage
    public let item: CGImage

    public init(library: OriginalBitmapLibrary, chapter: UInt16 = 1) throws {
        func image(_ name: String, transparent: Bool = true) throws -> CGImage {
            let bitmap = try library.loadLinear(path: "system/title/\(name).bin")
            guard let result = OriginalEntrancePanels.rotated(rgba: bitmap.rgba(transparentPaletteZero: transparent),
                width: bitmap.width, height: bitmap.height) else {
                throw OriginalDataError.invalid("Chapter title bitmap")
            }
            return result
        }
        left = try image("backL", transparent: false)
        right = try image("backR", transparent: false)
        let suffix = try OriginalChapter(chapter).artworkSuffix
        clock = try image("clock\(suffix)")
        item = try image("item\(suffix)")
    }
}
