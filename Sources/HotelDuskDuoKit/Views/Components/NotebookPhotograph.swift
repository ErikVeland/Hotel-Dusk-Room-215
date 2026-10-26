import SwiftUI

/// Mounts the image without moving its pixels or changing its touch coordinates.
/// The matte and adhesive sit outside the image's layout rectangle.
private struct NotebookPhotograph: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    NovelStyle.lightPaper
                    if let card = MetalPaperStock.photoCard {
                        Image(decorative: card, scale: 1).resizable()
                    }
                }
                .padding(.horizontal, -8)
                .padding(.top, -8)
                .padding(.bottom, -14)
                .rotationEffect(.degrees(-0.35))
                .shadow(color: NovelStyle.ink.opacity(0.24), radius: 3, x: 1, y: 4)
                .shadow(color: NovelStyle.ink.opacity(0.12), radius: 0.5, x: 0, y: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .overlay {
                Rectangle().strokeBorder(NovelStyle.ink.opacity(0.25), lineWidth: 0.5)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topLeading) {
                NotebookTape().rotationEffect(.degrees(-17)).offset(x: -18, y: -10)
            }
            .overlay(alignment: .topTrailing) {
                NotebookTape(alternate: true).rotationEffect(.degrees(13)).offset(x: 18, y: -8)
            }
    }
}

struct NotebookTape: View {
    var alternate = false

    var body: some View {
        Group {
            if let tape = alternate ? MetalPaperStock.secondTape : MetalPaperStock.tape {
                Image(decorative: tape, scale: 1).resizable().interpolation(.high)
            } else {
                Rectangle().fill(Color(red: 0.82, green: 0.73, blue: 0.51).opacity(0.65))
            }
        }
        .frame(width: 62, height: 21)
        .shadow(color: NovelStyle.ink.opacity(0.12), radius: 0.5, x: 0, y: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func notebookPhotograph() -> some View { modifier(NotebookPhotograph()) }
}

/// The title leaf uses the same ink, stock, and pasted artwork as the case notes.
struct NotebookTitleLeaf: View {
    var body: some View {
        ViewThatFits(in: .vertical) {
            titleLeaf(showArtwork: true)
            ScrollView { titleLeaf(showArtwork: false) }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
    }

    private func titleLeaf(showArtwork: Bool) -> some View {
        VStack(spacing: 18) {
            Text("KYLE HYDE / PRIVATE NOTES")
                .font(NovelStyle.imprint).tracking(2)
                .foregroundStyle(NovelStyle.fadedInk)
            InkRule()
            VStack(spacing: 0) {
                Text("HOTEL\nDUSK")
                    .font(.custom("Baskerville-Bold", size: 56, relativeTo: .largeTitle))
                    .tracking(3).lineSpacing(-8)
                    .foregroundStyle(NovelStyle.redInk)
                Text("Room 215").font(NovelStyle.title).italic()
            }
            .minimumScaleFactor(0.65)
            if showArtwork, let image = PaperbackCoverArt.image {
                Image(decorative: image, scale: 1)
                    .resizable().scaledToFit()
                    .frame(height: 190)
                    .notebookPhotograph()
                    .padding(.vertical, 10)
            }
            Text("DECEMBER 28, 1979")
                .font(NovelStyle.imprint).tracking(2)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}
