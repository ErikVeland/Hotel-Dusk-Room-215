import Foundation

/**
 * Process 126 after its bitmap uploads, from 0x0205EE60 and 0x0205E1A8.
 */
public struct OriginalClockProcess: Equatable, Sendable {
    public struct LabelDraw: Equatable, Sendable {
        public let layer: Int
        public let alpha: Int
    }

    public let label: String
    public let bitmapName: String
    public private(set) var phase = 6
    public private(set) var animation = 0
    public private(set) var counter = 0
    public private(set) var hold = 0
    public private(set) var alpha = 1
    public private(set) var hour: Int
    public private(set) var minute: Int
    public private(set) var second = 58
    public private(set) var showsLabel = false
    public private(set) var labelDraw: LabelDraw?
    public private(set) var isComplete = false
    private var lastTick: UInt64
    private var hasTicked = false

    public init(label: String, tick: UInt64 = 0) throws {
        let bytes = Array(label.utf8)
        guard bytes.count == 7, bytes[2] == 58,
              [0, 1, 3, 4].allSatisfy({ (48...57).contains(bytes[$0]) }),
              ["AM", "PM"].contains(String(label.suffix(2))) else {
            throw OriginalDataError.unsupported("Clock label \(label)")
        }
        guard label != "08:00AM" else {
            throw OriginalDataError.unsupported("The morning clock transition")
        }
        let h = Int(bytes[0] - 48) * 10 + Int(bytes[1] - 48)
        let m = Int(bytes[3] - 48) * 10 + Int(bytes[4] - 48)
        guard (1...12).contains(h), (0..<60).contains(m) else {
            throw OriginalDataError.invalid("Clock time")
        }
        self.label = label
        bitmapName = label.replacingOccurrences(of: ":", with: "").lowercased()
        hour = h % 12
        minute = m - 1
        if minute < 0 { minute = 59; hour = (hour + 11) % 12 }
        lastTick = tick
    }

    /**
     * Hand angles are multiples of pi. The hour hand uses ten-minute steps.
     */
    public var handAngles: [Float] {
        [-1 + Float(second) / 30, -1 + Float(minute) / 30,
         -1 + Float(hour) / 6 + Float(minute / 10) / 36]
    }

    /**
     * Advances the original clock update. Drawing runs before it on alternating frames.
     * Returns true for the original archive-0, entry-0x43 tick cue.
     */
    @discardableResult
    public mutating func update(tick: UInt64, draw: Bool, uploadComplete: Bool = true) -> Bool {
        guard !isComplete else { return false }
        if phase == 8 { isComplete = true; return false }
        if animation == 4, uploadComplete { animation = 5 }
        if draw, showsLabel { drawLabel() }
        if phase == 7 { phase = 8; return false }
        var sound = false
        if tick != lastTick {
            lastTick = tick
            if hasTicked {
                second += 1
                if second == 60 { second = 0; minute += 1 }
                if minute == 60 { minute = 0; hour = (hour + 1) % 12 }
                sound = true
            } else { hasTicked = true }
        }
        if second == 0 { showsLabel = true }
        if !showsLabel, alpha < 30 { alpha += 1 }
        if animation > 4, alpha > 1 { alpha -= 1 }
        return sound
    }

    private mutating func drawLabel() {
        switch animation {
        case 0...2:
            labelDraw = .init(layer: animation, alpha: counter + animation * 8 + 8)
            counter = (counter + 1) % 7
            if counter == 0 { animation += 1 }
        case 3:
            for _ in 0..<5 {
                if counter < 25 { counter += 1 }
                else {
                    hold += 1
                    if hold % 180 == 0 { animation = 4; hold = 0 }
                }
            }
            labelDraw = .init(layer: -1, alpha: counter + 5)
        case 4:
            labelDraw = .init(layer: -1, alpha: counter + 5)
        case 5...7:
            labelDraw = .init(layer: animation - 2, alpha: (animation - 5) * -8 + 30 - counter)
            counter = (counter + 1) % 7
            if counter == 0 { animation += 1 }
        case 8:
            phase = 7
            animation = 0
            labelDraw = nil
        default: break
        }
    }
}
