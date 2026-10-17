import SwiftUI

/// Dialogue reads as a printed passage, with choices set beneath a fine rule.
public struct DialogueBoxView: View {
    @ObservedObject public var session: GameSession
    let node: DialogueNode

    public init(session: GameSession, node: DialogueNode) {
        self.session = session
        self.node = node
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(node.speaker.uppercased())
                    .font(NovelStyle.heading)
                    .tracking(1.3)
                if node.isInterrogationQuestion {
                    Text("Choose your words carefully.")
                        .font(NovelStyle.italic)
                        .foregroundStyle(NovelStyle.redInk)
                }
            }

            Text(node.text)
                .font(NovelStyle.body)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if !node.choices.isEmpty {
                InkRule()
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(node.choices.enumerated()), id: \.element.id) { index, choice in
                        Button { session.selectChoice(choice) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(String(format: "%02d", index + 1))
                                    .font(NovelStyle.caption)
                                    .foregroundStyle(NovelStyle.fadedInk)
                                Text(choice.prompt)
                                    .font(NovelStyle.body)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PassageChoiceStyle())
                    }
                }
            }
        }
        .foregroundStyle(NovelStyle.ink)
        .padding(.vertical, 12)
    }
}

private struct PassageChoiceStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? NovelStyle.redInk : NovelStyle.ink)
            .background(configuration.isPressed ? NovelStyle.ink.opacity(0.06) : .clear)
    }
}
