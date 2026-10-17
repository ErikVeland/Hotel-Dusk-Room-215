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

    @Published public private(set) var runner: OriginalEventRunner
    @Published public private(set) var entrance: EntranceScene?
    private let audio: AudioController
    private var process: OriginalEntranceProcess?
    private var processReturn: Int16 = 2
    private var fadeRemaining: [Int: Int] = [:]
    private var pendingTouch: OriginalEntranceProcess.Touch?
    private var timer: Timer?
    private var isPaused = false
    private var presentedPacketOffset: Int?

    public init(runner: OriginalEventRunner, audio: AudioController) {
        self.runner = runner
        self.audio = audio
        settle()
    }

    public static func chapterOne(audio: AudioController) throws -> OriginalPlaySession {
        let runner = try OriginalEventRunner.chapterOneArrival(catalog: .bundled(), defaults: .bundled(),
            timestamp: Int64(Date().timeIntervalSince1970))
        return OriginalPlaySession(runner: runner, audio: audio)
    }

    /// A tap on either page while text is shown.
    public func advanceDialogue() {
        guard !isPaused, case .dialogue = runner.phase else { return }
        runner.acknowledgeDialogue()
        settle()
    }

    /// A new press on the touch page, in rotated page pixels (192 × 256).
    public func touchEntrance(pageX: Int, pageY: Int) {
        guard process != nil, (0..<192).contains(pageX), (0..<256).contains(pageY) else { return }
        pendingTouch = OriginalEntranceProcess.Touch(x: 255 - pageY, y: pageX)
    }

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
        case .exploration, .halted:
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
}
