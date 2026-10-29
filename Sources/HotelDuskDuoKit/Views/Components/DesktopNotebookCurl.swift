import SwiftUI

struct NotebookCurlGeometry {
    struct Point {
        let position: CGPoint
        let depth: CGFloat
        let facesFront: Bool
    }

    /// Integrate the sheet tangent along its width. Both ends of the animation
    /// are flat; its middle is a curved sheet with a real reverse face.
    static func point(u: CGFloat, v: CGFloat, progress: Double, pageSize: CGSize) -> Point {
        let p = min(1, max(0, progress))
        let bend = sin(.pi * p) * 1.2
        let angle = .pi * p - bend / 2
        let tangent = angle + bend * Double(u)
        let x: Double, z: Double
        if abs(bend) < 0.00001 {
            x = Double(pageSize.width * u) * cos(angle)
            z = Double(pageSize.width * u) * sin(angle)
        } else {
            x = Double(pageSize.width) / bend * (sin(tangent) - sin(angle))
            z = Double(pageSize.width) / bend * (cos(angle) - cos(tangent))
        }
        let perspective = 1 / (1 - z / max(1, Double(pageSize.width * 4)))
        return Point(position: CGPoint(x: pageSize.width + x * perspective,
                                       y: pageSize.height / 2 + (v - 0.5) * pageSize.height * perspective),
                     depth: z, facesFront: cos(tangent) >= 0)
    }
}

struct NotebookPageDrag {
    static func progress(translation: CGFloat, pageWidth: CGFloat, backward: Bool) -> Double {
        let distance = backward ? translation : -translation
        return min(1, max(0, Double(distance / max(1, pageWidth * 2))))
    }

    static func shouldComplete(translation: CGFloat, predicted: CGFloat, pageWidth: CGFloat, backward: Bool) -> Bool {
        let current = progress(translation: translation, pageWidth: pageWidth, backward: backward)
        let projected = progress(translation: predicted, pageWidth: pageWidth, backward: backward)
        let direction: CGFloat = backward ? 1 : -1
        if (predicted - translation) * direction < -pageWidth * 0.12 { return false }
        return current >= 0.5 || projected >= 0.5
    }
}

struct NotebookCurlImages {
    let left: CGImage
    let front: CGImage
    let reverse: CGImage
}

/// A sheet raised towards the reader, with its reverse crossing the spine.
struct DesktopNotebookCurl: View, Animatable {
    let images: NotebookCurlImages
    let pageSize: CGSize
    var progress: Double
    var backward = false
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, _ in
            let oldLeft = context.resolve(Image(decorative: images.left, scale: 1))
            let front = context.resolve(Image(decorative: images.front, scale: 1))
            let reverse = context.resolve(Image(decorative: images.reverse, scale: 1))
            context.draw(oldLeft, in: CGRect(origin: CGPoint(x: backward ? pageSize.width : 0, y: 0), size: pageSize))
            let count = 64
            func position(_ point: NotebookCurlGeometry.Point) -> NotebookCurlGeometry.Point {
                NotebookCurlGeometry.Point(position: CGPoint(
                    x: backward ? pageSize.width * 2 - point.position.x : point.position.x,
                    y: point.position.y), depth: point.depth, facesFront: point.facesFront)
            }
            let top = (0...count).map { position(NotebookCurlGeometry.point(u: CGFloat($0) / CGFloat(count), v: 0, progress: progress, pageSize: pageSize)) }
            let bottom = (0...count).map { position(NotebookCurlGeometry.point(u: CGFloat($0) / CGFloat(count), v: 1, progress: progress, pageSize: pageSize)) }
            var outline = Path()
            outline.addLines(top.map(\.position) + bottom.reversed().map(\.position))
            outline.closeSubpath()
            var shadow = context
            let lift = sin(.pi * min(1, max(0, progress)))
            shadow.addFilter(.shadow(color: .black.opacity(0.22 * lift), radius: 12 * lift,
                                     x: -10 * lift, y: 5 * lift))
            shadow.fill(outline, with: .color(.black.opacity(0.16 * lift)))
            let order = (0..<count).sorted { top[$0].depth < top[$1].depth }
            for index in order {
                let x0 = CGFloat(index) / CGFloat(count) * pageSize.width
                let x1 = CGFloat(index + 1) / CGFloat(count) * pageSize.width
                let isFront = NotebookCurlGeometry.point(u: (CGFloat(index) + 0.5) / CGFloat(count), v: 0.5,
                    progress: progress, pageSize: pageSize).facesFront
                let source0 = isFront != backward ? x0 : pageSize.width - x0
                let source1 = isFront != backward ? x1 : pageSize.width - x1
                let source = [CGPoint(x: source0, y: 0), CGPoint(x: source1, y: 0),
                              CGPoint(x: source0, y: pageSize.height), CGPoint(x: source1, y: pageSize.height)]
                let target = [top[index].position, top[index + 1].position,
                              bottom[index].position, bottom[index + 1].position]
                for triangle in [[0, 1, 2], [1, 3, 2]] {
                    drawTriangle(context: context, image: isFront ? front : reverse,
                                 source: triangle.map { source[$0] }, target: triangle.map { target[$0] })
                }
                var shade = Path()
                shade.addLines([target[0], target[1], target[3], target[2]])
                shade.closeSubpath()
                context.fill(shade, with: .color(NovelStyle.ink.opacity(lift * (isFront ? 0.06 : 0.13))),
                             style: FillStyle(antialiased: false))
            }
        }
        .frame(width: pageSize.width * 2, height: pageSize.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawTriangle(context: GraphicsContext, image: GraphicsContext.ResolvedImage,
                              source: [CGPoint], target: [CGPoint]) {
        let sx1 = source[1].x - source[0].x, sy1 = source[1].y - source[0].y
        let sx2 = source[2].x - source[0].x, sy2 = source[2].y - source[0].y
        let determinant = sx1 * sy2 - sx2 * sy1
        guard abs(determinant) > 0.00001 else { return }
        let tx1 = target[1].x - target[0].x, ty1 = target[1].y - target[0].y
        let tx2 = target[2].x - target[0].x, ty2 = target[2].y - target[0].y
        let a = (tx1 * sy2 - tx2 * sy1) / determinant
        let b = (ty1 * sy2 - ty2 * sy1) / determinant
        let c = (tx2 * sx1 - tx1 * sx2) / determinant
        let d = (ty2 * sx1 - ty1 * sx2) / determinant
        let transform = CGAffineTransform(a: a, b: b, c: c, d: d,
            tx: target[0].x - a * source[0].x - c * source[0].y,
            ty: target[0].y - b * source[0].x - d * source[0].y)
        var triangle = Path()
        triangle.addLines(target)
        triangle.closeSubpath()
        var drawing = context
        // Adjacent mesh triangles share exact edges. Antialiasing each clip
        // separately would let the old page show through as fine stripes.
        drawing.clip(to: triangle, style: FillStyle(antialiased: false))
        drawing.concatenate(transform)
        drawing.draw(image, in: CGRect(origin: .zero, size: pageSize))
    }
}

struct DesktopNotebookSpread: View {
    @ObservedObject var play: OriginalPlaySession
    @ObservedObject var notebook: DialogueNotebook
    let layout: DialogueNotebookLayout
    let metrics: DialogueSpreadMetrics
    let reduceMotion: Bool
    var gesturesEnabled = true
    @State private var images: NotebookCurlImages?
    @State private var progress = 0.0
    @State private var backward = false
    @State private var imageRevision: Int?
    @GestureState private var dragging = false

    private struct TurnKey: Equatable {
        let revision: Int
        let holding: Bool
    }

    var body: some View {
        HStack(spacing: 0) {
            leaf(notebook.reader.leftIndex)
            leaf(notebook.reader.leftIndex + 1)
        }
        .overlay(alignment: .topLeading) {
            if let images { DesktopNotebookCurl(images: images, pageSize: metrics.pageSize, progress: progress, backward: backward) }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 6)
            .updating($dragging) { _, active, _ in active = true }
            .onChanged { value in
                guard gesturesEnabled,
                      abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                if !notebook.isTurning {
                    let back = value.startLocation.x < metrics.pageSize.width
                    guard back ? value.translation.width > 0 : value.translation.width < 0,
                          !back || play.canReviewConversations,
                          notebook.beginInteractiveTurn(backward: back) else { return }
                }
                guard notebook.isHoldingTurn else { return }
                notebook.updateInteractiveTurn(progress: NotebookPageDrag.progress(
                    translation: value.translation.width, pageWidth: metrics.pageSize.width,
                    backward: notebook.turnsBackward))
            }
            .onEnded { value in
                guard notebook.isHoldingTurn else { return }
                notebook.releaseInteractiveTurn(commit: NotebookPageDrag.shouldComplete(
                    translation: value.translation.width, predicted: value.predictedEndTranslation.width,
                    pageWidth: metrics.pageSize.width, backward: notebook.turnsBackward))
            })
        .onChange(of: dragging) { _, active in
            if !active, notebook.isHoldingTurn { notebook.releaseInteractiveTurn(commit: false) }
        }
        .onChange(of: gesturesEnabled) { _, enabled in
            if !enabled, notebook.isHoldingTurn { notebook.releaseInteractiveTurn(commit: false) }
        }
        .onChange(of: notebook.turnProgress) { _, value in
            if notebook.isHoldingTurn { progress = value }
        }
        .task(id: TurnKey(revision: notebook.turnRevision, holding: notebook.isHoldingTurn)) {
            let revision = notebook.turnRevision
            guard notebook.isTurning else { images = nil; return }
            let previousLeft = notebook.turnFromSpread * 2
            backward = notebook.turnsBackward
            guard !reduceMotion else {
                images = nil
                if !notebook.isHoldingTurn { notebook.finishTurn(revision: revision) }
                return
            }
            if imageRevision != revision {
                guard
                  let left = snapshot(previousLeft + (backward ? 1 : 0)),
                  let front = snapshot(previousLeft + (backward ? 0 : 1)),
                  let reverse = snapshot(notebook.reader.leftIndex + (backward ? 1 : 0)) else {
                    images = nil
                    notebook.finishTurn(revision: revision, completed: false)
                    return
                }
                progress = notebook.turnProgress
                images = NotebookCurlImages(left: left, front: front, reverse: reverse)
                imageRevision = revision
            }
            guard !notebook.isHoldingTurn else { return }
            await Task.yield()
            let target = notebook.turnWillComplete ? 1.0 : 0.0
            let duration = max(0.16, 0.6 * abs(target - progress))
            withAnimation(.easeOut(duration: duration)) { progress = target }
            do { try await Task.sleep(for: .seconds(duration)) }
            catch { return }
            guard revision == notebook.turnRevision else { return }
            images = nil
            notebook.finishTurn(revision: revision)
        }
    }

    private func leaf(_ index: Int) -> NotebookDialogueLeaf {
        NotebookDialogueLeaf(play: play, notebook: notebook, layout: layout, metrics: metrics, pageIndex: index)
    }

    private func snapshot(_ index: Int) -> CGImage? {
        let renderer = ImageRenderer(content: leaf(index))
        renderer.scale = 2
        return renderer.cgImage
    }
}
