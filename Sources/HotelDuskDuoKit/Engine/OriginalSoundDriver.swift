import Foundation

/// Arithmetic and tables recovered from the game's ARM7 sound driver.
public struct OriginalSoundDriver: Decodable, Sendable {
    public struct Table: Decodable, Sendable {
        public let address: String
        public let sha256: String
        public let values: [Int]
    }
    public let schemaVersion: Int
    public let sourceARM7_SHA256: String
    public let attack: Table
    public let attenuation: Table
    public let modulationSine: Table
    public let channelOrder: Table
    public let initialEnvelope: Int
    public let randomSeed: UInt32
    public let randomMultiplier: UInt32
    public let randomIncrement: UInt32
    public let driverAlarmInterval: Int

    public static func load() throws -> Self {
        let data = try Data(contentsOf: OriginalAudioLibrary.resource("OriginalSoundDriver.json"))
        let driver = try JSONDecoder().decode(Self.self, from: data)
        guard driver.schemaVersion == 1, driver.attack.values.count == 19,
              driver.attenuation.values.count == 128, driver.modulationSine.values.count == 33,
              Set(driver.channelOrder.values) == Set(0..<16) else {
            throw OriginalAudioError.invalidManifest
        }
        return driver
    }

    /// Sequence volume uses the source attenuation table, not linear gain.
    /// Apple's final mixer still differs from DS integer hardware quantization.
    public func linearGain(volume: Int) -> Float {
        guard volume > 0 else { return 0 }
        return Float(pow(10, Double(attenuation.values[min(volume, 127)]) / 200))
    }

    /// ARM7 03800138: attack is a multiplier; 127 reaches full level immediately.
    public func attackMultiplier(_ value: Int) -> Int {
        let value = min(127, max(0, value))
        return value < 109 ? 255 - value : attack.values[127 - value]
    }

    /// ARM7 037FFBA4: decay and release decrement the fixed-point envelope.
    public func decayReleaseRate(_ value: Int) -> Int {
        switch min(127, max(0, value)) {
        case 127: return 65535
        case 126: return 15360
        case let value where value < 50: return value * 2 + 1
        case let value: return 7680 / (126 - value)
        }
    }

    public struct Envelope: Codable, Sendable, Equatable {
        public enum Stage: Int, Codable, Sendable { case attack, decay, sustain, release }
        public private(set) var stage: Stage = .attack
        public private(set) var level: Int
        private let attackMultiplier: Int
        private let decayRate: Int
        private let sustainLevel: Int
        private let releaseRate: Int

        public init(driver: OriginalSoundDriver, attack: Int, decay: Int, sustain: Int, release: Int) {
            level = driver.initialEnvelope
            attackMultiplier = driver.attackMultiplier(attack)
            decayRate = driver.decayReleaseRate(decay)
            sustainLevel = driver.attenuation.values[min(127, max(0, sustain))] * 128
            releaseRate = driver.decayReleaseRate(release)
        }

        public var attenuation: Int { level >> 7 }

        /// One sound-driver alarm, matching ARM7 0380015C.
        public mutating func advance() {
            switch stage {
            case .attack:
                level = -((-level * attackMultiplier) >> 8)
                if level == 0 { stage = .decay }
            case .decay:
                level -= decayRate
                if level <= sustainLevel { level = sustainLevel; stage = .sustain }
            case .sustain: break
            case .release: level -= releaseRate
            }
        }

        public mutating func release() { stage = .release }
    }

    public struct RandomState: Codable, Sendable, Equatable {
        public private(set) var state: UInt32
        private let multiplier: UInt32
        private let increment: UInt32

        public init(driver: OriginalSoundDriver) {
            state = driver.randomSeed
            multiplier = driver.randomMultiplier
            increment = driver.randomIncrement
        }

        /// ARM7 037FF468; the sound loop also advances this once per update.
        public mutating func next() -> UInt16 {
            state = state &* multiplier &+ increment
            return UInt16(state >> 16)
        }

        /// Signed random-variable command B6 in ARM7 038009D8.
        public mutating func value(upTo bound: Int16) -> Int16 {
            let magnitude = abs(Int(bound))
            let value = (Int(next()) * (magnitude + 1)) >> 16
            return Int16(bound < 0 ? -value : value)
        }
    }
}
