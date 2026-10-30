import SwiftUI

struct OriginalVendingMachineView: View {
    @ObservedObject var play: OriginalPlaySession
    let screen: UInt8

    var body: some View {
        if let process = play.vendingMachine {
            if screen == 0 { keypad(process) }
            else { catalogue(process) }
        }
    }

    private func catalogue(_ process: OriginalVendingMachineProcess) -> some View {
        VStack(spacing: 12) {
            Text("Vending machine").font(NovelStyle.body)
            if let item = process.selectedItem, let image = play.vendingMachineProducts[item] {
                Image(decorative: image, scale: 1)
                    .resizable().scaledToFit()
                Text("Collecting item…").font(NovelStyle.body)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(OriginalVendingMachineProcess.products, id: \.code) { product in
                        VStack(spacing: 4) {
                            if let image = play.vendingMachineProducts[product.itemID] {
                                Image(decorative: image, scale: 1)
                                    .resizable().scaledToFit()
                                    .frame(maxHeight: 100)
                            }
                            Text("\(product.code)").font(NovelStyle.body)
                            if !process.isAvailable(product) {
                                Text("Sold out").font(.caption)
                            }
                        }
                        .opacity(process.isAvailable(product) ? 1 : 0.45)
                    }
                }
                Text("Insert a coin, enter the item number, then press enter.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func keypad(_ process: OriginalVendingMachineProcess) -> some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let scale = max(0, min(proxy.size.width / 192, proxy.size.height / 256))
                ZStack(alignment: .topLeading) {
                    if let image = play.vendingMachineImage {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .frame(width: 192 * scale, height: 256 * scale)
                    }
                    Text(process.digits.map(String.init).joined())
                        .font(.system(size: 28 * scale, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(width: 144 * scale, height: 32 * scale)
                        .position(x: 96 * scale, y: 92 * scale)
                    control("Insert coin", action: .insertCoin, width: 44 * scale, height: 44 * scale)
                        .position(x: 148 * scale, y: 36 * scale)
                    ForEach(0..<10, id: \.self) { index in
                        let digit = index == 9 ? 0 : index + 1
                        control("\(digit)", action: .digit(digit), width: 36 * scale, height: 36 * scale)
                            .position(x: CGFloat(36 + index % 4 * 40) * scale,
                                      y: CGFloat(142 + index / 4 * 40) * scale)
                    }
                    control("Enter", action: .confirm, width: 72 * scale, height: 36 * scale)
                        .position(x: 136 * scale, y: 222 * scale)
                }
                .frame(width: 192 * scale, height: 256 * scale)
                .opacity(process.opacity)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            Text(status(process)).font(.caption).frame(height: 32)
            HStack {
                Button("Back") { play.vendingMachineAction(.quit) }
                Spacer()
                Button("Return coin") { play.vendingMachineAction(.returnCoin) }
                    .disabled(!process.coinInserted)
            }
            .disabled(process.phase != .acceptingInput)
        }
    }

    private func control(_ label: String, action: OriginalVendingMachineProcess.Action,
                         width: CGFloat, height: CGFloat) -> some View {
        Button { play.vendingMachineAction(action) } label: {
            Color.clear.frame(width: width, height: height).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .disabled(play.vendingMachine?.phase != .acceptingInput)
    }

    private func status(_ process: OriginalVendingMachineProcess) -> String {
        if process.rejectedCode { return "Item unavailable. Try another number." }
        switch process.phase {
        case .insertingCoin: return "Inserting coin…"
        case .dispensing: return "Collecting item…"
        case .fadingOut where process.selectedItem != nil: return "Collecting item…"
        default: return process.coinInserted ? "Coin inserted" : "Insert a coin"
        }
    }
}
