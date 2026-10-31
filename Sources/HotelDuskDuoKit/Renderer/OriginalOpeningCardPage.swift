import SwiftUI

/// Display the original portrait surface. The book host owns page placement,
/// display fades, and original-frame advancement.
public struct OriginalOpeningCardPage: View {
    private let image: CGImage

    public init(controller: OriginalOpeningStripReveal, page: Int,
                library: OriginalOpeningGraphicsLibrary) throws {
        image = try controller.makePortraitImage(page: page, library: library)
    }

    public var body: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .interpolation(image.width > 192 ? .high : .none)
            .aspectRatio(CGFloat(192) / 256, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
    }
}
