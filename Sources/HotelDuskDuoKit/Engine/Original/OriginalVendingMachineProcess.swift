import Foundation

public struct OriginalVendingMachineProcess: Equatable, Sendable {
    public enum Action: Codable, Equatable, Sendable {
        case insertCoin
        case digit(Int)
        case confirm
        case returnCoin
        case quit
    }

    public enum Phase: Equatable, Sendable {
        case fadingIn(remaining: Int)
        case acceptingInput
        case insertingCoin(remaining: Int)
        case dispensing(remaining: Int)
        case fadingOut(remaining: Int)
        case complete
    }

    public struct Product: Equatable, Sendable {
        public let code: Int
        public let itemID: UInt8
        public let result: Int16
        public let artwork: String
    }

    public static let products: [Product] = [
        Product(code: 10, itemID: 38, result: 4, artwork: "goods10"),
        Product(code: 11, itemID: 34, result: 0, artwork: "goods11"),
        Product(code: 12, itemID: 35, result: 1, artwork: "goods12"),
        Product(code: 13, itemID: 36, result: 2, artwork: "goods13")
    ]

    public private(set) var phase: Phase = .fadingIn(remaining: 60)
    public private(set) var digits: [Int] = []
    public private(set) var coinInserted = false
    public private(set) var rejectedCode = false
    public private(set) var selectedItem: UInt8?
    public private(set) var result: Int16?
    private let acquired: Set<UInt8>
    private let secretCode: Int
    private let shifted: Bool
    private var pendingResult: Int16 = 3

    public init(randomInfo: UInt16, shifted: Bool, itemStates: [UInt8]) {
        acquired = Set(itemStates.prefix(88).enumerated().compactMap { $0.element == 0 ? nil : UInt8($0.offset) })
        let row = (Int(randomInfo % 10) + (shifted ? 1 : 0)) % 10
        secretCode = [51, 37, 69, 80, 60, 32, 43, 55, 90, 28][row]
        self.shifted = shifted
    }

    public var opacity: Double {
        switch phase {
        case .fadingIn(let remaining): return Double(60 - remaining) / 60
        case .fadingOut(let remaining): return Double(remaining) / 60
        case .complete: return 0
        default: return 1
        }
    }

    public func isAvailable(_ product: Product) -> Bool { !acquired.contains(product.itemID) }

    @discardableResult
    public mutating func receive(_ action: Action) -> Int? {
        guard phase == .acceptingInput else { return nil }
        switch action {
        case .insertCoin:
            guard !coinInserted else { return nil }
            rejectedCode = false
            phase = .insertingCoin(remaining: 32)
        case .digit(let digit):
            guard coinInserted, (0...9).contains(digit), digits.count < 2 else { return nil }
            digits.append(digit)
            rejectedCode = false
            return 1
        case .confirm:
            guard coinInserted else { return nil }
            defer { digits = [] }
            guard digits.count == 2 else { rejectedCode = true; return 1 }
            let code = digits[0] * 10 + digits[1]
            if let product = Self.products.first(where: { $0.code == code }), isAvailable(product) {
                selectedItem = product.itemID
                pendingResult = product.result
            } else if code == secretCode, !acquired.contains(shifted ? 79 : 78) {
                selectedItem = shifted ? 79 : 78
                pendingResult = shifted ? 6 : 5
            } else {
                rejectedCode = true
                return 1
            }
            coinInserted = false
            rejectedCode = false
            phase = .dispensing(remaining: 120)
            return 3
        case .returnCoin:
            guard coinInserted else { return nil }
            coinInserted = false
            digits = []
            rejectedCode = false
            return 2
        case .quit:
            pendingResult = 3
            phase = .fadingOut(remaining: 60)
            return 2
        }
        return nil
    }

    @discardableResult
    public mutating func update() -> Int? {
        switch phase {
        case .fadingIn(let remaining):
            phase = remaining <= 1 ? .acceptingInput : .fadingIn(remaining: remaining - 1)
        case .insertingCoin(let remaining):
            if remaining <= 1 {
                phase = .acceptingInput
                coinInserted = true
                return 0
            }
            phase = .insertingCoin(remaining: remaining - 1)
        case .dispensing(let remaining):
            phase = remaining <= 1 ? .fadingOut(remaining: 60) : .dispensing(remaining: remaining - 1)
        case .fadingOut(let remaining):
            if remaining <= 1 {
                result = pendingResult
                phase = .complete
            } else { phase = .fadingOut(remaining: remaining - 1) }
        case .acceptingInput, .complete:
            break
        }
        return nil
    }
}
