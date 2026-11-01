import SwiftUI

/// Displays fixed-size artwork with pinch zoom, swipe panning, and mapped taps.
struct OriginalZoomableCanvas<Content: View>: View {
    let contentSize: CGSize
    var onTap: ((CGPoint) -> Void)?
    @ViewBuilder let content: () -> Content
    @GestureState private var isMagnifying = false
    @State private var zoom: CGFloat = 1
    @State private var zoomAtGestureStart: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var offsetAtGestureStart = CGSize.zero

    init(contentSize: CGSize, onTap: ((CGPoint) -> Void)? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.contentSize = contentSize
        self.onTap = onTap
        self.content = content
    }

    private func boundedOffset(_ candidate: CGSize, zoom: CGFloat, viewport: CGSize) -> CGSize {
        let limitX = max(0, (contentSize.width * zoom - viewport.width) / 2)
        let limitY = max(0, (contentSize.height * zoom - viewport.height) / 2)
        return CGSize(width: min(limitX, max(-limitX, candidate.width)),
                      height: min(limitY, max(-limitY, candidate.height)))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                content()
                    .frame(width: contentSize.width, height: contentSize.height)
                    .scaleEffect(zoom)
                    .offset(offset)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    let canPan = contentSize.width * zoom > proxy.size.width
                        || contentSize.height * zoom > proxy.size.height
                    guard canPan else { return }
                    offset = boundedOffset(
                        CGSize(width: offsetAtGestureStart.width + value.translation.width,
                               height: offsetAtGestureStart.height + value.translation.height),
                        zoom: zoom, viewport: proxy.size
                    )
                }
                .onEnded { value in
                    offsetAtGestureStart = offset
                    guard !isMagnifying, OriginalPageInput.isTap(from: value.startLocation, to: value.location),
                          let onTap else { return }
                    let point = CGPoint(
                        x: (value.startLocation.x - proxy.size.width / 2 - offset.width) / zoom + contentSize.width / 2,
                        y: (value.startLocation.y - proxy.size.height / 2 - offset.height) / zoom + contentSize.height / 2
                    )
                    guard point.x >= 0, point.y >= 0,
                          point.x < contentSize.width, point.y < contentSize.height else { return }
                    onTap(point)
                })
            .simultaneousGesture(MagnifyGesture()
                .updating($isMagnifying) { _, state, _ in state = true }
                .onChanged { value in
                    zoom = min(4, max(1, zoomAtGestureStart * value.magnification))
                    offset = boundedOffset(offset, zoom: zoom, viewport: proxy.size)
                }
                .onEnded { _ in
                    zoomAtGestureStart = zoom
                    offsetAtGestureStart = offset
                })
            .onDisappear {
                zoom = 1
                zoomAtGestureStart = 1
                offset = .zero
                offsetAtGestureStart = .zero
            }
        }
        .clipped()
    }
}
