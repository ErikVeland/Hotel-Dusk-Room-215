import Foundation
import Combine
import CoreGraphics

/// Hosts the recovered Chapter 1 opening for play-testing: the original event
/// runner, the entrance process at the DS update rate, and original audio.
/// Systems that are not recovered stop play with their source location.
@MainActor
public final class OriginalPlaySession: ObservableObject {
    /// 33,513,982 Hz / (6 × 355 × 263): the DS video update rate.
    public static let updatesPerSecond = 59.8261

    public struct EntranceScene: Equatable {
        /// Index into the original u01–u03 and d01–d03 panels.
        public var panel: Int
        public var sceneVisible: Bool
        public var awaitingHandle: Bool
    }

    public struct BellScene: Equatable {
        /// Field +0x444; the draw at 0x021FD7B4 rotates bell01 by it. The
        /// native view does not apply the rotation yet.
        public var angle: Float
        public var awaitingTouch: Bool
        public var quitEnabled: Bool
    }

    @Published public private(set) var runner: OriginalEventRunner
    @Published public private(set) var entrance: EntranceScene?
    @Published public private(set) var bell: BellScene?

    public struct SignScene: Equatable {
        public var strokes: [Int16]
        public var awaitingStroke: Bool
        public var quitEnabled: Bool
    }
    @Published public private(set) var sign: SignScene?
    private var signProcess: OriginalSignProcess?
    private var heldTouch: OriginalEntranceProcess.Touch?
    private let audio: AudioController
    private var process: OriginalEntranceProcess?
    private var bellProcess: OriginalBellProcess?
    private var bellMask: [UInt8] = []
    private var fixture: String?
    private var processReturn: Int16 = 2
    private var fadeRemaining: [Int: Int] = [:]
    private var pendingTouch: OriginalEntranceProcess.Touch?
    private var timer: Timer?
    private var isPaused = false
    private var presentedPacketOffset: Int?

    public init(runner: OriginalEventRunner, audio: AudioController, fixture: String? = nil) {
        self.runner = runner
        self.audio = audio
        self.fixture = fixture
        settle()
    }

    public static func chapterOne(audio: AudioController) throws -> OriginalPlaySession {
        var runner = try OriginalEventRunner.chapterOneArrival(catalog: .bundled(), defaults: .bundled(),
            timestamp: Int64(Date().timeIntervalSince1970))
        var fixture: String?
        #if DEBUG
        fixture = ProcessInfo.processInfo.environment["HOTEL_DUSK_FIXTURE"]
        if fixture == "R102-sign" {
            try fastForward(&runner) { if case .process(25) = $0.phase { return true }; return false }
            fixture = nil
        } else if let target = fixture.flatMap({ $0.hasPrefix("R102-event-") ? Int($0.dropFirst(11)) : nil }) {
            try fastForward(&runner) { $0.eventIndex == target }
            fixture = nil
        }
        #endif
        return OriginalPlaySession(runner: runner, audio: audio, fixture: fixture)
    }

    #if DEBUG
    /// Debug-only input record: plays the original script with fixed inputs
    /// until `stop` holds. The bell is rung to completion (return 0), the card
    /// is signed (return 0), and the first option of each prompt is taken. It
    /// replaces only the unrecovered map walk with the bell look result.
    static func fastForward(_ runner: inout OriginalEventRunner,
                            until stop: (OriginalEventRunner) -> Bool) throws {
        let table = try OriginalSearchTable.bundled(map: "R102")
        for _ in 0..<1000 where !stop(runner) {
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .exploration(2) where runner.eventIndex == nil: runner.lookInSearchView(area: 2, subarea: 2, table: table)
            case .process(56), .process(24), .process(25): runner.finishProcess(returnValue: 0)
            case .choice(let options): runner.choose(options[0].id)
            default: return
            }
        }
    }
    #endif

    /// Debug-only isolated component input, like the reference runner's
    /// diagnostic writes. `R102-bell-look` stands in for the unrecovered map
    /// walk and 3D search view: at R102 exploration it supplies the original
    /// look result for area 2, node `obj02` (subarea 2). Players never see it.
    private func applyFixture() -> Bool {
        guard fixture == "R102-bell-look", case .exploration(2) = runner.phase,
              runner.program.name == "EP1_R102", let table = try? OriginalSearchTable.bundled(map: "R102") else {
            return false
        }
        fixture = nil
        runner.lookInSearchView(area: 2, subarea: 2, table: table)
        return true
    }

    /// A tap on either page while text is shown.
    public func advanceDialogue() {
        guard !isPaused else { return }
        switch runner.phase {
        case .dialogue, .itemNotice: break
        default: return
        }
        runner.acknowledgeDialogue()
        settle()
    }

    /// The player picked an option of an original choice prompt.
    public func choose(_ id: UInt16) {
        guard !isPaused, case .choice = runner.phase else { return }
        runner.choose(id)
        settle()
    }

    /// The player pressed the pulsing interrupt icon during an armed page.
    public func interrupt() {
        guard !isPaused, runner.interruptAvailable else { return }
        runner.pressInterrupt()
        settle()
    }

    /// The player asked the partner about a keyword in the question menu.
    public func ask(_ keyword: Int16) {
        guard !isPaused, case .questions = runner.phase else { return }
        runner.ask(keyword)
        settle()
    }

    /// The player closed the question menu.
    public func leaveConversation() {
        guard !isPaused, case .questions = runner.phase else { return }
        runner.leave()
        settle()
    }

    /// A new press on the touch page, in rotated page pixels (192 × 256).
    public func touchEntrance(pageX: Int, pageY: Int) {
        guard process != nil || bellProcess != nil || signProcess != nil,
              (0..<192).contains(pageX), (0..<256).contains(pageY) else { return }
        pendingTouch = OriginalEntranceProcess.Touch(x: 255 - pageY, y: pageX)
    }

    /// The held touch on the touch page, in rotated page pixels; nil on release.
    public func holdTouch(pageX: Int, pageY: Int) {
        guard signProcess != nil else { return }
        heldTouch = OriginalEntranceProcess.Touch(x: 255 - min(max(pageY, 0), 255), y: min(max(pageX, 0), 191))
    }

    public func releaseTouch() { heldTouch = nil }

    public func pause() {
        isPaused = true
        stopTimer()
        audio.pause()
    }

    public func resume() {
        guard isPaused else { return }
        isPaused = false
        audio.resume()
        settle()
    }

    public func stop() {
        stopTimer()
        audio.stop()
    }

    /// Starts whatever the runner's current phase needs from the host.
    private func settle() {
        switch runner.phase {
        case .dialogue(let packet):
            stopTimer()
            if presentedPacketOffset != packet.sourceOffset {
                presentedPacketOffset = packet.sourceOffset
                applyAudioControls(packet)
            }
        case .process(24):
            if bellProcess == nil {
                do {
                    bellMask = try OriginalBitmapLibrary.bundled().loadLinear(path: "trick/bell/bell01.bin").indices
                } catch {
                    runner.halt("Bell resources could not be loaded: \(error)")
                    return settle()
                }
                bellProcess = OriginalBellProcess()
                processReturn = 2
                for fade in OriginalBellProcess.initialFades { fadeRemaining[fade.screen] = Int(fade.duration) }
                bell = BellScene(angle: 0, awaitingTouch: false, quitEnabled: false)
            }
            startTimer()
        case .process(25):
            if signProcess == nil {
                signProcess = OriginalSignProcess()
                processReturn = 2
                sign = SignScene(strokes: [0, 0, 0, 0], awaitingStroke: false, quitEnabled: false)
            }
            startTimer()
        case .process(let id):
            guard id == 56 else {
                runner.halt("Process \(id) is not recovered")
                return settle()
            }
            if process == nil {
                process = OriginalEntranceProcess()
                processReturn = 2
                // The normal initializer starts this one-update fade.
                let fade = OriginalEntranceProcess.initialFade
                fadeRemaining[fade.screen] = Int(fade.duration)
                entrance = EntranceScene(panel: 0, sceneVisible: true, awaitingHandle: false)
            }
            startTimer()
        case .waiting:
            startTimer()
        case .exploration:
            stopTimer()
            if applyFixture() { settle() }
        case .choice, .itemNotice, .questions, .halted:
            stopTimer()
        }
    }

    /// Text controls %m0NN start BGM_NN. The music table at 0x0200AD94 maps
    /// BGM_NN to SDAT sequence NN - 1, whose symbol is SEQ_BGM_NN. Only mode 0
    /// is acted on; the other mode values are not recovered.
    private func applyAudioControls(_ packet: OriginalDialoguePacket) {
        for page in packet.pages {
            for token in page.tokens {
                guard case .control(.music(let mode, let name)) = token.kind, mode == 0 else { continue }
                audio.playBGM(title: "SEQ_" + name)
            }
        }
    }

    private func startTimer() {
        guard timer == nil, !isPaused else { return }
        let timer = Timer(timeInterval: 1 / Self.updatesPerSecond, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// One original update.
    private func update() {
        audio.advanceOriginalFrame()
        if case .waiting = runner.phase {
            runner.advanceWait()
            return settle()
        }
        if bellProcess != nil { return updateBell() }
        if signProcess != nil { return updateSign() }
        guard var current = process else { return stopTimer() }
        let input = OriginalEntranceProcess.Input(newTouch: pendingTouch, leftHanded: false,
            page0FadeComplete: (fadeRemaining[0] ?? 0) == 0)
        pendingTouch = nil
        for (screen, remaining) in fadeRemaining where remaining > 0 { fadeRemaining[screen] = remaining - 1 }
        let step = current.update(input)
        for effect in step.effects {
            switch effect {
            case .fade(let fade): fadeRemaining[fade.screen] = Int(fade.duration)
            case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
            case .processReturn(let value): processReturn = value
            default: break
            }
        }
        for draw in current.draw(leftHanded: false) {
            // Names are u01...u03; the matching d panel shares the number.
            if case .copyImage(let name, _) = draw, let number = Int(name.dropFirst().prefix(2)) {
                entrance?.panel = number - 1
            }
        }
        entrance?.sceneVisible = current.sceneVisible
        entrance?.awaitingHandle = current.movementAwaitingTouch
        process = current
        if step.status == 3 {
            process = nil
            entrance = nil
            fadeRemaining = [:]
            stopTimer()
            runner.finishProcess(returnValue: processReturn)
            settle()
        }
    }

    /// One update of process 24. Status 2 hands the result to the event runner.
    private func updateBell() {
        guard var current = bellProcess else { return }
        let input = OriginalBellProcess.Input(newTouch: pendingTouch.map { .init(x: $0.x, y: $0.y) },
            leftHanded: false, screen0FadeComplete: (fadeRemaining[0] ?? 0) == 0)
        pendingTouch = nil
        for (screen, remaining) in fadeRemaining where remaining > 0 { fadeRemaining[screen] = remaining - 1 }
        let step = current.update(input, mask: bellMask)
        for effect in step.effects {
            switch effect {
            case .fade(let fade): fadeRemaining[fade.screen] = Int(fade.duration)
            case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
            case .processReturn(let value): processReturn = value
            case .hintTalk, .presentation: break
            }
        }
        bellProcess = current
        bell = BellScene(angle: current.bellAngle, awaitingTouch: current.awaitingTouch,
                         quitEnabled: current.quitEnabled)
        guard step.status != 0 else { return }
        bellProcess = nil
        bell = nil
        fadeRemaining = [:]
        stopTimer()
        if step.status == 1 {
            runner.halt("Bell hint talk (mode 20 via 0x021FE468) is not recovered")
        } else {
            runner.finishProcess(returnValue: processReturn)
        }
        settle()
    }

    /// One update of process 25. Status 2 hands the result to the event runner.
    private func updateSign() {
        guard var current = signProcess else { return }
        let input = OriginalSignProcess.Input(heldTouch: heldTouch.map { .init(x: $0.x, y: $0.y) },
            newTouch: pendingTouch.map { .init(x: $0.x, y: $0.y) }, leftHanded: false,
            screen0FadeComplete: (fadeRemaining[0] ?? 0) == 0)
        pendingTouch = nil
        for (screen, remaining) in fadeRemaining where remaining > 0 { fadeRemaining[screen] = remaining - 1 }
        let step = current.update(input)
        for effect in step.effects {
            switch effect {
            case .fade(let fade): fadeRemaining[fade.screen] = Int(fade.duration)
            case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
            case .processReturn(let value): processReturn = value
            case .hintTalk, .presentation: break
            }
        }
        signProcess = current
        sign = SignScene(strokes: current.strokes, awaitingStroke: current.awaitingStroke,
                         quitEnabled: current.quitEnabled)
        guard step.status == 2 else { return }
        signProcess = nil
        sign = nil
        heldTouch = nil
        fadeRemaining = [:]
        stopTimer()
        runner.finishProcess(returnValue: processReturn)
        settle()
    }
}
