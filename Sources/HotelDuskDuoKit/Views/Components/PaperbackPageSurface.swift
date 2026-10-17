import SwiftUI
import CoreGraphics

enum PaperPageSide: Equatable {
    case left, right

    var seed: UInt64 { self == .left ? 0x1979_0215 : 0x1979_0219 }
}

/// The printed sheet stays still; its shallow bow changes the reflected light.
/// No content transform can move a puzzle piece away from its touch target.
struct PaperbackPageSurface<Content: View>: View {
    @ObservedObject var hingeManager: DuoHingeManager
    let side: PaperPageSide
    var isVisible = true
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var settling = PaperSettlingResponse()
    @State private var hasSettledOnPresentation = false

    var body: some View {
        ZStack {
            PaperSurface(side: side)
            content()
            TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                    paused: !settling.isActive || !canSettle)) { timeline in
                PaperCurvatureLight(side: side,
                                    hingeAngle: hingeManager.hingeAngleDegrees,
                                    flex: reduceMotion ? 0 : settling.displacement(at: timeline.date))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onChange(of: hingeManager.hingeAngleDegrees) { oldAngle, newAngle in
            guard canSettle, abs(newAngle - oldAngle) >= 0.4 else { return }
            settling.respond(to: min(1, 0.2 + abs(newAngle - oldAngle) / 35))
        }
        .onChange(of: hingeManager.foldState) { previous, current in
            if current == .closed {
                settling.stop()
            } else if previous == .closed, canSettle {
                // The sheet keeps its grain. Only its flex differs each time.
                settling.newOpening(seed: UInt64.random(in: 1...UInt64.max) ^ side.seed)
                hasSettledOnPresentation = true
            }
        }
        .onChange(of: isVisible) { _, visible in
            if !visible { settling.stop() }
            else { settleOnPresentationIfNeeded() }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { settling.stop() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { settling.stop() }
            else { settleOnPresentationIfNeeded() }
        }
        .task(id: settling.event) {
            guard settling.isActive else { return }
            do { try await Task.sleep(for: .seconds(PaperSettlingResponse.duration)) }
            catch { return }
            settling.stop()
        }
        .onAppear { settleOnPresentationIfNeeded() }
        .onDisappear { settling.stop() }
    }

    private var isClosed: Bool { hingeManager.foldState == .closed }
    private var canSettle: Bool { !reduceMotion && isVisible && !isClosed && scenePhase == .active }

    private func settleOnPresentationIfNeeded() {
        // A cover-to-inner-display transition can create a new view after the
        // hinge already opened. Give that sheet a quiet initial settling pass.
        guard !hasSettledOnPresentation, canSettle else { return }
        settling.newOpening(seed: UInt64.random(in: 1...UInt64.max) ^ side.seed, magnitude: 0.4)
        hasSettledOnPresentation = true
    }
}

/// A finite, damped response. The rendering clock pauses when this reaches rest.
struct PaperSettlingResponse {
    static let duration = 1.8
    private(set) var event: UInt64 = 0
    private(set) var isActive = false
    private var started = Date.distantPast
    private var strength = 0.0
    private var frequency = 7.8
    private var phase = 0.6
    private var direction = 1.0

    mutating func newOpening(seed: UInt64, magnitude: Double = 1, at date: Date = Date()) {
        var random = PaperRandom(seed: seed)
        frequency = 6.7 + random.next() * 2.4
        phase = 0.3 + random.next() * 0.5
        direction = random.next() < 0.5 ? -1 : 1
        respond(to: (0.72 + random.next() * 0.28) * magnitude, at: date)
    }

    mutating func respond(to amount: Double, at date: Date = Date()) {
        strength = max(0, min(1, amount))
        started = date
        event &+= 1
        isActive = true
    }

    mutating func stop() { isActive = false }

    func displacement(at date: Date) -> Double {
        guard isActive else { return 0 }
        let elapsed = max(0, date.timeIntervalSince(started))
        guard elapsed < Self.duration else { return 0 }
        let envelope = exp(-elapsed * 3.2) * pow(1 - elapsed / Self.duration, 2)
        return sin(elapsed * frequency + phase) * envelope * strength * direction
    }
}

/// Broad, low-contrast lighting follows the curved sheet from binding to fore-edge.
/// The flex changes the light, not the artwork or the page's full-bleed silhouette.
struct PaperCurvatureLight: View {
    let side: PaperPageSide
    let hingeAngle: Double
    let flex: Double

    var body: some View {
        MetalBookMaterial(pass: .light, side: side, angle: hingeAngle, flex: flex)
    }
}

/// Two cached sheets of uncoated wood-pulp stock. The texture never swims or
/// regenerates during a hinge gesture, and costs no per-frame noise synthesis.
enum PaperStock {
    private static let left = make(seed: PaperPageSide.left.seed)
    private static let right = make(seed: PaperPageSide.right.seed)

    static func image(for side: PaperPageSide) -> CGImage? { side == .left ? left : right }

    private static func make(seed: UInt64) -> CGImage? {
        let width = 768
        let height = 1024
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
              let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        var random = PaperRandom(seed: seed)
        // The tooth is luminance variation within the paper, not translucent
        // clouds laid over it. Generate it once at a fine, irregular pixel scale.
        for offset in stride(from: 0, to: width * height * 4, by: 4) {
            let tooth = (random.next() - 0.5) * 13 + (random.next() - 0.5) * 4
            pixels[offset] = UInt8(max(0, min(255, 238 + tooth)))
            pixels[offset + 1] = UInt8(max(0, min(255, 230 + tooth)))
            pixels[offset + 2] = UInt8(max(0, min(255, 209 + tooth)))
            pixels[offset + 3] = 255
        }

        // Density changes over a sheet are much quieter than its surface tooth.
        for index in 0..<55 {
            let centre = CGPoint(x: random.next() * Double(width), y: random.next() * Double(height))
            let radius = 20 + random.next() * 135
            let warm = index % 3 != 0
            let color = warm ? CGColor(red: 0.54, green: 0.48, blue: 0.35, alpha: 0.004 + random.next() * 0.007)
                             : CGColor(gray: 1, alpha: 0.005 + random.next() * 0.008)
            radial(context, centre: centre, radius: radius, color: color)
        }

        // The exposed edges oxidize more than the sheltered middle of a page.
        for _ in 0..<80 {
            let edge = Int(random.next() * 4)
            let inset = pow(random.next(), 2) * 16
            let along = random.next()
            let centre: CGPoint
            switch edge {
            case 0: centre = CGPoint(x: inset, y: along * Double(height))
            case 1: centre = CGPoint(x: Double(width) - inset, y: along * Double(height))
            case 2: centre = CGPoint(x: along * Double(width), y: inset)
            default: centre = CGPoint(x: along * Double(width), y: Double(height) - inset)
            }
            radial(context, centre: centre, radius: 16 + random.next() * 53,
                   color: CGColor(red: 0.49, green: 0.42, blue: 0.28, alpha: 0.010 + random.next() * 0.016))
        }

        // Short, irregular fibres replace the old evenly spaced horizontal rules.
        for index in 0..<13000 {
            let x = random.next() * Double(width)
            let y = random.next() * Double(height)
            let length = 0.4 + pow(random.next(), 3) * 5.2
            let angle = random.next() * .pi * 2
            let alpha = 0.035 + random.next() * 0.06
            context.setStrokeColor(index % 3 == 0 ? CGColor(gray: 1, alpha: alpha * 1.8)
                                                 : CGColor(red: 0.36, green: 0.29, blue: 0.17, alpha: alpha))
            context.setLineWidth(0.25 + random.next() * 0.5)
            context.move(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
            context.strokePath()
        }

        // Sparse foxing sits in the stock, mostly toward the exposed edges.
        for _ in 0..<75 {
            let x = random.next() * Double(width)
            let y = random.next() * Double(height)
            let nearEdge = min(x, Double(width) - x, y, Double(height) - y) < 80
            let radius = 0.25 + random.next() * (nearEdge ? 1.8 : 0.6)
            radial(context, centre: CGPoint(x: x, y: y), radius: radius,
                   color: CGColor(red: 0.40, green: 0.23, blue: 0.10, alpha: nearEdge ? 0.16 : 0.065))
        }
        return context.makeImage()
    }

    private static func radial(_ context: CGContext, centre: CGPoint, radius: CGFloat, color: CGColor) {
        guard let clear = color.copy(alpha: 0),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [color, clear] as CFArray, locations: [0, 1]) else { return }
        context.drawRadialGradient(gradient, startCenter: centre, startRadius: 0,
                                   endCenter: centre, endRadius: radius, options: [])
    }
}

private struct PaperRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 1 : seed }

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / 9_007_199_254_740_992
    }
}
