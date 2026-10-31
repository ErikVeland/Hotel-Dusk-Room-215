import SwiftUI

struct OriginalFloorPlanView: View {
    let image: CGImage
    let exploration: OriginalMapExploration
    @AppStorage("hdGraphicsEnabled") private var hdGraphicsEnabled = true

    var body: some View {
        ZStack {
            Color.black
            Image(decorative: image, scale: 1)
                .resizable().interpolation(hdGraphicsEnabled ? .high : .none)
                .frame(width: CGFloat(image.artworkWidth), height: CGFloat(image.artworkHeight))
                .frame(width: 192, height: 256, alignment: .topLeading)
                .offset(x: CGFloat(exploration.mapBitmapOffset.x), y: CGFloat(exploration.mapBitmapOffset.y))
            OriginalMapPlayerIndicator(facing: exploration.facing)
                .position(x: CGFloat(exploration.mapPlayerPoint.x), y: CGFloat(exploration.mapPlayerPoint.y))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(width: 192, height: 256)
        .clipped()
    }
}

struct OriginalMapViewCone: Shape {
    let facing: Float
    let fieldOfView: Float

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let angle = Double.pi / 2 - Double(facing)
        let halfAngle = Double(fieldOfView) / 2
        return Path { path in
            path.move(to: centre)
            path.addArc(center: centre, radius: min(rect.width, rect.height) / 2,
                startAngle: .radians(angle - halfAngle), endAngle: .radians(angle + halfAngle), clockwise: false)
            path.closeSubpath()
        }
    }
}

private struct OriginalMapPlayerIndicator: View {
    let facing: Float
    private let colour = Color(red: 0.85, green: 0.12, blue: 0.08)

    var body: some View {
        let cone = OriginalMapViewCone(facing: facing,
            fieldOfView: OriginalMapExploration.walkingHorizontalFieldOfView)
        let arrow = Path { path in
            path.move(to: CGPoint(x: 42, y: 25))
            path.addLine(to: CGPoint(x: 48, y: 35))
            path.addLine(to: CGPoint(x: 42, y: 32))
            path.addLine(to: CGPoint(x: 36, y: 35))
            path.closeSubpath()
        }
        ZStack {
            cone.fill(RadialGradient(colors: [colour.opacity(0.26), colour.opacity(0.04)],
                center: .center, startRadius: 5, endRadius: 42))
            cone.stroke(colour.opacity(0.45), lineWidth: 0.75)
            arrow.fill(colour)
                .overlay {
                    arrow.stroke(.white, style: StrokeStyle(lineWidth: 1, lineJoin: .round))
                }
                .rotationEffect(.radians(Double.pi - Double(facing)))
            Circle()
                .fill(colour)
                .overlay { Circle().stroke(.white, lineWidth: 1.5) }
                .frame(width: 9, height: 9)
        }
        .frame(width: 84, height: 84)
        .shadow(color: .black.opacity(0.4), radius: 0.8, y: 0.5)
    }
}
