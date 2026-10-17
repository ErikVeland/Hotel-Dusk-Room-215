import Foundation
import CryptoKit

/// Original cinematic parameters. Handler addresses identify recovered routines;
/// they are never executed or dereferenced by the native application.
public struct OriginalCinematicRecord: Codable, Equatable, Sendable {
    public let handlerAddress: UInt32
    public let objectData: Data

    public init(handlerAddress: UInt32, objectData: Data) throws {
        guard objectData.count >= 8, objectData.count <= 0x400 else {
            throw OriginalDataError.invalid("Cinematic object size")
        }
        self.handlerAddress = handlerAddress
        self.objectData = objectData
    }

    public func byte(_ offset: Int) throws -> UInt8 {
        guard offset >= 0, offset < objectData.count else {
            throw OriginalDataError.invalid("Cinematic field offset")
        }
        return objectData[offset]
    }

    public func unsigned16(_ offset: Int) throws -> UInt16 {
        try UInt16(byte(offset)) | UInt16(byte(offset + 1)) << 8
    }

    public func signed16(_ offset: Int) throws -> Int16 { try Int16(bitPattern: unsigned16(offset)) }

    public func string(_ offset: Int, capacity: Int) throws -> String {
        guard offset >= 0, capacity > 0, offset <= objectData.count - capacity,
              let end = objectData[offset..<(offset + capacity)].firstIndex(of: 0),
              let value = String(data: objectData[offset..<end], encoding: .ascii) else {
            throw OriginalDataError.invalid("Cinematic source string")
        }
        return value
    }

    public var audioCommand: OriginalAudioCommand? {
        get throws {
            guard handlerAddress == 0x020A5140 || handlerAddress == 0x020A51F8 else { return nil }
            let fields = try stride(from: 4, to: min(objectData.count, 16), by: 2).map(signed16)
            return try OriginalAudioCommand.decode(handlerAddress: handlerAddress, fields: fields)
        }
    }
}

public struct OriginalCinematicProgram: Decodable, Sendable {
    public let schemaVersion: Int
    public let initializerAddress: UInt32
    public let updateAddress: UInt32
    public let romSHA256: String
    public let captureSHA256: String
    public let trace: String
    public let handedness: Int
    public let commands: [OriginalCinematicRecord]

    public static func bundledOpening() throws -> Self {
        guard let root = Bundle.module.resourceURL else { throw OriginalDataError.missing("Resource bundle") }
        let url = root.appendingPathComponent("GameData/OriginalOpeningQueue.json")
        let program = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard program.schemaVersion == 1, program.initializerAddress == 0x020109B4,
              program.updateAddress == 0x020A1A5C, program.handedness == 0,
              program.commands.count == 459,
              program.romSHA256 == "134236d0793bad5d563de119068774a3e1c43a9b1614b1fe1c1fbf923eab676b",
              program.commands.allSatisfy({ (8...0x400).contains($0.objectData.count) }) else {
            throw OriginalDataError.invalid("Original opening provenance")
        }
        return program
    }

    public var commandDigest: String {
        var bytes = Data()
        for command in commands {
            for shift in stride(from: 0, to: 32, by: 8) { bytes.append(UInt8(truncatingIfNeeded: command.handlerAddress >> shift)) }
            var size = UInt32(command.objectData.count).littleEndian
            withUnsafeBytes(of: &size) { bytes.append(contentsOf: $0) }
            bytes.append(command.objectData)
        }
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
