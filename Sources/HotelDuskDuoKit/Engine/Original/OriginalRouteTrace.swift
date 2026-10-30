import Foundation

/// Appends opt-in route observations as JSON Lines without changing game state.
public final class OriginalRouteTraceLog: @unchecked Sendable {
    private let lock = NSLock()
    private let handle: FileHandle
    private let runID: String
    private let checkpointName: String
    private var inputStep = 0
    private let encoder: JSONEncoder

    public init(url: URL, runID: String, checkpointName: String) throws {
        self.runID = runID
        self.checkpointName = checkpointName
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
    }

    deinit { try? handle.close() }

    @discardableResult
    func beginInput(_ input: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        inputStep += 1
        writeLocked(kind: "input", fields: ["input": input])
        return inputStep
    }

    func write(kind: String, fields: [String: String]) {
        lock.lock()
        defer { lock.unlock() }
        writeLocked(kind: kind, fields: fields)
    }

    private func writeLocked(kind: String, fields: [String: String]) {
        var observedFields = fields
        observedFields["evidenceStatus"] = "observed"
        let record: [String: AnyCodableValue] = [
            "runID": .string(runID),
            "inputStep": .integer(inputStep),
            "checkpointName": .string(checkpointName),
            "kind": .string(kind),
            "fields": .stringMap(observedFields)
        ]
        guard let data = try? encoder.encode(record), let newline = "\n".data(using: .utf8) else { return }
        try? handle.write(contentsOf: data + newline)
    }

    private enum AnyCodableValue: Encodable {
        case string(String)
        case integer(Int)
        case stringMap([String: String])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value): try container.encode(value)
            case .integer(let value): try container.encode(value)
            case .stringMap(let value): try container.encode(value)
            }
        }
    }
}
