import Foundation

/**
 * Process 59, overlay 20 (`CJukeBox`): the Seven Stars bar jukebox.
 *
 * Record selection follows 0x021FDBF0. Selecting the playing record stops the music and
 * stores -1 at game offset 0x13BC (0x020989D4). Another record plays its sequence and
 * stores it there, so the bar's walking music resumes with it (0x0202DC70). Record IDs
 * equal sequence IDs in the table at 0x02202078. The 3D cabinet, record rack rotation
 * and character animation are not reproduced.
 */
public struct OriginalJukeboxProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case play(sequenceID: Int)
        case stop
        case completed(Int16)
    }

    /// Titles from `JK_USA.txt`, one per record.
    public let titles: [String]
    public private(set) var playing: Int?
    public private(set) var result: Int16?

    public init(titles: [String], playing: Int16) {
        self.titles = titles
        self.playing = playing >= 0 && Int(playing) < titles.count ? Int(playing) : nil
    }

    /// Parses the tab-terminated, line-separated title list.
    public static func titles(from data: Data) throws -> [String] {
        guard let text = String(data: data, encoding: .isoLatin1) else { throw OriginalDataError.invalid("Jukebox titles") }
        let titles = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard titles.count == 36 else { throw OriginalDataError.invalid("Jukebox title count \(titles.count)") }
        return titles
    }

    public mutating func select(_ record: Int) -> [Effect] {
        guard result == nil, titles.indices.contains(record) else { return [] }
        if playing == record {
            playing = nil
            return [.stop]
        }
        playing = record
        return [.play(sequenceID: record)]
    }

    /// The process returns to the bar script; its exit does not branch on the value.
    public mutating func quit() -> [Effect] {
        guard result == nil else { return [] }
        result = 0
        return [.completed(0)]
    }
}
