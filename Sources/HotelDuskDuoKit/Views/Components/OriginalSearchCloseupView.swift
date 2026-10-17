import SwiftUI

/**
 * Shows the original close-up image and forwards selection to the session.
 */
struct OriginalSearchCloseupView: View {
    @ObservedObject var play: OriginalPlaySession
    var interactive = true
    @State private var showsInventory = false

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / 192, proxy.size.height / 256)
                if let image = play.closeupDetailImage?.image ?? play.closeupImage?.image {
                    Image(decorative: image, scale: 1).interpolation(.none)
                        .frame(width: 192, height: 256)
                        .contentShape(Rectangle())
                        .gesture(SpatialTapGesture().onEnded { value in
                            if interactive { play.selectCloseupComponent(x: Int(value.location.x), y: Int(value.location.y)) }
                            else { play.advanceDialogue() }
                        })
                        .scaleEffect(scale)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
            if interactive {
                if showsInventory {
                    ForEach((try? play.runner.game.inventory.items) ?? [], id: \.self) { item in
                        Button(play.itemNames[item] ?? String(item)) {
                            showsInventory = false
                            play.useItemInCloseup(item)
                        }
                    }
                    Button("Cancel") { showsInventory = false }
                }
                HStack {
                    Button("Items") { showsInventory = true }
                    Button("Back") { play.leaveSearchCloseup() }
                    Button(play.searchItem == nil ? "Look" : "Use") { play.confirmCloseupComponent() }
                        .disabled(play.closeup?.selected == nil)
                }
                if let item = play.searchItem {
                    Text(play.itemNames[item] ?? String(item))
                    Button("Cancel item") { play.useItemInCloseup(nil) }
                }
            }
        }.buttonStyle(BookTextButtonStyle())
    }
}
