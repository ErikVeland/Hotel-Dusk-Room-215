import Foundation

/// Chapter clock tables from 0x02017278 (tables at 0x020EB130–0x020EB180).
public struct OriginalChapter {
    public let index: UInt16
    private static let clocks = ["05:00PM", "05:30PM", "06:00PM", "07:00PM", "08:00PM",
                                 "09:00PM", "10:00PM", "11:00PM", "12:00AM", "02:00AM"]
    private static let ranges = ["5:00–5:30 P.M.", "5:30–6:00 P.M.", "6:00–7:00 P.M.",
        "7:00–8:00 P.M.", "8:00–9:00 P.M.", "9:00–10:00 P.M.", "10:00–11:00 P.M.",
        "11:00 P.M.–12:00 A.M.", "12:00–2:00 A.M.", "2:00–10:00 A.M."]

    public init(_ index: UInt16) throws {
        guard index < 10 else { throw OriginalDataError.unsupported("Chapter \(index)") }
        self.index = index
    }

    public var number: Int { Int(index) + 1 }
    public var title: String { "Chapter \(number)" }
    public var clockLabel: String { " " + Self.clocks[Int(index)] }
    public var timeRange: String { Self.ranges[Int(index)] }
    public var dateLabel: String { index < 8 ? "December 28th 1979" : "December 29th 1979" }
    public var artworkSuffix: String { String(format: "%02d", number) }
}
