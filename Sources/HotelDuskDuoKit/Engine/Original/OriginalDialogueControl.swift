import Foundation

/// Commands consumed by the original text renderer at 0x0204370C. Metadata
/// commands are retained even when that renderer itself only skips their bytes.
public enum OriginalTextControl: Equatable, Sendable {
    case color(UInt8)
    case display(UInt8)
    case talkingMotion(UInt8)
    case effect(UInt8)
    case music(mode: UInt8, name: String)
    case sound(code: String, mode: UInt8)
    case portraitMetadata(person: Int32, field: UInt8)
    case nameMetadata(UInt8)
    case backgroundMetadata(Data)
    case marker(UInt8)
    case toggleCipher
    /// `%r` with four digits begins every game-over sequence before its replayed warning.
    case retry(UInt16)
}

public struct OriginalDialogueToken: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Original font bytes, including non-ASCII glyphs, are not UTF-8 text.
        case glyph(UInt8)
        case control(OriginalTextControl)
    }
    public let textIndex: Int
    public let byteOffset: Int
    public let kind: Kind
}

public enum OriginalDialogueControl {
    /// Widths follow the original pointer increments. Unknown percent sequences
    /// render as ordinary characters in the original, so they remain glyphs.
    public static func tokens(for entry: OriginalTextTable.Entry) throws -> [OriginalDialogueToken] {
        let bytes = Array(entry.bytes)
        var result: [OriginalDialogueToken] = []
        var cursor = 0
        func decimal(_ data: ArraySlice<UInt8>) throws -> UInt16 {
            guard !data.isEmpty, data.allSatisfy({ (48...57).contains($0) }) else {
                throw OriginalDataError.invalid("Dialogue decimal at text \(entry.index):\(cursor)")
            }
            var value: UInt32 = 0
            for byte in data { value = value * 10 + UInt32(byte - 48) }
            guard value <= UInt16.max else { throw OriginalDataError.invalid("Dialogue decimal overflow") }
            return UInt16(value)
        }
        while cursor < bytes.count {
            let start = cursor
            var kind = OriginalDialogueToken.Kind.glyph(bytes[cursor])
            var length = 1
            if bytes[cursor] == 37, cursor + 1 < bytes.count {
                let code = bytes[cursor + 1]
                let widths: [UInt8: Int] = [98: 5, 99: 1, 100: 1, 101: 2, 109: 3,
                    110: 1, 112: 7, 114: 4, 115: 7, 119: 1, 33: 0, 63: 0, 43: 0]
                if let width = widths[code] {
                    length = width + 2
                    guard length <= bytes.count - cursor else {
                        throw OriginalDataError.invalid("Truncated dialogue control at text \(entry.index):\(cursor)")
                    }
                    let payload = bytes[(cursor + 2)..<(cursor + length)]
                    let control: OriginalTextControl
                    switch code {
                    case 99: control = .color(UInt8(try decimal(payload)))
                    case 100: control = .display(UInt8(try decimal(payload)))
                    case 119: control = .talkingMotion(UInt8(try decimal(payload)))
                    case 101: control = .effect(UInt8(try decimal(payload)))
                    case 110: control = .nameMetadata(UInt8(try decimal(payload)))
                    case 109:
                        let mode = UInt8(try decimal(payload.prefix(1)))
                        _ = try decimal(payload.suffix(2))
                        control = .music(mode: mode, name: "BGM_" + String(decoding: payload.suffix(2), as: UTF8.self))
                    case 115:
                        control = .sound(code: String(decoding: payload.prefix(6), as: UTF8.self),
                            mode: UInt8(try decimal(payload.suffix(1))))
                    case 112:
                        let personBytes = payload.prefix(5)
                        let negative = personBytes.first == 45
                        let magnitude = try decimal(negative ? personBytes.dropFirst() : personBytes)
                        let person = negative ? -Int32(magnitude) : Int32(magnitude)
                        guard let field = UInt8(String(decoding: payload.suffix(2), as: UTF8.self), radix: 16) else {
                            throw OriginalDataError.invalid("Dialogue portrait field")
                        }
                        control = .portraitMetadata(person: person, field: field)
                    case 98: control = .backgroundMetadata(Data(payload))
                    case 43: control = .toggleCipher
                    case 114: control = .retry(try decimal(payload))
                    default: control = .marker(code)
                    }
                    kind = .control(control)
                }
            }
            result.append(.init(textIndex: entry.index, byteOffset: start, kind: kind))
            cursor += length
        }
        return result
    }
}

/// Text buffers and portrait fields from opcode 4 (0x0203F57C). A paired
/// dialogue reads six consecutive strings and consumes the next raw record as
/// metadata, regardless of that record's first byte.
public struct OriginalDialoguePacket: Equatable, Sendable {
    public struct Presentation: Equatable, Sendable {
        public let page: UInt8
        public let person: Int8
        public let pose: Int8
        public let animation: Int8
        public let animationEnabled: Bool
        public let field7: Int8
    }
    public struct Page: Equatable, Sendable {
        public let page: UInt8
        public let entries: [OriginalTextTable.Entry]
        public let tokens: [OriginalDialogueToken]
        public var visibleBytes: Data {
            Data(tokens.compactMap { if case .glyph(let byte) = $0.kind { return byte }; return nil })
        }
    }
    public let sourceOffset: Int
    public let display: UInt8
    public let field8: Bool
    public let field9: UInt8
    public let presentations: [Presentation]
    public let pages: [Page]
    public var consumedRecordCount: Int { display == 2 ? 2 : 1 }

    public init(record: OriginalBlockGraph.Record, following: OriginalBlockGraph.Record?,
                text: OriginalTextTable) throws {
        guard record.raw.count == 16, record.raw.first == 4 else {
            throw OriginalDataError.invalid("Dialogue record")
        }
        let bytes = OriginalBytes(record.raw)
        let display = bytes.bytes[1]
        guard display <= 2 else { throw OriginalDataError.invalid("Dialogue display") }
        let start = Int(try bytes.u16(10))
        let count = display == 2 ? 6 : 3
        guard start <= text.entries.count, count <= text.entries.count - start else {
            throw OriginalDataError.invalid("Dialogue text group bounds")
        }
        func presentation(_ raw: Data, page: UInt8) throws -> Presentation {
            let source = OriginalBytes(raw)
            guard raw.count == 16 else { throw OriginalDataError.invalid("Paired dialogue metadata") }
            return Presentation(page: page, person: Int8(bitPattern: source.bytes[2]),
                pose: Int8(bitPattern: source.bytes[3]), animation: Int8(bitPattern: source.bytes[5]),
                animationEnabled: source.bytes[6] == 0, field7: Int8(bitPattern: source.bytes[7]))
        }
        var presentations = [try presentation(record.raw, page: display == 2 ? 1 : display)]
        if display == 2 {
            guard let following else { throw OriginalDataError.missing("Paired dialogue metadata") }
            presentations.append(try presentation(following.raw, page: 0))
        }
        var pages: [Page] = []
        for group in 0..<(display == 2 ? 2 : 1) {
            let entries = Array(text.entries[(start + group * 3)..<(start + group * 3 + 3)])
            var tokens: [OriginalDialogueToken] = []
            for entry in entries {
                tokens += try OriginalDialogueControl.tokens(for: entry)
                // 0x02043238 appends a newline after every source string.
                tokens.append(.init(textIndex: entry.index, byteOffset: entry.bytes.count, kind: .glyph(10)))
            }
            pages.append(Page(page: display == 2 ? UInt8(1 - group) : display, entries: entries, tokens: tokens))
        }
        self.sourceOffset = record.sourceOffset
        self.display = display
        self.field8 = bytes.bytes[8] != 0
        self.field9 = bytes.bytes[9]
        self.presentations = presentations
        self.pages = pages
    }
}
