import Foundation

// MARK: - Scorecard Model
struct ScorecardData: Codable, Sendable {
    let teams: ScorecardTeams
    let lineups: Lineups
    let pitchers: ScorecardPitchers
    let innings: [ScorecardInning]
    let advisories: [String]
    let umpires: [ScorecardUmpire]
    let gameInfo: [GameInfoItem]
    let currentInning: Int?
    let isTopInning: Bool?
    let currentBatterId: Int?
}

struct GameInfoItem: Codable, Sendable {
    let label: String
    let value: String?
}

struct ScorecardUmpire: Codable, Sendable {
    let fullName: String
    let type: String // HP, 1B, 2B, 3B
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
    let jerseyNumber: String?
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

// MARK: - Column Layout (batting-around support)

struct InningColumnLayout {
    let inningNum: Int
    let subColumnCount: Int
    let startColumn: Int
}

struct ColumnLayout {
    let innings: [InningColumnLayout]
    let totalColumns: Int
    
    func inningInfo(forColumn col: Int) -> (inningNum: Int, subIndex: Int)? {
        for inning in innings {
            if col >= inning.startColumn && col < inning.startColumn + inning.subColumnCount {
                return (inning.inningNum, col - inning.startColumn)
            }
        }
        return nil
    }
    
    func layout(forInning num: Int) -> InningColumnLayout? {
        return innings.first { $0.inningNum == num }
    }
}
