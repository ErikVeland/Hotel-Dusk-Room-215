import CoreGraphics
import Foundation

@MainActor
struct OriginalVendingMachineRenderer {
    let keypad: CGImage
    let products: [UInt8: CGImage]

    init(library: OriginalBitmapLibrary) throws {
        func image(_ name: String) throws -> CGImage {
            let texture = try library.loadTexture(path: "trick/vendingmachine/\(name).bin")
            guard let image = OriginalArtwork.shared.image(rgba: texture.rgba,
                width: texture.storedWidth, height: texture.storedHeight, rotated: true) else {
                throw OriginalDataError.invalid("Vending machine artwork \(name)")
            }
            return image
        }
        keypad = try image("pocketcalc")
        var images: [UInt8: CGImage] = [:]
        for product in OriginalVendingMachineProcess.products {
            images[product.itemID] = try image(product.artwork)
        }
        images[78] = try image("goods14a")
        images[79] = try image("goods14b")
        products = images
    }
}
