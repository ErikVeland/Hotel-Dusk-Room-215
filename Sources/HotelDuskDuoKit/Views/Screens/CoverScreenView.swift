import SwiftUI
import ImageIO

/// The cover stays upright and retains its proportions in every orientation.
public struct CoverScreenView: View {
    @ObservedObject public var session: GameSession

    public init(session: GameSession, safeArea: EdgeInsets = EdgeInsets()) {
        self.session = session
    }

    public var body: some View {
        GeometryReader { display in
            ZStack(alignment: .leading) {
                NovelStyle.cover
                if let image = PaperbackCoverArt.image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: display.size.width, height: display.size.height, alignment: .top)
                        .clipped()
                }

                // The wear belongs to the printed stock. Only the binding's
                // shallow curvature adds light over that fixed texture.
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.24), location: 0),
                    .init(color: .clear, location: 0.28),
                    .init(color: NovelStyle.lightPaper.opacity(0.10), location: 0.55),
                    .init(color: .black.opacity(0.12), location: 0.73),
                    .init(color: .clear, location: 1)
                ], startPoint: .leading, endPoint: .trailing)
                .frame(width: max(14, display.size.width * 0.055))
                .allowsHitTesting(false)
            }
            .frame(width: display.size.width, height: display.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hotel Dusk: Room 215. Paperback cover.")
    }
}

@MainActor
enum PaperbackCoverArt {
    static let image: CGImage? = {
        let url = Bundle.module.url(forResource: "HotelDuskPaperback", withExtension: "png", subdirectory: "Images/Cover")
            ?? Bundle.module.url(forResource: "HotelDuskPaperback", withExtension: "png")
        guard let url,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }()
}
