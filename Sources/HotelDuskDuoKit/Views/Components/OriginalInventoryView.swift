import SwiftUI

/// Looking at an item does not select it for use or run its original process.
/// The player confirms those actions from the inspection view.
struct OriginalInventoryView: View {
    @ObservedObject var play: OriginalPlaySession
    var actionTitle = "Use item"
    var onSelect: ((UInt8) -> Void)?
    let onClose: () -> Void
    @State private var inspectedItem: UInt8?

    private var items: [UInt8] { (try? play.runner.game.inventory.items) ?? [] }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("ITEMS").font(NovelStyle.imprint).tracking(2)
                Spacer()
                Button("Close") { close() }
            }
            InkRule()
            if let item = inspectedItem, items.contains(item) {
                Button("‹  All items") { inspectedItem = nil }
                    .frame(maxWidth: .infinity, alignment: .leading)
                ScrollView {
                    OriginalInventoryInspection(item: item)
                        .padding(.vertical, 12)
                }
                if let onSelect {
                    Button(actionTitle) {
                        play.endInventoryBrowsing()
                        onSelect(item)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if items.isEmpty {
                Spacer()
                Text("No items in your inventory.")
                    .font(NovelStyle.body).multilineTextAlignment(.center)
                Spacer()
            } else {
                Text("Select an item to inspect it.")
                    .font(NovelStyle.caption).foregroundStyle(NovelStyle.fadedInk)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 16) {
                        ForEach(items, id: \.self) { item in
                            Button { inspectedItem = item } label: {
                                VStack(spacing: 8) {
                                    OriginalInventoryItemImage(item: item)
                                        .frame(height: 88)
                                    Text(OriginalInventoryArtwork.shared.name(for: item))
                                        .font(NovelStyle.label)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, minHeight: 132, alignment: .top)
                                .padding(8)
                                .background(NovelStyle.lightPaper.opacity(0.7))
                                .overlay(Rectangle().strokeBorder(NovelStyle.rule.opacity(0.4), lineWidth: 0.5))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Inspect \(OriginalInventoryArtwork.shared.name(for: item))")
                        }
                    }
                    .padding(2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(NovelStyle.ink)
        .buttonStyle(BookTextButtonStyle())
        .onAppear { play.beginInventoryBrowsing() }
        .onDisappear { play.endInventoryBrowsing() }
        .onChange(of: items) { _, items in
            if let inspectedItem, !items.contains(inspectedItem) { self.inspectedItem = nil }
        }
    }

    private func close() {
        play.endInventoryBrowsing()
        onClose()
    }
}

struct OriginalInventoryInspection: View {
    let item: UInt8
    @State private var enlarged = false

    var body: some View {
        VStack(spacing: 20) {
            Text(OriginalInventoryArtwork.shared.name(for: item))
                .font(NovelStyle.title).multilineTextAlignment(.center)
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    let side = enlarged ? 512.0 : min(256, max(0, proxy.size.width - 16))
                    OriginalInventoryItemImage(item: item)
                        .frame(width: side, height: side)
                        .padding(8)
                        .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
                }
            }
            .frame(height: enlarged ? 360 : 280)
            .background(NovelStyle.lightPaper)
            if !OriginalInventoryArtwork.shared.hasOriginalPicture(for: item) {
                Text("No original picture is available for this item.")
                    .font(NovelStyle.caption).multilineTextAlignment(.center)
            }
            Button(enlarged ? "Reduce image" : "Enlarge image") { enlarged.toggle() }
                .buttonStyle(BookTextButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(NovelStyle.ink)
        .id(item)
    }
}

struct OriginalInventoryItemImage: View {
    let item: UInt8

    var body: some View {
        if let image = try? OriginalInventoryArtwork.shared.image(for: item) {
            Image(decorative: image, scale: 1)
                .resizable().interpolation(.none).scaledToFit()
                .accessibilityLabel(OriginalInventoryArtwork.shared.name(for: item))
        } else {
            VStack(spacing: 6) {
                Image(systemName: "photo").font(.system(size: 36))
                Text("Image unavailable").font(NovelStyle.caption)
            }
            .foregroundStyle(NovelStyle.fadedInk)
        }
    }
}

struct OriginalInventoryItemLabel: View {
    let item: UInt8

    var body: some View {
        HStack(spacing: 8) {
            OriginalInventoryItemImage(item: item).frame(width: 40, height: 40)
            Text(OriginalInventoryArtwork.shared.name(for: item)).font(NovelStyle.caption)
        }
        .accessibilityElement(children: .combine)
    }
}
