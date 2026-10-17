import Foundation

/**
 * Opcode 16 arguments for the original process 126 (0x0203C4AC, 0x0205D8FC).
 */
public struct OriginalTimeTransition: Equatable, Sendable {
    public let request: OriginalEventRunner.ProcessRequest
    public let label: String

    public init(record: OriginalBlockGraph.Record) throws {
        guard record.raw.count == 16, record.raw[0] == 16 else {
            throw OriginalDataError.invalid("Time transition command")
        }
        let reader = OriginalBytes(record.raw)
        request = .init(kind: Int8(bitPattern: reader.bytes[2]),
                        value: Int16(bitPattern: try reader.u16(4)))
        let bytes = try reader.zeroTerminated(6, limit: 10)
        guard let label = String(bytes: bytes, encoding: .ascii) else {
            throw OriginalDataError.invalid("Time transition label")
        }
        self.label = label
    }

    /**
     * The dispatcher compares with the literal NONE, including its case.
     */
    public var presentsClock: Bool { label != "NONE" }

    /**
     * The child substitutes its original default for an empty supplied label.
     */
    public var clockLabel: String { label.isEmpty ? "05:00PM" : label }
}
