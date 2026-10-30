import Foundation

/// Persist each simulation step as a small append, with atomic base replacement.
/// An interrupted final append leaves the preceding complete step readable.
final class OriginalInstantSaveLog {
    private struct ByteChange: Codable {
        let offset: Int
        let value: UInt8
    }

    private struct Step: Codable {
        let baseID: String
        let sequence: Int
        let savedAt: Date
        let bytes: [ByteChange]
        let stateSHA256: String
        let condition: UInt8?
        let facing: Float
        let music: Int?
        let replaceLastInput: OriginalProgressInput?
        let appendedInputs: [OriginalProgressInput]
        let jigsawSeeds: [UInt32]?
        let puzzleSeeds: [UInt32]?
        let chapterSlotReads: [[OriginalChapterSave?]]?
        let chapterWrites: [OriginalPlayProgress.ChapterWrite]?
        let notebookInk: [DialogueNotebook.SavedState.Ink]?
        let nativeNotebookPages: [String: Data]?
        let readingAnchor: Int?
        let revealedEnd: Int?
        let reviewAnchor: Int?
        let retraceEnd: Int?
        let furthestRevealedEnd: Int?
        let reviewPassageEnd: Int?
        let reviewRevealedEnd: Int?
        let program: String
        let eventIndex: Int?
        let phase: String
        let session: OriginalEventSession?
        let progressSHA256: String

        init?(baseID: String, sequence: Int, previous: OriginalResumeSave, next: OriginalResumeSave) {
            guard let old = previous.progress, let new = next.progress, let digest = next.progressSHA256,
                  previous.state.count == next.state.count,
                  old.origin == new.origin, old.base == new.base, old.timestamp == new.timestamp,
                  old.baseSession == new.baseSession, old.baseRuntimePosition == new.baseRuntimePosition,
                  old.baseRuntimeFacing == new.baseRuntimeFacing, old.usesInstantSaves == new.usesInstantSaves,
                  old.qualityOfLifeVersion == new.qualityOfLifeVersion,
                  let oldNotebook = old.notebook, let newNotebook = new.notebook,
                  new.session != nil else { return nil }
            var replacement: OriginalProgressInput?
            let appended: [OriginalProgressInput]
            if new.inputs.count >= old.inputs.count,
               Array(new.inputs.prefix(old.inputs.count)) == old.inputs {
                appended = Array(new.inputs.dropFirst(old.inputs.count))
            } else if old.inputs.count > 0, new.inputs.count >= old.inputs.count,
                      Array(new.inputs.prefix(old.inputs.count - 1)) == Array(old.inputs.dropLast()),
                      case let .frames(oldCount, oldEnergy)? = old.inputs.last,
                      case let .frames(newCount, newEnergy) = new.inputs[old.inputs.count - 1],
                      newCount > oldCount, oldEnergy == newEnergy {
                replacement = new.inputs[old.inputs.count - 1]
                appended = Array(new.inputs.dropFirst(old.inputs.count))
            } else { return nil }
            self.baseID = baseID
            self.sequence = sequence
            savedAt = next.savedAt
            bytes = next.state.indices.compactMap {
                previous.state[$0] == next.state[$0] ? nil : ByteChange(offset: $0, value: next.state[$0])
            }
            stateSHA256 = next.stateSHA256
            condition = next.conditionGlobalByte
            facing = next.checkpointFacing
            music = next.musicSequenceID
            replaceLastInput = replacement
            appendedInputs = appended
            jigsawSeeds = old.jigsawSeeds == new.jigsawSeeds ? nil : new.jigsawSeeds
            puzzleSeeds = old.puzzleSeeds == new.puzzleSeeds ? nil : new.puzzleSeeds
            chapterSlotReads = old.chapterSlotReads == new.chapterSlotReads ? nil : new.chapterSlotReads
            chapterWrites = old.chapterWrites == new.chapterWrites ? nil : new.chapterWrites
            notebookInk = oldNotebook.ink == newNotebook.ink ? nil : newNotebook.ink
            nativeNotebookPages = old.nativeNotebookPages == new.nativeNotebookPages ? nil : new.nativeNotebookPages
            readingAnchor = oldNotebook.readingAnchor == newNotebook.readingAnchor ? nil : newNotebook.readingAnchor
            revealedEnd = oldNotebook.revealedEnd == newNotebook.revealedEnd ? nil : newNotebook.revealedEnd
            reviewAnchor = newNotebook.reviewAnchor
            retraceEnd = newNotebook.retraceEnd
            furthestRevealedEnd = newNotebook.furthestRevealedEnd
            reviewPassageEnd = newNotebook.reviewPassageEnd
            reviewRevealedEnd = newNotebook.reviewRevealedEnd
            program = new.program
            eventIndex = new.eventIndex
            phase = new.phase
            session = old.session == new.session ? nil : new.session
            progressSHA256 = digest
        }

        func applying(to previous: OriginalResumeSave) throws -> OriginalResumeSave {
            guard var journal = previous.progress, let notebook = journal.notebook else {
                throw OriginalDataError.invalid("Instant save base")
            }
            var state = previous.state
            for change in bytes {
                guard state.indices.contains(change.offset) else { throw OriginalDataError.invalid("Instant save byte") }
                state[change.offset] = change.value
            }
            if let replaceLastInput {
                guard !journal.inputs.isEmpty else { throw OriginalDataError.invalid("Instant save input") }
                journal.inputs[journal.inputs.count - 1] = replaceLastInput
            }
            journal.inputs.append(contentsOf: appendedInputs)
            if let jigsawSeeds { journal.jigsawSeeds = jigsawSeeds }
            if let puzzleSeeds { journal.puzzleSeeds = puzzleSeeds }
            if let chapterSlotReads { journal.chapterSlotReads = chapterSlotReads }
            if let chapterWrites { journal.chapterWrites = chapterWrites }
            if let nativeNotebookPages { journal.nativeNotebookPages = nativeNotebookPages }
            journal.notebook = .init(ink: notebookInk ?? notebook.ink,
                readingAnchor: readingAnchor ?? notebook.readingAnchor, revealedEnd: revealedEnd ?? notebook.revealedEnd,
                reviewAnchor: reviewAnchor, retraceEnd: retraceEnd, furthestRevealedEnd: furthestRevealedEnd,
                reviewPassageEnd: reviewPassageEnd, reviewRevealedEnd: reviewRevealedEnd)
            journal.program = program
            journal.eventIndex = eventIndex
            journal.phase = phase
            if let session { journal.session = session }
            let game = try OriginalGameState(snapshot: state, conditionGlobalByte: condition)
            let next = try OriginalResumeSave(game: game, checkpointFacing: facing,
                musicSequenceID: music, savedAt: savedAt, progress: journal)
            guard next.stateSHA256 == stateSHA256, next.progressSHA256 == progressSHA256 else {
                throw OriginalDataError.checksum("Instant save step")
            }
            return next
        }
    }

    private let directory: URL
    private var baseURL: URL { directory.appendingPathComponent("resume.json") }
    private var stepsURL: URL { directory.appendingPathComponent("resume.steps") }
    private let lock = NSLock()
    private var previous: OriginalResumeSave?
    private var baseID = ""
    private var baseInode: UInt64 = 0
    private var byteCount = 0
    private var sequence = 0

    init(directory: URL) { self.directory = directory }

    func load() throws -> OriginalResumeSave? {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: baseURL.path) else { return nil }
        let base = try Data(contentsOf: baseURL)
        var saved = try JSONDecoder().decode(OriginalResumeSave.self, from: base)
        _ = try saved.gameState()
        let identifier = OriginalScriptCatalog.digest(base)
        var count = 0
        var validBytes = 0
        if FileManager.default.fileExists(atPath: stepsURL.path) {
            let data = try Data(contentsOf: stepsURL)
            var start = data.startIndex
            for end in data.indices where data[end] == 10 {
                let step = try JSONDecoder().decode(Step.self, from: data[start..<end])
                // A crash after replacing the base may leave its old log behind.
                guard step.baseID == identifier else { break }
                guard step.sequence == count + 1 else { throw OriginalDataError.invalid("Instant save sequence") }
                saved = try step.applying(to: saved)
                count += 1
                validBytes = end + 1
                start = end + 1
            }
        }
        previous = saved
        baseID = identifier
        baseInode = try inode()
        byteCount = validBytes
        sequence = count
        return saved
    }

    func save(_ saved: OriginalResumeSave) throws {
        lock.lock()
        defer { lock.unlock() }
        _ = try saved.gameState()
        if let previous, sequence < 128, byteCount < 1_048_576,
           (try? inode()) == baseInode, (try? logSize()) == byteCount,
           let step = Step(baseID: baseID, sequence: sequence + 1, previous: previous, next: saved) {
            var data = try JSONEncoder().encode(step)
            data.append(10)
            let handle = try FileHandle(forWritingTo: stepsURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            self.previous = saved
            byteCount += data.count
            sequence += 1
        } else {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(saved)
            try data.write(to: baseURL, options: .atomic)
            try Data().write(to: stepsURL, options: .atomic)
            previous = saved
            baseID = OriginalScriptCatalog.digest(data)
            baseInode = try inode()
            byteCount = 0
            sequence = 0
        }
    }

    private func inode() throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: baseURL.path)
        return (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
    }

    private func logSize() throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: stepsURL.path)
        return (attributes[.size] as? NSNumber)?.intValue ?? 0
    }
}
