import SwiftUI

/**
 * Door image and native controls. The session owns selection and story actions.
 */
struct OriginalDoorView: View {
    @ObservedObject var play: OriginalPlaySession
    var interactive = true
    @State private var showsInventory = false

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / 192, proxy.size.height / 256)
                if let image = play.doorImage?.image {
                    Image(decorative: image, scale: 1).interpolation(.none)
                        .frame(width: 192, height: 256)
                        .contentShape(Rectangle())
                        .gesture(SpatialTapGesture().onEnded { value in
                            if interactive { play.selectDoorComponent(x: Int(value.location.x), y: Int(value.location.y)) }
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
                            play.useItemAtDoor(item)
                            showsInventory = false
                        }
                    }
                    Button("Cancel") { showsInventory = false }
                } else {
                    if let item = play.door?.item {
                        Text(play.itemNames[item] ?? String(item)).font(NovelStyle.caption)
                    }
                    HStack {
                        Button("Back") { play.leaveDoor() }
                        Button("Items") { showsInventory = true }
                        Button(play.door?.item == nil ? "Look" : "Use") { play.confirmDoorComponent() }
                            .disabled(play.door?.selected == nil)
                        if play.door?.item != nil { Button("Cancel") { play.useItemAtDoor(nil) } }
                    }
                }
            }
        }.buttonStyle(BookTextButtonStyle())
    }
}
