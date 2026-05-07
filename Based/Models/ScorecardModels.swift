import Foundation

// MARK: - Scorecard Result

enum ScorecardResult: Sendable, Equatable {
    case single
    case double
    case triple
    case homeRun
    case walk
    case intentionalWalk
    case hitByPitch
    case strikeoutSwinging
    case strikeoutLooking
    case flyout(position: String)
    case popout(position: String)
    case lineout(position: String)
    case groundout(sequence: String)
    case forceOut(sequence: String)
    case fieldersChoice
    case doublePlay(sequence: String)
    case triplePlay
    case sacFly(position: String?)
    case sacBunt
    case fieldError
    case stolenBase
    case caughtStealing
    case pickoff
    case balk
    case wildPitch
    case passedBall
    case live
    case runnerOnly
    case empty
    case other(text: String)

    var displayText: String {
        switch self {
        case .single: return "1B"
        case .double: return "2B"
        case .triple: return "3B"
        case .homeRun: return "HR"
        case .walk: return "BB"
        case .intentionalWalk: return "IBB"
        case .hitByPitch: return "HBP"
        case .strikeoutSwinging: return "K"
        case .strikeoutLooking: return "K"
        case .flyout(let pos): return "F\(pos)"
        case .popout(let pos): return "P\(pos)"
        case .lineout(let pos): return "L\(pos)"
        case .groundout(let seq): return seq
        case .forceOut(let seq): return "FO\n\(seq)"
        case .fieldersChoice: return "FC"
        case .doublePlay(let seq): return "\(seq)\nGIDP"
        case .triplePlay: return "TP"
        case .sacFly(let pos):
            if let pos { return "SAC\nF\(pos)" }
            return "SAC"
        case .sacBunt: return "SAC"
        case .fieldError: return "E"
        case .stolenBase: return "SB"
        case .caughtStealing: return "CS"
        case .pickoff: return "PO"
        case .balk: return "BK"
        case .wildPitch: return "WP"
        case .passedBall: return "PB"
        case .live: return "LIVE"
        case .runnerOnly: return "Z"
        case .empty: return ""
        case .other(let text): return text
        }
    }

    var isHit: Bool {
        switch self {
        case .single, .double, .triple, .homeRun: return true
        default: return false
        }
    }

    var isWalk: Bool {
        switch self {
        case .walk, .intentionalWalk, .hitByPitch: return true
        default: return false
        }
    }

    var isSacrifice: Bool {
        switch self {
        case .sacFly, .sacBunt: return true
        default: return false
        }
    }

    var isStrikeout: Bool {
        switch self {
        case .strikeoutSwinging, .strikeoutLooking: return true
        default: return false
        }
    }

    var isCalledStrikeout: Bool { self == .strikeoutLooking }
    var isHomeRun: Bool { self == .homeRun }
    var isLive: Bool { self == .live }
    var countsAsAtBat: Bool { !isWalk && !isSacrifice }
}

extension ScorecardResult: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.parse(raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(encodingText)
    }

    private var encodingText: String {
        if case .strikeoutLooking = self { return "Ʞ" }
        return displayText
    }

    static func parse(_ text: String) -> ScorecardResult {
        switch text {
        case "1B": return .single
        case "2B": return .double
        case "3B": return .triple
        case "HR": return .homeRun
        case "BB": return .walk
        case "IBB": return .intentionalWalk
        case "HBP": return .hitByPitch
        case "K": return .strikeoutSwinging
        case "Ʞ": return .strikeoutLooking
        case "FC": return .fieldersChoice
        case "TP": return .triplePlay
        case "SAC": return .sacBunt
        case "E": return .fieldError
        case "SB": return .stolenBase
        case "CS": return .caughtStealing
        case "PO": return .pickoff
        case "BK": return .balk
        case "WP": return .wildPitch
        case "PB": return .passedBall
        case "FO": return .forceOut(sequence: "")
        case "GIDP": return .doublePlay(sequence: "")
        case "LIVE": return .live
        case "Z": return .runnerOnly
        case "": return .empty
        default:
            let lines = text.split(separator: "\n", maxSplits: 1).map(String.init)
            if lines.count == 2 {
                if lines[1] == "GIDP" { return .doublePlay(sequence: lines[0]) }
                if lines[0] == "FO" { return .forceOut(sequence: lines[1]) }
                if lines[0] == "SAC" && lines[1].hasPrefix("F") {
                    return .sacFly(position: String(lines[1].dropFirst()))
                }
            }
            if text.hasPrefix("F") && text.count <= 3 && text.dropFirst().allSatisfy(\.isNumber) {
                return .flyout(position: String(text.dropFirst()))
            }
            if text.hasPrefix("P") && text.count <= 3 && text.dropFirst().allSatisfy(\.isNumber) {
                return .popout(position: String(text.dropFirst()))
            }
            if text.hasPrefix("L") && text.count <= 3 && text.dropFirst().allSatisfy(\.isNumber) {
                return .lineout(position: String(text.dropFirst()))
            }
            if text.contains("-") && !text.contains("\n") {
                return .groundout(sequence: text)
            }
            return .other(text: text)
        }
    }
}

// MARK: - Runner Base State

struct RunnerBaseState {
    var reachFirst = false
    var reachSecond = false
    var reachThird = false
    var reachHome = false
    var outAtFirst = false
    var outAtSecond = false
    var outAtThird = false
    var outAtHome = false
    var annotations: [BaseAnnotation] = []
    var pinchRunnerName: String?

    mutating func applyInitialReach(for eventType: String) {
        switch eventType {
        case "single", "walk", "hit_by_pitch", "intent_walk", "field_error", "fielders_choice":
            reachFirst = true
        case "double":
            reachFirst = true; reachSecond = true
        case "triple":
            reachFirst = true; reachSecond = true; reachThird = true
        case "home_run":
            reachFirst = true; reachSecond = true; reachThird = true; reachHome = true
        default:
            break
        }
    }

    mutating func advanceBatter(to end: String) {
        switch end {
        case "1b": reachFirst = true
        case "2b": reachFirst = true; reachSecond = true
        case "3b": reachFirst = true; reachSecond = true; reachThird = true
        case "score", "home": reachFirst = true; reachSecond = true; reachThird = true; reachHome = true
        default: break
        }
    }

    mutating func advanceRunner(to end: String) {
        switch end {
        case "1b": reachFirst = true
        case "2b": reachSecond = true; lineToSecond = true
        case "3b": reachThird = true; lineToThird = true
        case "score", "home":
            if reachSecond { reachThird = true; lineToThird = true }
            reachHome = true; lineToHome = true
        default: break
        }
    }

    mutating func recordOut(at base: String) {
        switch base {
        case "1b": reachFirst = false; outAtFirst = true
        case "2b": reachSecond = false; outAtSecond = true
        case "3b": reachThird = false; outAtThird = true
        case "home": reachHome = false; outAtHome = true
        default: break
        }
    }

    var isResolved: Bool {
        reachHome || outAtFirst || outAtSecond || outAtThird || outAtHome
    }

    var currentBase: Int? {
        if reachHome { return 4 }
        if reachThird { return 3 }
        if reachSecond { return 2 }
        if reachFirst { return 1 }
        return nil
    }

    // Line-to fields for placed runners (who advance from a starting base)
    var lineToSecond = false
    var lineToThird = false
    var lineToHome = false

    func toBasesReached(includeLines: Bool = false) -> BasesReached {
        BasesReached(
            first: reachFirst,
            second: reachSecond,
            third: reachThird,
            home: reachHome,
            lineToFirst: includeLines ? (reachFirst ? true : nil) : nil,
            lineToSecond: includeLines ? (lineToSecond ? true : nil) : nil,
            lineToThird: includeLines ? (lineToThird ? true : nil) : nil,
            lineToHome: includeLines ? (lineToHome ? true : nil) : nil,
            outAtFirst: outAtFirst,
            outAtSecond: outAtSecond,
            outAtThird: outAtThird,
            outAtHome: outAtHome,
            annotations: annotations.isEmpty ? nil : annotations
        )
    }
}

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
    let homeRuns: Int?
    let awayRuns: Int?
    let homeScoringPlayerIds: [Int]
    let awayScoringPlayerIds: [Int]
}

struct AtBatEvent: Codable, Sendable, Equatable {
    let atBatIndex: Int?
    let batterId: Int
    let batterName: String
    let pinchRunnerName: String?
    let pitcherId: Int
    let pitcherName: String
    let inning: Int
    let isTop: Bool
    let result: ScorecardResult
    let description: String
    let balls: Int
    let strikes: Int
    let outs: Int
    let rbi: Int
    let isRunnerOnly: Bool
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
