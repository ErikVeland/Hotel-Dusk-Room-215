import SwiftUI
import CoreGraphics

/// Visible text from an original dialogue page. Glyph bytes are shown as
/// Latin-1. Colour and participant metadata survive into the notebook.
struct OriginalDialogueLines {
    struct Run: Hashable {
        let text: String
        let colour: UInt8
        let person: Int32?

        init(text: String, colour: UInt8, person: Int32? = nil) {
            self.text = text
            self.colour = colour
            self.person = person
        }
    }
    let lines: [[Run]]

    init(page: OriginalDialoguePacket.Page, person: Int32? = nil) {
        var lines: [[Run]] = [[]]
        var person = person
        var colour: UInt8 = 0, bytes: [UInt8] = []
        func flush() {
            guard !bytes.isEmpty else { return }
            lines[lines.count - 1].append(Run(text: String(bytes: bytes, encoding: .isoLatin1) ?? "", colour: colour, person: person))
            bytes = []
        }
        for token in page.tokens {
            switch token.kind {
            case .glyph(10): flush(); lines.append([])
            case .glyph(let byte): bytes.append(byte)
            case .control(.color(let value)): flush(); colour = value
            case .control(.portraitMetadata(let value, _)): flush(); person = value
            case .control: break
            }
        }
        flush()
        while let last = lines.last, last.isEmpty { lines.removeLast() }
        self.lines = lines
    }

    var isEmpty: Bool { lines.allSatisfy { $0.allSatisfy { $0.text.trimmingCharacters(in: .whitespaces).isEmpty } } }
}

/// The original entrance panels, rotated from DS framebuffer orientation to
/// the right-handed book page (raw x becomes 255 − page y).
@MainActor
enum OriginalEntrancePanels {
    private static var cache: [String: CGImage] = [:]

    static func image(upper: Bool, panel: Int) -> CGImage? {
        let path = "trick/entrance/\(upper ? "u" : "d")0\(min(max(panel, 0), 2) + 1).bin"
        if let cached = cache[path] { return cached }
        guard let bitmap = try? OriginalBitmapLibrary.bundled().load(path: path),
              let image = rotated(bitmap) else { return nil }
        cache[path] = image
        return image
    }

    private static func rotated(_ bitmap: OriginalBitmap) -> CGImage? {
        rotated(rgba: bitmap.rgba(transparentPaletteZero: false), width: bitmap.width, height: bitmap.height)
    }

    /// Source pixel (column c, row r) goes to page (x: r, y: width − 1 − c).
    static func rotated(rgba: Data, width sourceWidth: Int, height sourceHeight: Int) -> CGImage? {
        let source = [UInt8](rgba)
        let width = sourceHeight, height = sourceWidth
        var output = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let from = (x * sourceWidth + (sourceWidth - 1 - y)) * 4
                let to = (y * width + x) * 4
                output[to..<to + 4] = source[from..<from + 4]
            }
        }
        guard let provider = CGDataProvider(data: Data(output) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

struct OriginalEntrancePanelView: View {
    @ObservedObject var play: OriginalPlaySession
    let upper: Bool

    var body: some View {
        if let scene = play.entrance {
            GeometryReader { proxy in
                let size = fittedSize(in: proxy.size)
                ZStack {
                    if scene.sceneVisible, let image = OriginalEntrancePanels.image(upper: upper, panel: scene.panel) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.none)
                    } else {
                        Color.black
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .onPageTap { point in
                    guard !upper else { return }
                    play.touchEntrance(pageX: Int(point.x / size.width * 192),
                                       pageY: Int(point.y / size.height * 256))
                }
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }

    private func fittedSize(in space: CGSize) -> CGSize {
        let scale = max(0, min((space.width - 16) / 192, (space.height - 36) / 256))
        return CGSize(width: 192 * scale, height: 256 * scale)
    }

}

/// Process 24 on the touch page: `bell02` (the counter) under `bell01` (the
/// bell, palette index 0 transparent), both drawn on the 3D screen by
/// 0x021FD7B4. The bell's swing (+0x444) and the trick-button sprites are
/// not drawn. Touch targets stay invisible.
struct OriginalBellPageView: View {
    @ObservedObject var play: OriginalPlaySession
    let upper: Bool
    private static var images: [String: CGImage] = [:]

    private static func image(_ name: String) -> CGImage? {
        if let cached = images[name] { return cached }
        guard let bitmap = try? OriginalBitmapLibrary.bundled().loadLinear(path: "trick/bell/\(name).bin"),
              let image = OriginalEntrancePanels.rotated(rgba: bitmap.rgba(transparentPaletteZero: name == "bell01"),
                                                         width: bitmap.width, height: bitmap.height) else { return nil }
        images[name] = image
        return image
    }

    var body: some View {
        if let scene = play.bell, !upper {
            VStack(spacing: 8) {
                GeometryReader { proxy in
                    let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                    let size = CGSize(width: 192 * scale, height: 256 * scale)
                    ZStack(alignment: .topLeading) {
                        ForEach(["bell02", "bell01"], id: \.self) { name in
                            if let image = Self.image(name) {
                                Image(decorative: image, scale: 1).resizable().interpolation(.none)
                                    .frame(width: size.width, height: size.height)
                            }
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .contentShape(Rectangle())
                    .onPageTap { point in
                        guard scale > 0 else { return }
                        play.touchEntrance(pageX: Int(point.x / scale), pageY: Int(point.y / scale))
                    }
                    .notebookPhotograph()
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                HStack {
                    Button("Back") { play.touchEntrance(pageX: 172, pageY: 240) }
                        .disabled(!scene.quitEnabled)
                    Button(scene.awaitingTouch ? "Ring bell" : "Wait…") {
                        play.touchEntrance(pageX: 96, pageY: 76)
                    }
                    .disabled(!scene.awaitingTouch)
                }
                .buttonStyle(BookTextButtonStyle())
            }
        }
    }

}

/// Shown where the recovered game ends or a system is missing.
struct OriginalPlayStatusView: View {
    @ObservedObject var session: GameSession
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack(spacing: 16) {
            switch play.runner.phase {
            case .exploration:
                Text("End of the recovered opening").font(NovelStyle.title)
                Text("The playable route ends here. Further exploration and conversations are not available yet.")
                    .font(NovelStyle.body)
            case .halted(let halt):
                Text("Play stopped").font(NovelStyle.title)
                Text(halt.reason).font(NovelStyle.body)
                Text("\(halt.program)\(halt.eventIndex.map { ", event \($0)" } ?? "")\(halt.sourceOffset.map { ", offset \($0)" } ?? "")")
                    .font(NovelStyle.document)
                    .foregroundStyle(NovelStyle.fadedInk)
            default:
                EmptyView()
            }
            if session.resumeSave != nil {
                Button("Return to last checkpoint") { session.continueSavedGame() }
                    .buttonStyle(BookTextButtonStyle())
            }
            if let error = session.saveError { Text(error).font(NovelStyle.caption) }
            Button("Return to title") { session.endOriginalGame() }
                .buttonStyle(BookTextButtonStyle())
        }
        .multilineTextAlignment(.center)
    }
}

/**
 * Ordinary choices and chapter review answers retain their original order.
 * The original menu graphics are not drawn yet.
 */
struct OriginalChoiceView: View {
    @ObservedObject var play: OriginalPlaySession
    let choices: [OriginalEventRunner.Choice]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(choices, id: \.id) { choice in
                Button(choice.label) { play.choose(choice.id) }
                    .buttonStyle(BookTextButtonStyle())
            }
        }
    }
}

/// Process 25. The blank card `signnote` is shown, and each field reveals the
/// completed card `signnote02` up to its stroke length, as the draw at
/// 0x021FD728 grows each field's quad. Fades and the pen sprite are not drawn.
struct OriginalSignPageView: View {
    @ObservedObject var play: OriginalPlaySession
    let upper: Bool
    @State private var dragging = false
    private static var images: [String: CGImage] = [:]

    private static func image(_ name: String) -> CGImage? {
        if let cached = images[name] { return cached }
        guard let bitmap = try? OriginalBitmapLibrary.bundled().loadLinear(path: "trick/sign/\(name).bin"),
              let image = OriginalEntrancePanels.rotated(rgba: bitmap.rgba(transparentPaletteZero: false),
                                                         width: bitmap.width, height: bitmap.height) else { return nil }
        images[name] = image
        return image
    }

    var body: some View {
        if let scene = play.sign, !upper {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                let size = CGSize(width: 192 * scale, height: 256 * scale)
                ZStack(alignment: .topLeading) {
                    if let blank = Self.image("signnote") {
                        Image(decorative: blank, scale: 1).resizable().interpolation(.none)
                            .frame(width: size.width, height: size.height)
                    }
                    if let written = Self.image("signnote02") {
                        Image(decorative: written, scale: 1).resizable().interpolation(.none)
                            .frame(width: size.width, height: size.height)
                            .mask(alignment: .topLeading) { reveal(scene.strokes, scale: scale) }
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    guard scale > 0 else { return }
                    let x = Int(drag.location.x / scale), y = Int(drag.location.y / scale)
                    if !dragging { dragging = true; play.touchEntrance(pageX: x, pageY: y) }
                    play.holdTouch(pageX: x, pageY: y)
                }.onEnded { _ in
                    dragging = false
                    play.releaseTouch()
                })
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }

    private func reveal(_ strokes: [Int16], scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<4, id: \.self) { field in
                Rectangle()
                    .frame(width: CGFloat(strokes[field]) * scale,
                           height: CGFloat(OriginalSignProcess.fieldHeight[field] + 1) * scale)
                    .offset(x: CGFloat(OriginalSignProcess.fieldX[field]) * scale,
                            y: CGFloat(OriginalSignProcess.fieldY[field]) * scale)
            }
        }
    }
}

/// The question menu of event modes 7 and 8: the partner's open keywords
/// from the chapter `.ttk`, and leaving the conversation. The original menu
/// graphics are not drawn.
struct OriginalQuestionMenuView: View {
    @ObservedObject var play: OriginalPlaySession
    let topics: [OriginalEventRunner.Topic]
    @State private var showsInventory = false

    var body: some View {
        if showsInventory {
            OriginalInventoryView(play: play, actionTitle: "Show item", onSelect: { item in
                showsInventory = false
                play.showItemInConversation(item)
            }, onClose: { showsInventory = false })
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    Text(topics.isEmpty ? "No questions" : "Ask about").font(NovelStyle.caption).foregroundStyle(NovelStyle.fadedInk)
                    ForEach(topics, id: \.keyword) { topic in
                        Button(topic.label) { play.ask(topic.keyword) }
                            .buttonStyle(BookTextButtonStyle())
                    }
                    InkRule().padding(.vertical, 6)
                    Button("Notebook") { play.openNotebook() }
                        .buttonStyle(BookTextButtonStyle())
                    Button("Items") { showsInventory = true }
                        .buttonStyle(BookTextButtonStyle())
                    Button("Leave") { play.leaveConversation() }
                        .buttonStyle(BookTextButtonStyle())
                }
            }
        }
    }
}
