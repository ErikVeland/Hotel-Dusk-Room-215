import SwiftUI

/// Door image and native controls. The session owns selection and story actions.
struct OriginalDoorView: View {
    @ObservedObject var play: OriginalPlaySession
    var interactive = true
    @State private var showsInventory = false

    var body: some View {
        if showsInventory, interactive {
            OriginalInventoryView(play: play, onSelect: { item in
                showsInventory = false
                play.useItemAtDoor(item)
            }, onClose: { showsInventory = false })
        } else {
            VStack {
                if let image = play.doorImage?.image {
                    OriginalInspectionImage(image: image, selected: play.door?.selected != nil) { point in
                        if interactive { play.selectDoorComponent(x: Int(point.x), y: Int(point.y), confirmImmediately: true) }
                        else { play.advanceDialogue() }
                    }
                }
                if interactive {
                    Text("Tap an object to interact. Choose an item first to use it.")
                        .font(NovelStyle.caption)
                        .foregroundStyle(NovelStyle.fadedInk)
                    if let item = play.door?.item { OriginalInventoryItemLabel(item: item) }
                    HStack {
                        Button("Back") { play.leaveDoor() }
                        Button("Items") { showsInventory = true }
                        if play.door?.item != nil { Button("Cancel") { play.useItemAtDoor(nil) } }
                    }
                }
            }.buttonStyle(BookTextButtonStyle())
        }
    }
}
