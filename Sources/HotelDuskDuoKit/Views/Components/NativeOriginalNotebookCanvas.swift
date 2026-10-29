#if canImport(UIKit) && canImport(PencilKit)
import SwiftUI
import UIKit
import PencilKit

struct NativeOriginalNotebookCanvas: UIViewRepresentable {
    @ObservedObject var play: OriginalPlaySession
    let notebook: OriginalNotebook
    let clearToken: Int
    let undoToken: Int

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.drawingPolicy = .anyInput
        canvas.tool = tool
        let saved = play.nativeNotebookPages[String(notebook.page)]
        canvas.drawing = saved.flatMap { try? PKDrawing(data: $0) } ?? Self.migrate(notebook)
        context.coordinator.lastDrawing = canvas.drawing.dataRepresentation()
        context.coordinator.clearToken = clearToken
        context.coordinator.undoToken = undoToken
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        canvas.tool = tool
        canvas.isUserInteractionEnabled = !play.isPaused && notebook.canEdit
        if coordinator.clearToken != clearToken {
            coordinator.clearToken = clearToken
            canvas.drawing = PKDrawing()
            coordinator.save(canvas)
        }
        if coordinator.undoToken != undoToken {
            coordinator.undoToken = undoToken
            canvas.undoManager?.undo()
            coordinator.save(canvas)
        }
    }

    private var tool: PKTool {
        if notebook.erasing { return PKEraserTool(.bitmap) }
        return PKInkingTool(.pen, color: UIColor(red: 0.20, green: 0.17, blue: 0.14, alpha: 1), width: 1.6)
    }

    /// Import existing DS ink into editable native strokes, retaining old saves.
    private static func migrate(_ notebook: OriginalNotebook) -> PKDrawing {
        let ink = PKInk(.pen, color: UIColor(red: 0.20, green: 0.17, blue: 0.14, alpha: 1))
        var strokes: [PKStroke] = []
        for y in 0..<256 {
            var x = 0
            while x < 192 {
                func filled(_ column: Int) -> Bool {
                    let row = 255 - y
                    let index = (column / 8) * 0x800 + (row / 8) * 64 + (column % 8) * 8 + row % 8
                    return notebook.pixels[index] != 0
                }
                guard filled(x) else { x += 1; continue }
                let start = x
                while x + 1 < 192 && filled(x + 1) { x += 1 }
                let end = x
                let points = [CGFloat(start) + 0.5, CGFloat(end) + 0.6].map {
                    PKStrokePoint(location: CGPoint(x: $0, y: CGFloat(y) + 0.5), timeOffset: 0,
                                  size: CGSize(width: 1, height: 1), opacity: 1, force: 1,
                                  azimuth: 0, altitude: .pi / 2)
                }
                strokes.append(PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: .distantPast)))
                x += 1
            }
        }
        return PKDrawing(strokes: strokes)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: NativeOriginalNotebookCanvas
        var lastDrawing = Data()
        var clearToken = 0
        var undoToken = 0

        init(parent: NativeOriginalNotebookCanvas) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { save(canvasView) }

        func save(_ canvas: PKCanvasView) {
            let data = canvas.drawing.dataRepresentation()
            guard data != lastDrawing, let packed = Self.packedInk(canvas.drawing) else { return }
            lastDrawing = data
            parent.play.setNativeNotebookInk(page: parent.notebook.page, drawing: data, packed: packed)
        }

        private static func packedInk(_ drawing: PKDrawing) -> Data? {
            let image = drawing.image(from: CGRect(x: 0, y: 0, width: 192, height: 256), scale: 1)
            guard let cgImage = image.cgImage else { return nil }
            var rgba = [UInt8](repeating: 0, count: 192 * 256 * 4)
            guard let context = CGContext(data: &rgba, width: 192, height: 256, bitsPerComponent: 8,
                                          bytesPerRow: 192 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.translateBy(x: 0, y: 256)
            context.scaleBy(x: 1, y: -1)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 192, height: 256))
            var packed = [UInt8](repeating: 0, count: OriginalNotebook.packedSize)
            for y in 0..<256 {
                for x in 0..<192 where rgba[(y * 192 + x) * 4 + 3] >= 32 {
                    let row = 255 - y
                    let index = (x / 8) * 0x800 + (row / 8) * 64 + (x % 8) * 8 + row % 8
                    packed[index / 8] |= UInt8(1 << (index % 8))
                }
            }
            return Data(packed)
        }
    }
}
#endif
