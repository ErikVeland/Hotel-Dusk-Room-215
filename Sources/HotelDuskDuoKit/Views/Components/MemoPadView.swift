import SwiftUI

/// Kyle's notebook keeps written clues and pencil strokes on the reading page.
public struct MemoPadView: View {
    @ObservedObject public var session: GameSession
    @ObservedObject private var draft: MemoDraft

    public init(session: GameSession) {
        self.session = session
        self.draft = session.memoDraft
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kyle Hyde’s notebook").font(NovelStyle.title)
            HStack {
                Button("Erase drawing") {
                    draft.lines.removeAll()
                    draft.currentLine.removeAll()
                }
                Spacer()
                Button("Put away") { session.isMemoPadOpen = false }
                    .accessibilityLabel("Close notebook")
            }
            .buttonStyle(BookTextButtonStyle())

            ZStack(alignment: .topLeading) {
                NovelStyle.lightPaper
                Canvas { context, size in
                    for y in stride(from: CGFloat(28), to: size.height, by: 28) {
                        var rule = Path()
                        rule.move(to: CGPoint(x: 0, y: y))
                        rule.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(rule, with: .color(NovelStyle.rule.opacity(0.23)), lineWidth: 0.5)
                    }
                    for line in draft.lines + [draft.currentLine] {
                        guard let first = line.first else { continue }
                        var path = Path()
                        path.move(to: first)
                        for point in line.dropFirst() { path.addLine(to: point) }
                        context.stroke(path, with: .color(NovelStyle.ink), lineWidth: 2)
                    }
                }
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { draft.currentLine.append($0.location) }
                    .onEnded { _ in
                        draft.lines.append(draft.currentLine)
                        draft.currentLine = []
                    })
                .accessibilityLabel("Pencil drawing")
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(session.memoNotes, id: \.self) { note in
                        Text(note)
                            .font(NovelStyle.italic)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .allowsHitTesting(false)
            }
            .frame(height: 260)
            .overlay(Rectangle().strokeBorder(NovelStyle.rule.opacity(0.3), lineWidth: 0.5))

            TextField("Jot down a clue…", text: $draft.text)
                .textFieldStyle(.plain)
                .font(NovelStyle.body)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) { InkRule() }
            Button("Keep this note") {
                session.addMemoNote(draft.text)
                draft.text = ""
            }
            .buttonStyle(BookTextButtonStyle())
            .disabled(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .foregroundStyle(NovelStyle.ink)
    }
}
