import Foundation

/// Store each frozen drawing once. Incremental saves carry its content digest.
struct BookArtworkStore {
    let directory: URL

    private func asset(_ digest: String) throws -> URL {
        guard digest.count == 64, digest.allSatisfy({ $0.isHexDigit }) else {
            throw OriginalDataError.invalid("Saved sketch reference")
        }
        return directory.appendingPathComponent("book-art", isDirectory: true).appendingPathComponent(digest + ".png")
    }

    func storing(_ entries: [BookJourney.Entry]) throws -> [BookJourney.Entry] {
        try entries.map { value in
            var entry = value
            for (data, digest) in [(entry.viewPNG, entry.viewSHA256), (entry.floorPlanPNG, entry.floorPlanSHA256)] {
                guard let data, let digest else { continue }
                let url = try asset(digest)
                if !FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: url, options: .atomic)
                }
            }
            entry.viewPNG = nil
            entry.floorPlanPNG = nil
            return entry
        }
    }

    func loading(_ entries: [BookJourney.Entry]) throws -> [BookJourney.Entry] {
        try entries.map { value in
            var entry = value
            func load(_ data: Data?, _ digest: String?) throws -> Data? {
                guard let digest else { return data }
                let pixels = try data ?? Data(contentsOf: asset(digest))
                guard OriginalScriptCatalog.digest(pixels) == digest else {
                    throw OriginalDataError.checksum("Saved sketch")
                }
                return pixels
            }
            entry.viewPNG = try load(entry.viewPNG, entry.viewSHA256)
            entry.floorPlanPNG = try load(entry.floorPlanPNG, entry.floorPlanSHA256)
            return entry
        }
    }

    private func map(_ state: DialogueNotebook.SavedState?, storing: Bool) throws -> DialogueNotebook.SavedState? {
        guard var state else { return nil }
        if var book = state.book {
            book.entries = try storing ? self.storing(book.entries) : loading(book.entries)
            state.book = book
        }
        return state
    }

    func map(_ checkpoint: OriginalResumeSave, storing: Bool) throws -> OriginalResumeSave {
        let notebook = try map(checkpoint.notebook, storing: storing)
        var progress = checkpoint.progress
        let progressNotebook = try map(progress?.notebook, storing: storing)
        progress?.notebook = progressNotebook
        return try OriginalResumeSave(game: checkpoint.gameState(), checkpointFacing: checkpoint.checkpointFacing,
            musicSequenceID: checkpoint.musicSequenceID, savedAt: checkpoint.savedAt, progress: progress, notebook: notebook)
    }
}
