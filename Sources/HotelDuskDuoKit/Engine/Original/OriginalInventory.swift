import Foundation

/// Ordered inventory and acquisition state transcribed from 0x02097914,
/// 0x0209798C and 0x02097E94. Inputs must come from an observed original state.
public struct OriginalInventory: Equatable, Sendable {
    public private(set) var items: [UInt8]
    public private(set) var itemStates: [UInt8]

    public init(items: [UInt8], itemStates: [UInt8]) throws {
        guard items.count <= 88, itemStates.count == 88,
              items.allSatisfy({ $0 < 88 }), Set(items).count == items.count else {
            throw OriginalDataError.invalid("Original inventory storage")
        }
        self.items = items
        self.itemStates = itemStates
    }

    public mutating func apply(_ operation: OriginalOperation) throws {
        if case .setItemState(let id, let value) = operation {
            if id >= 0, id < 88 { itemStates[Int(id)] = value }
            return
        }
        let field: UInt16
        switch operation {
        case .addInventory(let id), .removeInventory(let id), .removeAndClearInventory(let id): field = id
        default: throw OriginalDataError.unsupported("Not an inventory operation")
        }
        let id = UInt8(truncatingIfNeeded: field)
        guard id < 88 else { throw OriginalDataError.unsupported("Inventory ID outside recovered storage") }
        switch operation {
        case .addInventory:
            guard !items.contains(id), items.count < 88 else { return }
            if itemStates[Int(id)] == 0 { itemStates[Int(id)] = 1 }
            items.append(id)
        case .removeInventory, .removeAndClearInventory:
            if let index = items.firstIndex(of: id) { items.remove(at: index) }
            if case .removeAndClearInventory = operation,
               Int16(bitPattern: field) >= 0, field < 88 {
                itemStates[Int(id)] = 0
            }
        default: break
        }
    }
}
