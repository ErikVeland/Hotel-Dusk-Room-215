import Foundation

/// Isolated Swift transcriptions of verified CTalkController handlers. This
/// core does not choose events or advance the script PC: the original animation
/// lookahead and dialogue state transitions still need to be recovered.
public struct OriginalControllerCore: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case stateChanged
        case requiresDialogueHandler(textIndex: UInt16)
        case requiresHandler(opcode: UInt8)
        case requiresInventoryHandler(OriginalOperation)
    }

    public private(set) var flagSlots32: [UInt16]
    public private(set) var flagSlots852: [UInt16]
    public private(set) var waitCounter: UInt32
    public private(set) var waitLimit: UInt32

    /// Supply an observed state. Zero-filled storage is not assumed to be the
    /// original game's initial state.
    public init(flagSlots32: [UInt16], flagSlots852: [UInt16],
                waitCounter: UInt32, waitLimit: UInt32) throws {
        guard flagSlots32.count == 8, flagSlots852.count == 32,
              waitLimit <= UInt16.max, waitCounter <= UInt32(UInt16.max) + 1 else {
            throw OriginalDataError.invalid("Original controller storage")
        }
        self.flagSlots32 = flagSlots32
        self.flagSlots852 = flagSlots852
        self.waitCounter = waitCounter
        self.waitLimit = waitLimit
    }

    /// Matches 0x0203BDE4. Even the update which clears the counter returns
    /// without executing an operation. The caller supplies original update ticks.
    @discardableResult
    public mutating func consumeWaitUpdate() -> Bool {
        guard waitLimit != 0 else { return false }
        if waitCounter <= waitLimit { waitCounter += 1 }
        else { waitCounter = 0; waitLimit = 0 }
        return true
    }

    public mutating func apply(_ operation: OriginalOperation) -> Effect {
        switch operation {
        case .setFlag32(let index):
            Self.set(index, value: true, slots: &flagSlots32)
        case .clearFlag32(let index):
            Self.set(index, value: false, slots: &flagSlots32)
        case .changeFlag852(let value, let index):
            Self.set(index, value: value != 0, slots: &flagSlots852)
        case .wait(let counter):
            // The handler writes the limit only. It does not reset elapsed time.
            waitLimit = UInt32(counter)
        case .dialogue(let textIndex):
            return .requiresDialogueHandler(textIndex: textIndex)
        case .unrecovered(let opcode):
            return .requiresHandler(opcode: opcode)
        case .addInventory, .removeInventory, .removeAndClearInventory, .setItemState:
            return .requiresInventoryHandler(operation)
        }
        return .stateChanged
    }

    private static func set(_ index: UInt16, value: Bool, slots: inout [UInt16]) {
        guard Int(index) < slots.count * 8 else { return }
        let slot = Int(index) >> 3
        let bit = UInt16(1) << (index & 7)
        if value { slots[slot] |= bit }
        else { slots[slot] &= ~bit }
    }
}
