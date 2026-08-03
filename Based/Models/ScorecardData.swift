import Foundation

// MARK: - Scorecard Data Model

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
    let gameDate: String?
    let currentInning: Int?
    let isTopInning: Bool?
    let currentBatterId: String?
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
    let id: String
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

struct ScorecardInning: Codable, Sendable, Equatable {
    let num: Int
    let ordinal: String
    let home: [AtBatEvent]
    let away: [AtBatEvent]
    let homeRuns: Int?
    let awayRuns: Int?
    let homeScoringPlayerIds: [String]
    let awayScoringPlayerIds: [String]
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

// MARK: - Compact Layout (order-based columns)

struct CompactColumn: Codable, Sendable {
    let index: Int
    let inningStart: Int
    let inningEnd: Int
    let leadoffLineupIndex: Int
}

struct CompactColumnLayout: Codable, Sendable {
    let columns: [CompactColumn]
    let columnLayout: ColumnLayout
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
    func events(inningNum: Int, isHomeBatting: Bool, includeLiveCurrentAtBat: Bool = true) -> [AtBatEvent] {
        let inningEvents = innings.first(where: { $0.num == inningNum }).map {
            isHomeBatting ? $0.home : $0.away
        } ?? []

        guard includeLiveCurrentAtBat,
              let liveCurrentAtBat,
              liveCurrentAtBat.inning == inningNum,
              liveCurrentAtBat.isTop != isHomeBatting,
              !inningEvents.contains(where: { $0.atBatIndex == liveCurrentAtBat.atBatIndex && $0.atBatIndex != nil }) else {
            return inningEvents
        }

        return inningEvents + [liveCurrentAtBat]
    }

    func calculatePlayerStats(for batterId: String, isHome: Bool) -> PlayerGameStats {
        var atBats = 0, hits = 0, runs = 0, rbi = 0, walks = 0, strikeouts = 0
        for inning in innings {
            let events = isHome ? inning.home : inning.away
            for event in events where event.batterId == batterId {
                if event.isRunnerOnly { continue }
                let result = event.result
                if result.isWalk { walks += 1 }
                else if result.isSacrifice {}
                else {
                    atBats += 1
                    if result.isHit { hits += 1 }
                }
                rbi += event.rbi
                if result.isStrikeout { strikeouts += 1 }
            }
            let scoringPlayerIds = isHome ? inning.homeScoringPlayerIds : inning.awayScoringPlayerIds
            if scoringPlayerIds.contains(batterId) {
                runs += 1
            }
        }
        return PlayerGameStats(atBats: atBats, hits: hits, runs: runs, rbi: rbi, walks: walks, strikeouts: strikeouts)
    }
}
