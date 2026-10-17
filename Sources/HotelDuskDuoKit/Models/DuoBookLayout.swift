import SwiftUI

/// Keeps the page boundary at the display centre, even with asymmetric safe areas.
struct DuoBookLayout {
    enum Page: String, Identifiable {
        case exploration, touch
        var id: Self { self }
    }

    let size: CGSize
    let safeArea: EdgeInsets
    let handedness: Handedness

    var pages: [Page] {
        handedness == .rightHanded ? [.exploration, .touch] : [.touch, .exploration]
    }

    func frame(at index: Int) -> CGRect {
        CGRect(x: CGFloat(index) * size.width / 2, y: 0,
               width: size.width / 2, height: size.height)
    }

    func insets(at index: Int) -> EdgeInsets {
        EdgeInsets(top: max(12, safeArea.top),
                   leading: index == 0 ? max(12, safeArea.leading) : 16,
                   bottom: max(12, safeArea.bottom),
                   trailing: index == 0 ? 16 : max(12, safeArea.trailing))
    }
}
