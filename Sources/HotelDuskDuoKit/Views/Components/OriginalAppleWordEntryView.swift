import SwiftUI

/**
 * Presents the five recovered letters for the player's Chapter 9 word entry.
 */
struct OriginalAppleWordEntryView: View {
    @ObservedObject var play: OriginalPlaySession

    private let letters = OriginalAppleWordEntryProcess.letters

    var body: some View {
        VStack(spacing: 18) {
            Text("Tap the letters in apple-count order.")
                .font(.headline)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                ForEach(letters.indices, id: \.self) { index in
                    Button {
                        play.selectAppleWordLetter(at: index)
                    } label: {
                        VStack(spacing: 4) {
                            Text(String(letters[index]))
                                .font(.title2.bold())
                            Text(verbatim: appleCountLabel(at: index))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(NovelStyle.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: "\(letters[index]), \(appleCountLabel(at: index))"))
                }
            }

            Text(String(play.appleWordEntry?.selectedLetters ?? []))
                .font(.title2.monospaced().bold())
                .frame(minHeight: 32)
                .accessibilityLabel("Letters entered")
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func appleCountLabel(at index: Int) -> String {
        let count = index + 1
        return count == 1 ? "1 apple" : "\(count) apples"
    }
}
