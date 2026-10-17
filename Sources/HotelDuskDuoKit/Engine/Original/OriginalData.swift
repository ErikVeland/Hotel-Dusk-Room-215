import Foundation

/// Decoding failures stop recovery. Damaged or unknown data must not become
/// invented dialogue, pictures, commands, or default gameplay values.
public enum OriginalDataError: Error, Equatable {
    case truncated(offset: Int, length: Int)
    case invalid(String)
    case unsupported(String)
    case checksum(String)
    case missing(String)
}

struct OriginalBytes {
    let bytes: [UInt8]
    init(_ data: Data) { bytes = Array(data) }
    func range(_ offset: Int, _ length: Int) throws -> ArraySlice<UInt8> {
        guard offset >= 0, length >= 0, offset <= bytes.count,
              length <= bytes.count - offset else {
            throw OriginalDataError.truncated(offset: offset, length: length)
        }
        return bytes[offset..<offset + length]
    }
    func u16(_ offset: Int) throws -> UInt16 {
        let b = Array(try range(offset, 2))
        return UInt16(b[0]) | UInt16(b[1]) << 8
    }
    func u32(_ offset: Int) throws -> UInt32 {
        let b = Array(try range(offset, 4))
        return UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
    }
    func zeroTerminated(_ offset: Int, limit: Int) throws -> [UInt8] {
        let bytes = try range(offset, limit)
        guard let end = bytes.firstIndex(of: 0) else {
            throw OriginalDataError.invalid("Unterminated string at \(offset)")
        }
        return Array(bytes[..<end])
    }
}

/// Native Swift decoder for CiNG's 12 3D DA containers. The optional WPF
/// directory record is retained by tools/unpack_wpf.py, not part of the codec.
public enum OriginalContainer {
    public static func decode(_ data: Data, hasDirectoryRecord: Bool = true) throws -> Data {
        let reader = OriginalBytes(data)
        let start = hasDirectoryRecord ? 32 : 0
        if hasDirectoryRecord {
            guard try reader.u32(24) == data.count - 32 else {
                throw OriginalDataError.invalid("WPF member length")
            }
        }
        let magic = Array(try reader.range(start, 4))
        guard magic.prefix(3) == [0x12, 0x3D, 0xDA], magic[3] <= 1 else {
            throw OriginalDataError.unsupported("CiNG container signature")
        }
        let length = Int(try reader.u32(start + 4))
        let packedLength = try reader.u32(start + 8)
        guard try reader.u32(start + 12) == 0, length <= 64 * 1024 * 1024 else {
            throw OriginalDataError.invalid("CiNG container header")
        }
        if magic[3] == 0 {
            guard packedLength == .max, data.count == start + 16 + length else {
                throw OriginalDataError.invalid("Raw CiNG length")
            }
            return Data(try reader.range(start + 16, length))
        }
        guard data.count == start + 16 + Int(packedLength) else {
            throw OriginalDataError.invalid("Compressed CiNG length")
        }
        let source = Array(try reader.range(start + 16, Int(packedLength)))
        var ring = [UInt8](repeating: 0, count: 65_536)
        var write = 65_536 - 259
        var cursor = 0
        var output = [UInt8]()
        output.reserveCapacity(length)
        func append(_ value: UInt8) throws {
            guard output.count < length else { throw OriginalDataError.invalid("CiNG output overflow") }
            output.append(value)
            ring[write] = value
            write = (write + 1) & 0xFFFF
        }
        while cursor < source.count {
            let flags = source[cursor]
            cursor += 1
            for bit in 0..<8 {
                if cursor == source.count { break }
                if flags & (1 << bit) != 0 {
                    try append(source[cursor])
                    cursor += 1
                } else {
                    guard source.count - cursor >= 3 else {
                        throw OriginalDataError.truncated(offset: start + 16 + cursor, length: 3)
                    }
                    let reference = Int(source[cursor]) | Int(source[cursor + 1]) << 8
                    let count = Int(source[cursor + 2]) + 4
                    cursor += 3
                    for index in 0..<count { try append(ring[(reference + index) & 0xFFFF]) }
                }
            }
        }
        guard output.count == length else { throw OriginalDataError.invalid("CiNG decoded length") }
        return Data(output)
    }
}
