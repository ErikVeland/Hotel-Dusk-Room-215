import Foundation

/**
 * Identifies the alphabet-overlay mode from its original embedded event call site.
 */
public enum OriginalAlphabetProcessMode: Equatable, Sendable {
    case paintingSearch
    case wordEntry
}

/**
 * Resolves only the Chapter 9 alphabet process calls recovered from the BLK tables.
 */
public enum OriginalAlphabetProcessContext {
    private static let paintingSearchCallSites: Set<String> = [
        "EP9_R117:84",
        "EP9_R125:104",
        "EP9_R205:248",
        "EP9_R207:84",
        "EP9_R213:84"
    ]

    public static func mode(for invocation: OriginalEventRunner.EmbeddedProcessInvocation)
        -> OriginalAlphabetProcessMode? {
        let callSite = "\(invocation.programName):\(invocation.eventSourceOffset)"
        if invocation.processID == 64, paintingSearchCallSites.contains(callSite) {
            return .paintingSearch
        }
        if invocation.processID == 81,
           invocation.programName == "EP9_R125",
           invocation.eventSourceOffset == 164 {
            return .wordEntry
        }
        return nil
    }

    /**
     * Returns the selected painting only for a recovered painting-search call.
     */
    public static func paintingIndex(for invocation: OriginalEventRunner.EmbeddedProcessInvocation)
        -> Int? {
        guard mode(for: invocation) == .paintingSearch else { return nil }
        // R125 is the Room 111 back room, which supplies the remaining J slot.
        if invocation.programName == "EP9_R125" && invocation.eventSourceOffset == 104
            && invocation.selection.mapID == 25 {
            return 0
        }
        return OriginalApplePaintingSearch.paintingMapIDs.firstIndex(of: invocation.selection.mapID)
    }

    /**
     * Returns the source caller value only when its recovered meaning is known.
     */
    public static func callerValue(forKey key: UInt16,
                                   mode: OriginalAlphabetProcessMode) -> Int16? {
        guard key == 0x15, mode == .paintingSearch else { return nil }
        return 10
    }

    /**
     * Returns the accepted success result for a recovered Chapter 9 call site.
     */
    public static func successfulReturnValue(
        for invocation: OriginalEventRunner.EmbeddedProcessInvocation) -> Int16? {
        switch mode(for: invocation) {
        case .paintingSearch:
            if invocation.programName == "EP9_R117" && invocation.eventSourceOffset == 84 { return 0 }
            if invocation.programName == "EP9_R125" && invocation.eventSourceOffset == 104 { return 0 }
            return 2
        case .wordEntry:
            return 0
        case nil:
            return nil
        }
    }
}

/**
 * A touch point transformed into overlay 38's painting camera coordinates.
 */
public struct OriginalAlphabetTouchPoint: Equatable, Sendable {
    public let x: Int32
    public let y: Int32
}

/**
 * Tracks the five Chapter 9 apple paintings recorded by overlay 38.
 */
public struct OriginalApplePaintingSearch: Equatable, Sendable {
    public static let paintingMapIDs: [Int16] = [11, 39, 17, 33, 31]
    public static let targetWord = "JENNY"
    private static let paintingMask: UInt16 = (1 << paintingMapIDs.count) - 1
    private static let paintingAnchors: [(x: Int32, y: Int32)] = [
        (86, 214), (32, 224), (188, 188), (160, 74), (186, 74)
    ]

    public private(set) var foundMask: UInt16

    public init(foundMask: UInt16 = 0) {
        self.foundMask = foundMask & Self.paintingMask
    }

    public var foundCount: Int {
        foundMask.nonzeroBitCount
    }

    public var isComplete: Bool {
        foundMask == Self.paintingMask
    }

    /**
     * Applies overlay 38's touch-to-camera transform from 0x021FE830.
     */
    public static func cameraPoint(pageX: Int32, pageY: Int32,
                                   cameraX: Float, cameraY: Float) -> OriginalAlphabetTouchPoint? {
        guard cameraX.isFinite, cameraY.isFinite else { return nil }
        let xOffset = ((Float(pageX) - 96) * 96 - cameraY) / 96
        let yOffset = ((128 - Float(pageY)) * 128 + cameraX) / 128
        let x = Float(96) + xOffset * 3
        let y = Float(256) - (Float(128) + yOffset * 3)
        guard x.isFinite, y.isFinite,
              Double(x) >= Double(Int32.min), Double(x) <= Double(Int32.max),
              Double(y) >= Double(Int32.min), Double(y) <= Double(Int32.max) else { return nil }
        return OriginalAlphabetTouchPoint(x: Int32(x), y: Int32(y))
    }

    /**
     * Tests the source's inclusive 16-by-16 selection region for a painting.
     */
    public static func containsPainting(at index: Int, cameraPoint: OriginalAlphabetTouchPoint) -> Bool {
        guard paintingAnchors.indices.contains(index) else { return false }
        let anchor = paintingAnchors[index]
        return cameraPoint.x >= anchor.x - 32 && cameraPoint.x <= anchor.x - 16 &&
            cameraPoint.y >= anchor.y && cameraPoint.y <= anchor.y + 16
    }

    /**
     * Records the painting for a source map ID and returns its puzzle index.
     */
    @discardableResult
    public mutating func findPainting(onMap mapID: Int16) -> Int? {
        guard let index = Self.paintingMapIDs.firstIndex(of: mapID) else { return nil }
        foundMask |= 1 << index
        return index
    }

    /**
     * Reveals the target-word letter for a recovered painting map ID.
     */
    @discardableResult
    public mutating func revealLetter(onMap mapID: Int16) -> (index: Int, letter: Character)? {
        guard let index = findPainting(onMap: mapID) else { return nil }
        let letter = Array(Self.targetWord)[index]
        return (index, letter)
    }

    public func hasFoundPainting(at index: Int) -> Bool {
        guard Self.paintingMapIDs.indices.contains(index) else { return false }
        return foundMask & (1 << index) != 0
    }
}

/**
 * Runs one map-specific painting search and retains its recovered bit mask.
 */
public struct OriginalApplePaintingProcess: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case looking
        case revealed(Character)
        case complete
    }

    public let paintingIndex: Int
    public private(set) var foundMask: UInt16
    public private(set) var phase: Phase
    public private(set) var cameraX: Float = 0
    public private(set) var cameraY: Float = 0

    public init?(paintingIndex: Int, foundMask: UInt16 = 0) {
        guard OriginalApplePaintingSearch.paintingMapIDs.indices.contains(paintingIndex) else { return nil }
        self.paintingIndex = paintingIndex
        self.foundMask = foundMask & 0x1f
        if self.foundMask & (1 << paintingIndex) != 0 {
            phase = .revealed(Array(OriginalApplePaintingSearch.targetWord)[paintingIndex])
        } else {
            phase = .looking
        }
    }

    /**
     * Moves the painting camera using overlay 38's 0.03-unit directional step.
     */
    public mutating func moveCamera(horizontalSteps: Int, verticalSteps: Int) {
        cameraX = min(2, max(-2, cameraX + Float(verticalSteps) * 0.03))
        cameraY = min(3, max(-6, cameraY + Float(horizontalSteps) * 0.03))
    }

    /**
     * Selects the source letter only when its hit region and artwork mask match.
     */
    @discardableResult
    public mutating func select(pageX: Int32, pageY: Int32, cameraX: Float = 0,
                                cameraY: Float = 0, mask: OriginalApplePaintingMask) -> Bool {
        guard phase == .looking,
              let point = OriginalApplePaintingSearch.cameraPoint(pageX: pageX, pageY: pageY,
                                                                   cameraX: cameraX, cameraY: cameraY),
              OriginalApplePaintingSearch.containsPainting(at: paintingIndex, cameraPoint: point),
              mask.contains(point) else { return false }
        foundMask |= 1 << paintingIndex
        phase = .revealed(Array(OriginalApplePaintingSearch.targetWord)[paintingIndex])
        return true
    }

    /**
     * Completes the local overlay state and returns its default result value.
     */
    @discardableResult
    public mutating func acknowledgeLetter() -> Int16? {
        guard case .revealed = phase else { return nil }
        phase = .complete
        return 2
    }
}
