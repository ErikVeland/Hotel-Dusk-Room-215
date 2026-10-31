import Foundation

struct OriginalEncounterAnimationCatalog {
    private let expressions: [Int: [Int: String]]
    private let animationNames: [String: String]

    init(catalog: OriginalScriptCatalog) throws {
        let data = try catalog.decodedFile("ExpList.def")
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw OriginalAnimationError.invalid("Character expression table encoding")
        }
        var result: [Int: [Int: String]] = [:]
        var person: Int?
        var expectedCount: Int?
        for line in text.components(separatedBy: .newlines) {
            let fields = line.components(separatedBy: "//")[0].split(whereSeparator: \.isWhitespace)
            guard let first = fields.first else { continue }
            switch first {
            case "CHAREXP_BEGIN":
                person = nil
                expectedCount = nil
            case "ID":
                guard fields.count == 2, let id = Int(fields[1]), (1...17).contains(id), result[id] == nil else {
                    throw OriginalAnimationError.invalid("Character expression ID")
                }
                person = id
                result[id] = [:]
            case "NUM":
                guard fields.count == 2, let count = Int(fields[1]), count >= 0 else {
                    throw OriginalAnimationError.invalid("Character expression count")
                }
                expectedCount = count
            case "CHAREXP_END":
                guard let person, result[person]?.count == expectedCount else {
                    throw OriginalAnimationError.invalid("Incomplete character expressions")
                }
            default:
                guard let person, fields.count == 2, let pose = Int(first), pose > 0,
                      result[person]?[pose] == nil else {
                    throw OriginalAnimationError.invalid("Character expression entry")
                }
                result[person]?[pose] = String(fields[1]) + "_"
            }
        }
        guard result.count == 17 else { throw OriginalAnimationError.invalid("Character expression coverage") }
        expressions = result
        let library = try OriginalAnimationLibrary.bundled()
        animationNames = Dictionary(uniqueKeysWithValues: library.manifest.animations.map { ($0.id.lowercased(), $0.id) })
    }

    func animationID(person: Int, pose: Int) throws -> String {
        guard let name = expressions[person]?[pose], let id = animationNames[name.lowercased()] else {
            throw OriginalAnimationError.missing("Character \(person), expression \(pose)")
        }
        return id
    }

    func initialPose(person: Int) throws -> Int {
        if (try? animationID(person: person, pose: 2)) != nil { return 2 }
        guard let pose = expressions[person]?.keys.sorted().first(where: {
            (try? animationID(person: person, pose: $0)) != nil
        }) else { throw OriginalAnimationError.missing("Character \(person)") }
        return pose
    }
}

final class OriginalEncounterAnimations {
    struct Portrait {
        let screen: UInt8
        let person: Int
        let pose: Int
        let animationID: String
        let frame: OriginalAnimationFrame
        let contour: OriginalAnimationContour
    }

    private struct Player {
        let person: Int
        let pose: Int
        var decoder: OriginalAnimationDecoder
        var frame: OriginalAnimationFrame
        let contour: OriginalAnimationContour
        var updates = 0
    }

    private final class CachedClip: NSObject {
        let clip: OriginalAnimationClip
        init(_ clip: OriginalAnimationClip) { self.clip = clip }
    }

    private let expressions: OriginalEncounterAnimationCatalog
    private let library: OriginalAnimationLibrary
    private let clips = NSCache<NSString, CachedClip>()
    private var players: [UInt8: Player] = [:]
    private var lastProgram: String?
    private var lastPacketOffset: Int?
    private let updatesPerFrame = 6

    init(catalog: OriginalScriptCatalog) throws {
        expressions = try OriginalEncounterAnimationCatalog(catalog: catalog)
        library = try OriginalAnimationLibrary.bundled()
        clips.countLimit = 8
    }

    var portraits: [Portrait] {
        players.keys.sorted().compactMap { screen in
            guard let player = players[screen] else { return nil }
            return Portrait(screen: screen, person: player.person, pose: player.pose,
                animationID: player.decoder.clip.id, frame: player.frame, contour: player.contour)
        }
    }

    func present(_ packet: OriginalDialoguePacket, program: String) throws {
        guard program != lastProgram || packet.sourceOffset != lastPacketOffset else { return }
        for presentation in packet.presentations {
            let screen = presentation.page
            let person = Int(presentation.person)
            if person == -1 || person == -3 { continue }
            guard (1...17).contains(person) else {
                players.removeValue(forKey: screen)
                continue
            }
            var pose = Int(presentation.pose)
            if pose < 0 {
                if players[screen]?.person == person { continue }
                pose = try expressions.initialPose(person: person)
            }
            if players[screen]?.person == person, players[screen]?.pose == pose { continue }
            let id = try expressions.animationID(person: person, pose: pose)
            let clip: OriginalAnimationClip
            if let cached = clips.object(forKey: id as NSString) { clip = cached.clip }
            else {
                clip = try library.load(id: id)
                clips.setObject(CachedClip(clip), forKey: id as NSString)
            }
            var decoder = OriginalAnimationDecoder(clip: clip)
            guard let frame = try decoder.advance() else { throw OriginalAnimationError.invalid("Empty character animation") }
            players[screen] = Player(person: person, pose: pose, decoder: decoder, frame: frame,
                contour: OriginalAnimationContour(frame: frame))
        }
        lastProgram = program
        lastPacketOffset = packet.sourceOffset
    }

    @discardableResult
    func advance() throws -> Bool {
        var changed = false
        for screen in players.keys.sorted() {
            guard var player = players[screen] else { continue }
            player.updates += 1
            if player.updates >= updatesPerFrame {
                player.updates = 0
                if let frame = try player.decoder.advance() {
                    player.frame = frame
                    changed = true
                }
            }
            players[screen] = player
        }
        return changed
    }

    func clear() {
        players.removeAll(keepingCapacity: true)
        lastProgram = nil
        lastPacketOffset = nil
    }
}
