import Foundation

// MARK: - AtBat Event Models

struct AtBatEvent: Codable, Sendable, Equatable {
    let atBatIndex: Int?
    let batterId: String
    let batterName: String
    let pinchRunnerName: String?
    let pitcherId: String
    let pitcherName: String
    let previousPitcherName: String?
    let inning: Int
    let isTop: Bool
    let result: ScorecardResult
    let description: String
    let balls: Int
    let strikes: Int
    let outs: Int
    let rbi: Int
    let isRunnerOnly: Bool
    let isPitchingChange: Bool
    let bases: BasesReached
    let pitches: [PitchEvent]?
}

struct PitchEvent: Codable, Sendable, Equatable {
    let pitchNumber: Int
    let description: String
    let outcome: String // "Ball", "Strike", "Foul", "In Play"
    let speed: Double?
    let pitchType: String?
    let balls: Int?
    let strikes: Int?

    // Strike Zone Data (ft)
    // x: Horizontal (0 is center), z: Vertical Height
    let x: Double?
    let z: Double?
    let zoneTop: Double?
    let zoneBottom: Double?

    var isBall: Bool {
        let o = outcome.lowercased()
        let d = description.lowercased()
        return o.contains("ball") || d.contains("ball") || d.contains("blocked")
    }

    var isStrike: Bool {
        let o = outcome.lowercased()
        let d = description.lowercased()
        return o.contains("strike") || d.contains("strike") || o.contains("foul") || d.contains("foul")
    }
}

extension Array where Element == PitchEvent {
    /// Some sources (e.g. WPBL) never populate pitch coordinates, so there's nothing
    /// meaningful to plot in a strike-zone view. Views embedding PitchTrackView should
    /// check this before showing it, since PitchTrackView itself always draws a box.
    var hasLocationData: Bool {
        contains { $0.x != nil && $0.z != nil }
    }
}

/// An annotation to draw on the diamond (e.g. "E6", "SB", "CS")
struct BaseAnnotation: Codable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable {
        case error          // "E6" — next to the base reached
        case pinchRunner    // "PR" — indicates a pinch runner took over on base
        case stolenBase     // "SB" — next to the base stolen to
        case caughtStealing // "CS" — next to the out-line between bases
        case placedRunner   // "Z" — batter is the automatic extra-innings runner starting the next half-inning on base
    }
    let kind: Kind
    let base: Int       // 1=1B, 2=2B, 3=3B, 4=home
    let label: String   // e.g. "E6", "SB", "CS"
}

extension AtBatEvent {
    /// Returns a copy with `annotation` appended to `bases.annotations`.
    func addingAnnotation(_ annotation: BaseAnnotation) -> AtBatEvent {
        let newBases = BasesReached(
            first: bases.first,
            second: bases.second,
            third: bases.third,
            home: bases.home,
            lineToFirst: bases.lineToFirst,
            lineToSecond: bases.lineToSecond,
            lineToThird: bases.lineToThird,
            lineToHome: bases.lineToHome,
            outAtFirst: bases.outAtFirst,
            outAtSecond: bases.outAtSecond,
            outAtThird: bases.outAtThird,
            outAtHome: bases.outAtHome,
            annotations: (bases.annotations ?? []) + [annotation]
        )
        return AtBatEvent(
            atBatIndex: atBatIndex,
            batterId: batterId,
            batterName: batterName,
            pinchRunnerName: pinchRunnerName,
            pitcherId: pitcherId,
            pitcherName: pitcherName,
            previousPitcherName: previousPitcherName,
            inning: inning,
            isTop: isTop,
            result: result,
            description: description,
            balls: balls,
            strikes: strikes,
            outs: outs,
            rbi: rbi,
            isRunnerOnly: isRunnerOnly,
            isPitchingChange: isPitchingChange,
            bases: newBases,
            pitches: pitches
        )
    }
}

struct BasesReached: Codable, Sendable, Equatable {
    let first: Bool
    let second: Bool
    let third: Bool
    let home: Bool
    let lineToFirst: Bool?
    let lineToSecond: Bool?
    let lineToThird: Bool?
    let lineToHome: Bool?

    // Outs between bases
    let outAtFirst: Bool?
    let outAtSecond: Bool?
    let outAtThird: Bool?
    let outAtHome: Bool?

    // Diamond annotations (errors, stolen bases, caught stealing)
    let annotations: [BaseAnnotation]?
}
