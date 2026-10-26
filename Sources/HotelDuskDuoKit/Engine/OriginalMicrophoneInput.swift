import AVFoundation
import Combine
import Foundation

/// The original microphone callback (0x0200A590) keeps the largest positive
/// signed 16-bit sample in each 512-sample buffer. Audio is never stored.
@MainActor
public final class OriginalMicrophoneInput: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var error: String?
    private var engine: AVAudioEngine?
    private var request = 0
    private let samples = Peak()
    public var energy: UInt32 { samples.read() }

    private final class Peak: @unchecked Sendable {
        private let lock = NSLock()
        private var value: UInt32 = 0
        func store(_ value: UInt32) { lock.lock(); self.value = value; lock.unlock() }
        func read() -> UInt32 { lock.lock(); defer { lock.unlock() }; return value }
    }

    public func start() async {
        guard !isRunning else { return }
        request += 1
        let current = request
        guard Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil else {
            error = "Microphone input is unavailable in this build. You can still use touch."
            return
        }
        let allowed = await AVCaptureDevice.requestAccess(for: .audio)
        guard current == request else { return }
        guard allowed else {
            error = "Microphone access is off. You can enable it in Settings or use touch."
            return
        }
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            #endif
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw OriginalDataError.missing("Microphone") }
            let samples = samples
            input.installTap(onBus: 0, bufferSize: 512, format: format) { buffer, _ in
                guard let channel = buffer.floatChannelData?[0] else { return }
                var peak: Float = 0
                for index in 0..<Int(buffer.frameLength) { peak = max(peak, channel[index]) }
                samples.store(UInt32(min(32767, max(0, peak * 32767))))
            }
            try engine.start()
            self.engine = engine
            isRunning = true
            error = nil
        } catch { self.error = "The microphone could not start. You can still use touch." }
    }

    public func stop() {
        request += 1
        if let engine { engine.inputNode.removeTap(onBus: 0); engine.stop() }
        engine = nil
        isRunning = false
        samples.store(0)
    }
}
