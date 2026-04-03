import Foundation

// MARK: - Scorecard Model
struct ScorecardData: Codable, Sendable {
    let teams: ScorecardTeams
    let lineups: Lineups
    let pitchers: ScorecardPitchers
    let innings: [ScorecardInning]
    let advisories: [String]
    let currentInning: Int?
    let isTopInning: Bool?
    let currentBatterId: Int?
}

struct ScorecardPitchers: Codable, Sendable {
    let home: [ScorecardPitcher]
    let away: [ScorecardPitcher]
}

struct ScorecardPitcher: Codable, Sendable {
    let id: Int
    let fullName: String
    let stats: String
}

struct ScorecardTeams: Codable, Sendable {
    let home: Team
    let away: Team
}

struct Lineups: Codable, Sendable {
    let home: [ScorecardBatter]
    let away: [ScorecardBatter]
}

struct ScorecardBatter: Codable, Identifiable, Sendable {
    let id: Int
    let fullName: String
    let abbreviation: String
    let position: String
    let inningEntered: Int?
    let inningExited: Int?
}

struct ScorecardInning: Codable, Sendable {
    let num: Int
    let ordinal: String
    let home: [AtBatEvent]
    let away: [AtBatEvent]
}

struct AtBatEvent: Codable, Sendable {
    let batterId: Int
    let result: String // e.g., "1B", "K", "HR", "F8"
    let description: String
    let balls: Int
    let strikes: Int
    let outs: Int
    let rbi: Int
    let bases: BasesReached
    let pitches: [PitchEvent]?
}

struct PitchEvent: Codable, Sendable {
    let pitchNumber: Int
    let description: String
    let outcome: String // "Ball", "Strike", "Foul", "In Play"
    let speed: Double?
    
    // Strike Zone Data (ft)
    // x: Horizontal (0 is center), z: Vertical Height
    let x: Double?
    let z: Double?
    let zoneTop: Double?
    let zoneBottom: Double?
}

struct BasesReached: Codable, Sendable {
    let first: Bool
    let second: Bool
    let third: Bool
    let home: Bool
    
    // Outs between bases
    let outAtFirst: Bool?
    let outAtSecond: Bool?
    let outAtThird: Bool?
    let outAtHome: Bool?
}
