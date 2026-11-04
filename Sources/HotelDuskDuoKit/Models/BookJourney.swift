import Foundation
import simd

/// Frozen leaves and the route that is still being walked.
enum BookJourney {
    static let marker = "\u{FFFC}"
    enum Kind: String, Codable, Sendable { case arrival, walk, interaction, departure }

    struct Visit: Codable, Equatable, Sendable {
        let id: Int
        let mapID: Int16
        let chapter: Int
        let name: String
        let mapSize: SIMD2<Float>
        var route: [SIMD2<Float>]
        var interacting = false
    }

    struct Entry: Codable, Equatable, Sendable {
        let inkOffset: Int
        let visitID: Int
        let mapID: Int16
        let chapter: Int
        let name: String
        let kind: Kind
        let mapSize: SIMD2<Float>
        let route: [SIMD2<Float>]
        let facing: Float
        var viewPNG: Data?
        var floorPlanPNG: Data?
        let viewSHA256: String?
        let floorPlanSHA256: String?

        enum CodingKeys: String, CodingKey {
            case inkOffset, visitID, mapID, chapter, name, kind, mapSize, route, facing
            case viewPNG, floorPlanPNG, viewSHA256, floorPlanSHA256
        }
    }

    struct Portrait: Codable, Equatable, Hashable, Sendable {
        let screen: UInt8
        let animationID: String
        let frameIndex: Int
    }

    struct Cast: Codable, Equatable, Sendable {
        let inkOffset: Int
        let portraits: [Portrait]
    }

    struct Record: Codable, Equatable, Sendable {
        var entries: [Entry] = []
        var portraits: [Cast] = []
        var leafArt: [Cast] = []
        fileprivate(set) var activeVisit: Visit?
        fileprivate(set) var nextVisitID = 0

        mutating func visit(mapID: Int16, chapter: Int, name: String, mapSize: SIMD2<Float>, point: SIMD2<Float>) {
            guard activeVisit?.mapID != mapID || activeVisit?.chapter != chapter else { return }
            activeVisit = Visit(id: nextVisitID, mapID: mapID, chapter: chapter, name: name,
                                mapSize: mapSize, route: [point])
            nextVisitID += 1
        }

        mutating func walk(to point: SIMD2<Float>, force: Bool = false) {
            guard point.x.isFinite, point.y.isFinite, let last = activeVisit?.route.last,
                  simd_distance(point, last) >= 0.5 || (force && point != last) else { return }
            activeVisit?.route.append(point)
        }

        mutating func resumeWalking() { activeVisit?.interacting = false }
        mutating func leave() { activeVisit = nil }

        @discardableResult
        mutating func capture(_ kind: Kind, at offset: Int, facing: Float, view: Data?, floorPlan: Data?) -> Bool {
            guard let visit = activeVisit, kind != .interaction || !visit.interacting else { return false }
            entries.append(Entry(inkOffset: offset, visitID: visit.id, mapID: visit.mapID,
                chapter: visit.chapter, name: visit.name, kind: kind, mapSize: visit.mapSize,
                route: visit.route, facing: facing, viewPNG: view, floorPlanPNG: floorPlan,
                viewSHA256: view.map(OriginalScriptCatalog.digest),
                floorPlanSHA256: floorPlan.map(OriginalScriptCatalog.digest)))
            if kind == .interaction { activeVisit?.interacting = true }
            return true
        }

        func validate(ink: String) throws {
            let text = ink as NSString
            var last = -1
            for entry in entries {
                guard entry.inkOffset > last, entry.inkOffset < text.length,
                      text.character(at: entry.inkOffset) == 0xFFFC,
                      entry.facing.isFinite, entry.mapSize.x > 0, entry.mapSize.y > 0,
                      entry.route.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
                    throw OriginalDataError.invalid("Saved journey leaf")
                }
                last = entry.inkOffset
            }
            if let visit = activeVisit {
                guard visit.route.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
                      visit.id < nextVisitID else { throw OriginalDataError.invalid("Saved walking route") }
            }
            guard portraits.allSatisfy({ (0...text.length).contains($0.inkOffset) }) else {
                throw OriginalDataError.invalid("Saved portrait position")
            }
        }

        var fingerprint: Self {
            var result = self
            result.entries = entries.map {
                var entry = $0
                entry.viewPNG = nil
                entry.floorPlanPNG = nil
                return entry
            }
            return result
        }
    }

    /// An instant-save step carries new artwork once and appends new route points.
    struct Delta: Codable {
        var entries: [Entry]
        let portraits: [Cast]
        let leafArt: [Cast]
        let visit: Visit?
        let continuesVisit: Bool
        let nextVisitID: Int

        init?(previous: Record, next: Record) {
            guard next.entries.starts(with: previous.entries), next.portraits.starts(with: previous.portraits),
                  next.leafArt.starts(with: previous.leafArt) else { return nil }
            entries = Array(next.entries.dropFirst(previous.entries.count))
            portraits = Array(next.portraits.dropFirst(previous.portraits.count))
            leafArt = Array(next.leafArt.dropFirst(previous.leafArt.count))
            nextVisitID = next.nextVisitID
            if var current = next.activeVisit, let old = previous.activeVisit, current.id == old.id {
                guard current.route.starts(with: old.route) else { return nil }
                current.route = Array(current.route.dropFirst(old.route.count))
                visit = current
                continuesVisit = true
            } else {
                visit = next.activeVisit
                continuesVisit = false
            }
        }

        func applying(to previous: Record) throws -> Record {
            var result = previous
            result.entries.append(contentsOf: entries)
            result.portraits.append(contentsOf: portraits)
            result.leafArt.append(contentsOf: leafArt)
            if var visit, continuesVisit {
                guard let old = previous.activeVisit, old.id == visit.id else {
                    throw OriginalDataError.invalid("Saved journey visit")
                }
                visit.route = old.route + visit.route
                result.activeVisit = visit
            } else { result.activeVisit = visit }
            result.nextVisitID = nextVisitID
            return result
        }
    }
}

extension BookJourney.Entry {
    init(from decoder: Decoder) throws {
        let value = try decoder.container(keyedBy: CodingKeys.self)
        inkOffset = try value.decode(Int.self, forKey: .inkOffset)
        visitID = try value.decode(Int.self, forKey: .visitID)
        mapID = try value.decode(Int16.self, forKey: .mapID)
        chapter = try value.decode(Int.self, forKey: .chapter)
        name = try value.decode(String.self, forKey: .name)
        kind = try value.decode(BookJourney.Kind.self, forKey: .kind)
        mapSize = try value.decode(SIMD2<Float>.self, forKey: .mapSize)
        route = try value.decode([SIMD2<Float>].self, forKey: .route)
        facing = try value.decode(Float.self, forKey: .facing)
        viewPNG = try value.decodeIfPresent(Data.self, forKey: .viewPNG)
        floorPlanPNG = try value.decodeIfPresent(Data.self, forKey: .floorPlanPNG)
        viewSHA256 = try value.decodeIfPresent(String.self, forKey: .viewSHA256)
        floorPlanSHA256 = try value.decodeIfPresent(String.self, forKey: .floorPlanSHA256)
        for (data, digest) in [(viewPNG, viewSHA256), (floorPlanPNG, floorPlanSHA256)] {
            if let data, let digest, OriginalScriptCatalog.digest(data) != digest {
                throw OriginalDataError.checksum("Saved sketch")
            }
        }
    }
}
