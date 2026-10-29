import SwiftUI
#if canImport(UIKit) && canImport(PencilKit)
import UIKit
import PencilKit
#endif

/// Kyle's notebook keeps written clues and pen strokes on the reading page.
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
                    draft.nativeDrawingData = Data()
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
                    #if !canImport(UIKit) || !canImport(PencilKit)
                    for line in draft.lines + [draft.currentLine] {
                        guard let first = line.first else { continue }
                        var path = Path()
                        path.move(to: first)
                        for point in line.dropFirst() { path.addLine(to: point) }
                        context.stroke(path, with: .color(NovelStyle.ink), lineWidth: 2)
                    }
                    #endif
                }
                #if !canImport(UIKit) || !canImport(PencilKit)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { draft.currentLine.append($0.location) }
                    .onEnded { _ in
                        draft.lines.append(draft.currentLine)
                        draft.currentLine = []
                    })
                #endif
                .accessibilityLabel("Pen drawing")
                #if canImport(UIKit) && canImport(PencilKit)
                NativeMemoCanvas(draft: draft)
                #endif
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

#if canImport(UIKit) && canImport(PencilKit)
private struct NativeMemoCanvas: UIViewRepresentable {
    @ObservedObject var draft: MemoDraft

    func makeCoordinator() -> Coordinator { Coordinator(draft: draft) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: UIColor(red: 0.20, green: 0.17, blue: 0.14, alpha: 1), width: 1.6)
        if let drawing = try? PKDrawing(data: draft.nativeDrawingData) { canvas.drawing = drawing }
        context.coordinator.lastData = draft.nativeDrawingData
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.draft = draft
        guard context.coordinator.lastData != draft.nativeDrawingData else { return }
        context.coordinator.lastData = draft.nativeDrawingData
        canvas.drawing = (try? PKDrawing(data: draft.nativeDrawingData)) ?? PKDrawing()
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var draft: MemoDraft
        var lastData = Data()

        init(draft: MemoDraft) { self.draft = draft }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let data = canvasView.drawing.dataRepresentation()
            guard data != lastData else { return }
            lastData = data
            draft.nativeDrawingData = data
        }
    }
}
#endif
