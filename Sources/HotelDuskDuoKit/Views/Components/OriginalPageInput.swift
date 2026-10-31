import SwiftUI

/// Converts touches on the displayed image to original page pixels.
struct OriginalPageInput {
    let scale: CGFloat
    var size: CGSize { CGSize(width: 192 * scale, height: 256 * scale) }

    init(available: CGSize) {
        scale = max(0, min(available.width / 192, available.height / 256))
    }

    func point(_ location: CGPoint) -> CGPoint? {
        guard scale > 0, location.x.isFinite, location.y.isFinite,
              location.x >= 0, location.y >= 0,
              location.x < size.width, location.y < size.height else { return nil }
        return CGPoint(x: location.x / scale, y: location.y / scale)
    }

    /// Small finger movement must not cancel a deliberate object tap.
    static func isTap(from start: CGPoint, to end: CGPoint) -> Bool {
        hypot(end.x - start.x, end.y - start.y) <= 22
    }
}

extension View {
    func onPageTap(_ action: @escaping (CGPoint) -> Void) -> some View {
        contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onEnded { value in
                    guard OriginalPageInput.isTap(from: value.startLocation, to: value.location) else { return }
                    action(value.startLocation)
                })
    }
}

/// The hit surface uses the displayed dimensions, with no gesture inside a scale transform.
struct OriginalInspectionImage: View {
    let image: CGImage
    let selected: Bool
    let action: (CGPoint) -> Void
    @State private var lastPoint: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            let input = OriginalPageInput(available: CGSize(width: max(0, proxy.size.width - 16),
                                                       height: max(0, proxy.size.height - 36)))
            Image(decorative: image, scale: 1)
                .resizable().interpolation(image.width > 192 ? .high : .none)
                .frame(width: input.size.width, height: input.size.height)
                .overlay(alignment: .topLeading) {
                    if selected, let point = lastPoint {
                        Image(systemName: "hand.point.up.fill")
                            .font(.system(size: 24)).foregroundStyle(.white)
                            .shadow(color: .black, radius: 2)
                            .position(x: point.x * input.scale, y: point.y * input.scale)
                            .allowsHitTesting(false)
                    }
                }
                .onPageTap { location in
                    guard let point = input.point(location) else { return }
                    lastPoint = point
                    action(point)
                }
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}
