import Foundation

// MARK: - Scorecard Model
struct ScorecardData: Codable, Sendable, Equatable {
    let teams: ScorecardTeams
    let lineups: Lineups
    let pitchers: ScorecardPitchers
    let innings: [ScorecardInning]
    let timeline: [AtBatEvent]
    let liveCurrentAtBat: AtBatEvent?
    let advisories: [String]
    let umpires: [ScorecardUmpire]
    let gameInfo: [GameInfoItem]
    let currentInning: Int?
    let isTopInning: Bool?
    let currentBatterId: Int?
}

struct GameInfoItem: Codable, Sendable, Equatable {
    let label: String
    let value: String?
}

struct ScorecardUmpire: Codable, Sendable, Equatable {
    let fullName: String
    let type: String // HP, 1B, 2B, 3B
}

struct ScorecardPitchers: Codable, Sendable, Equatable {
    let home: [ScorecardPitcher]
    let away: [ScorecardPitcher]
}

struct ScorecardPitcher: Codable, Sendable, Equatable {
    let id: Int
    let fullName: String
    let stats: String
    let ip: String
    let h: Int
    let r: Int
    let er: Int
    let bb: Int
    let k: Int
}

struct ScorecardTeams: Codable, Sendable, Equatable {
    let home: Team
    let away: Team
}

struct Lineups: Codable, Sendable, Equatable {
    let home: [ScorecardBatter]
    let away: [ScorecardBatter]
}

struct ScorecardBatter: Codable, Identifiable, Sendable, Equatable {
    let id: Int
    let fullName: String
    let abbreviation: String
    let position: String
    let jerseyNumber: String?
    let inningEntered: Int?
    let inningExited: Int?
}

struct ScorecardInning: Codable, Sendable, Equatable {
    let num: Int
    let ordinal: String
    let home: [AtBatEvent]
    let away: [AtBatEvent]
    let homeRuns: Int?  // Authoritative from linescore (nil if inning hasn't started)
    let awayRuns: Int?  // Authoritative from linescore (nil if inning hasn't started)
}

struct AtBatEvent: Codable, Sendable, Equatable {
    let batterId: Int
    let batterName: String
    let pitcherId: Int
    let pitcherName: String
    let inning: Int
    let isTop: Bool
    let result: String // e.g., "1B", "K", "HR", "F8"
    let description: String
    let balls: Int
    let strikes: Int
    let outs: Int
    let rbi: Int
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
    
    // Outs between bases
    let outAtFirst: Bool?
    let outAtSecond: Bool?
    let outAtThird: Bool?
    let outAtHome: Bool?
    
    // Diamond annotations (errors, stolen bases, caught stealing)
    let annotations: [BaseAnnotation]?
}

// MARK: - Column Layout (batting-around support)

struct InningColumnLayout: Codable, Sendable {
    let inningNum: Int
    let subColumnCount: Int
    let startColumn: Int
}

struct ColumnLayout: Codable, Sendable {
    let innings: [InningColumnLayout]
    let statColumns: [String]
    let totalColumns: Int
    
    init(innings: [InningColumnLayout], statColumns: [String] = ["AB", "R", "H", "RBI"]) {
        self.innings = innings
        self.statColumns = statColumns
        let lastInningCol = innings.last.map { $0.startColumn + $0.subColumnCount } ?? 0
        self.totalColumns = lastInningCol + statColumns.count
    }
    
    func inningInfo(forColumn col: Int) -> (inningNum: Int, subIndex: Int)? {
        for inning in innings {
            if col >= inning.startColumn && col < inning.startColumn + inning.subColumnCount {
                return (inning.inningNum, col - inning.startColumn)
            }
        }
        return nil
    }
    
    func statInfo(forColumn col: Int) -> String? {
        let lastInningCol = innings.last.map { $0.startColumn + $0.subColumnCount } ?? 0
        let statIndex = col - lastInningCol
        if statIndex >= 0 && statIndex < statColumns.count {
            return statColumns[statIndex]
        }
        return nil
    }
    
    func layout(forInning num: Int) -> InningColumnLayout? {
        return innings.first { $0.inningNum == num }
    }
}

// MARK: - Player Game Stats Model
struct PlayerGameStats: Codable, Sendable {
    let atBats: Int
    let hits: Int
    let runs: Int
    let rbi: Int
    let walks: Int
    let strikeouts: Int
}

extension ScorecardData {
    func calculatePlayerStats(for batterId: Int, isHome: Bool) -> PlayerGameStats {
        var atBats = 0, hits = 0, runs = 0, rbi = 0, walks = 0, strikeouts = 0
        for inning in innings {
            let events = isHome ? inning.home : inning.away
            for event in events where event.batterId == batterId {
                let result = event.result
                if result == "BB" || result == "IBB" || result == "HBP" { walks += 1 }
                else if result == "SF" || result == "SAC" {}
                else {
                    atBats += 1
                    if ["1B", "2B", "3B", "HR"].contains(result) { hits += 1 }
                }
                if event.bases.home { runs += 1 }
                rbi += event.rbi
                if result == "K" || result == "Ʞ" { strikeouts += 1 }
            }
        }
        return PlayerGameStats(atBats: atBats, hits: hits, runs: runs, rbi: rbi, walks: walks, strikeouts: strikeouts)
    }
}
