import Foundation

// MARK: - AtBat Event Models

struct AtBatEvent: Codable, Sendable, Equatable {
    let atBatIndex: Int?
    let batterId: Int
    let batterName: String
    let pinchRunnerName: String?
    let pitcherId: Int
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

/// An annotation to draw on the diamond (e.g. "E6", "SB", "CS")
struct BaseAnnotation: Codable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable {
        case error          // "E6" — next to the base reached
        case pinchRunner    // "PR" — indicates a pinch runner took over on base
        case stolenBase     // "SB" — next to the base stolen to
        case caughtStealing // "CS" — next to the out-line between bases
    }
    let kind: Kind
    let base: Int       // 1=1B, 2=2B, 3=3B, 4=home
    let label: String   // e.g. "E6", "SB", "CS"
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
