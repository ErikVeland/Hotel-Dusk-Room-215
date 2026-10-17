import Foundation

/**
 * Process 98 retains the search area while the player selects close-up components.
 */
public struct OriginalSearchCloseup {
    public let area: UInt16
    public let subarea: UInt16
    public let view: OriginalUpViewTable.View
    public private(set) var selected: Int?

    public init(area: UInt16, subarea: UInt16, view: OriginalUpViewTable.View) throws {
        self.area = area
        self.subarea = subarea
        self.view = view
    }

    /**
     * 0x02058A04 hides collected item layers, including items subsequently removed from inventory.
     */
    public func visibility(game: OriginalGameState) throws -> [Bool] {
        let states = try game.inventory.itemStates
        return try [true] + view.layers.map { layer in
            guard layer.itemID >= 0 else { return true }
            guard states.indices.contains(Int(layer.itemID)) else {
                throw OriginalDataError.invalid("Close-up item ID")
            }
            return states[Int(layer.itemID)] == 0
        }
    }

    /**
     * A second press confirms a component. Component zero selects the background event.
     */
    public mutating func select(_ component: Int?) -> Bool {
        let valid = component.flatMap { (0...view.layers.count).contains($0) ? $0 : nil }
        let confirmed = valid != nil && valid == selected
        selected = valid
        return confirmed
    }

    public var selectedEvent: Int16? {
        selected.map { $0 == 0 ? view.id : view.layers[$0 - 1].eventID }
    }

    /**
     * 0x02059E7C reads the child view ID at layer offset 0x24.
     */
    public var selectedChildView: UInt16? {
        guard let selected, selected > 0, view.layers[selected - 1].processID >= 0 else { return nil }
        return UInt16(view.layers[selected - 1].processID)
    }

    /**
     * 0x02059E1C returns the selected layer's non-empty detail asset.
     */
    public var selectedDetailAsset: String? {
        guard let selected, selected > 0 else { return nil }
        let asset = view.layers[selected - 1].detailAsset
        return asset.isEmpty ? nil : asset
    }

    public mutating func clearSelection() { selected = nil }
}
