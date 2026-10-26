import SwiftUI

/// Paperback typography, paper and ink shared by the book's pages and documents.
enum NovelStyle {
    static let paper = Color(red: 0.93, green: 0.89, blue: 0.80)
    static let lightPaper = Color(red: 0.97, green: 0.94, blue: 0.87)
    static let ink = Color(red: 0.20, green: 0.17, blue: 0.14)
    static let fadedInk = Color(red: 0.43, green: 0.37, blue: 0.30)
    static let rule = Color(red: 0.56, green: 0.48, blue: 0.36)
    static let redInk = Color(red: 0.48, green: 0.19, blue: 0.15)
    static let cover = Color(red: 0.13, green: 0.12, blue: 0.10)

    static let title = Font.custom("Baskerville", size: 28, relativeTo: .title)
    static let heading = Font.custom("Baskerville-SemiBold", size: 20, relativeTo: .headline)
    static let body = Font.custom("Georgia", size: 18, relativeTo: .body)
    static let italic = Font.custom("Georgia-Italic", size: 16, relativeTo: .callout)
    static let label = Font.custom("Baskerville", size: 17, relativeTo: .callout)
    static let caption = Font.custom("Baskerville", size: 14, relativeTo: .caption)
    static let document = Font.custom("Courier", size: 15, relativeTo: .callout)
    static let imprint = Font.custom("Courier", size: 11, relativeTo: .caption2)
}

struct PaperSurface: View {
    var side: PaperPageSide = .left

    var body: some View {
        ZStack {
            NovelStyle.paper
            if let stock = MetalPaperStock.image(for: side) ?? PaperStock.image(for: side) {
                Image(decorative: stock, scale: 1)
                    .resizable()
                    .interpolation(.high)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct InkRule: View {
    var body: some View {
        Rectangle().fill(NovelStyle.rule.opacity(0.45)).frame(height: 0.5)
            .accessibilityHidden(true)
    }
}

/// An underlined text affordance with a full touch target, without a button tile.
struct BookTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NovelStyle.label)
            .foregroundStyle(NovelStyle.ink)
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .background(configuration.isPressed ? NovelStyle.ink.opacity(0.08) : .clear)
            .opacity(isEnabled ? 1 : 0.45)
            .overlay(alignment: .bottom) {
                Rectangle().fill(NovelStyle.rule.opacity(configuration.isPressed ? 0.8 : 0.35))
                    .frame(height: 0.5)
                    .padding(.horizontal, 8)
            }
    }
}
