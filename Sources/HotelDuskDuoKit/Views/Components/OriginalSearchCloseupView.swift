import SwiftUI

/// Shows the original close-up image and forwards selection to the session.
struct OriginalSearchCloseupView: View {
    @ObservedObject var play: OriginalPlaySession
    var interactive = true
    @State private var showsInventory = false

    var body: some View {
        if showsInventory, interactive {
            OriginalInventoryView(play: play, onSelect: { item in
                showsInventory = false
                play.useItemInCloseup(item)
            }, onClose: { showsInventory = false })
        } else {
            VStack {
                if let image = play.closeupDetailImage?.image ?? play.closeupImage?.image {
                    OriginalInspectionImage(image: image, selected: play.closeup?.selected != nil) { point in
                        if interactive { play.selectCloseupComponent(x: Int(point.x), y: Int(point.y), confirmImmediately: true) }
                        else { play.advanceDialogue() }
                    }
                }
                if interactive {
                    Text("Tap an object to interact. Choose an item first to use it.")
                        .font(NovelStyle.caption)
                        .foregroundStyle(NovelStyle.fadedInk)
                    HStack {
                        Button("Items") { showsInventory = true }
                        Button("Back") { play.leaveSearchCloseup() }
                    }
                    if let item = play.searchItem {
                        OriginalInventoryItemLabel(item: item)
                        Button("Cancel item") { play.useItemInCloseup(nil) }
                    }
                }
            }.buttonStyle(BookTextButtonStyle())
        }
    }
}
