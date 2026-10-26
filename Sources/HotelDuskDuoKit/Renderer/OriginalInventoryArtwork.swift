import Foundation
import CoreGraphics

/// Original item pictures in their upright book orientation, shared by the
/// inventory grid, inspection view and selected-item labels.
@MainActor
final class OriginalInventoryArtwork {
    static let shared = OriginalInventoryArtwork()
    private let library: OriginalBitmapLibrary?
    let names: [UInt8: String]
    private var images: [UInt8: CGImage] = [:]

    init() {
        library = try? .bundled()
        names = (try? OriginalItemNames.bundled().names) ?? [:]
    }

    func name(for item: UInt8) -> String { names[item] ?? "Item \(item)" }

    func hasOriginalPicture(for item: UInt8) -> Bool {
        let path = String(format: "system/ItemImage/item%03d.bin", Int(item))
        return library?.manifest.images.contains { $0.source == path } == true
    }

    func image(for item: UInt8) throws -> CGImage {
        if let image = images[item] { return image }
        guard let library else { throw OriginalDataError.missing("Item artwork") }
        let image = try OriginalTouchPictureImages.item(item, library: library)
        images[item] = image
        return image
    }
}
