import Foundation
import Combine

/// Unsubmitted notes and pencil strokes belong to the session, not a page's lifetime.
@MainActor
public final class MemoDraft: ObservableObject {
    @Published public var text = ""
    @Published public var lines: [[CGPoint]] = []
    @Published public var currentLine: [CGPoint] = []

    public init() {}
}
