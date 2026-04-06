import Foundation

// MARK: - Play By Play

struct PlayByPlayResponse: Codable, Sendable {
    let allPlays: [Play]?
    let currentPlay: Play?
}

struct Play: Codable, Sendable {
    let result: PlayResult?
    let about: PlayAbout?
    let count: PlayCount?
    let matchup: Matchup?
    let playEvents: [PlayEvent]?
    let runners: [RunnerMovement]?
}

struct RunnerMovement: Codable, Sendable {
    let movement: Movement?
    let details: RunnerDetails?
    let credits: [PlayCredit]?
}

struct Movement: Codable, Sendable {
    let originBase: String?
    let start: String?
    let end: String?
    let outBase: String?
    let isOut: Bool?
}

struct RunnerDetails: Codable, Sendable {
    let event: String?
    let eventType: String?
    let runner: Player?
    let isScoringEvent: Bool?
    let rbi: Bool?
}

struct PlayCredit: Codable, Sendable {
    let player: Player?
    let position: Position?
    let credit: String?
}

struct HitData: Codable, Sendable {
    let launchSpeed: Double?
    let launchAngle: Double?
    let totalDistance: Double?
    let trajectory: String?
    let hardness: String?
    let location: String?
}

struct PlayResult: Codable, Sendable {
    let type: String?
    let event: String?
    let eventType: String?
    let description: String?
    let rbi: Int?
    let awayScore: Int?
    let homeScore: Int?
}

struct PlayAbout: Codable, Sendable {
    let atBatIndex: Int?
    let halfInning: String?
    let isTopInning: Bool?
    let inning: Int?
    let startTime: String?
    let endTime: String?
    let isComplete: Bool?
}

struct PlayCount: Codable, Sendable {
    let balls: Int?
    let strikes: Int?
    let outs: Int?
}

struct Matchup: Codable, Sendable {
    let batter: Player?
    let pitcher: Player?
    let batterHotColdZones: [HotColdZone]?
}

struct HotColdZone: Codable, Sendable {
    let zone: String?
    let color: String?
    let temp: String?
}

struct PlayEvent: Codable, Sendable {
    let details: PlayEventDetails?
    let pitchType: CodeDescription?
    let count: PlayCount?
    let pitchData: PitchData?
    let hitData: HitData?
    let index: Int?
    let startTime: String?
    let endTime: String?
    let isPitch: Bool?
    let type: String?
    let player: Player?
    let replacedPlayer: Player?
    let isSubstitution: Bool?
}

struct PlayEventDetails: Codable, Sendable {
    let call: CodeDescription?
    let description: String?
    let code: String?
    let ballColor: String?
    let trailColor: String?
}

struct CodeDescription: Codable, Sendable {
    let code: String?
    let description: String?
}

struct PitchData: Codable, Sendable {
    let startSpeed: Double?
    let endSpeed: Double?
    let strikeZoneTop: Double?
    let strikeZoneBottom: Double?
    let coordinates: PitchCoordinates?
}

struct PitchCoordinates: Codable, Sendable {
    let x: Double?
    let y: Double?
    let pX: Double?
    let pZ: Double?
}

// MARK: - Boxscore

struct BoxscoreResponse: Codable, Sendable {
    let teams: BoxscoreTeams?
    let officials: [Official]?
    let info: [BoxscoreNote]?
}

struct BoxscoreNote: Codable, Sendable {
    let label: String?
    let value: String?
}

// MARK: - Live Feed

struct LiveFeedResponse: Codable, Sendable {
    let gameData: GameData?
}

struct GameData: Codable, Sendable {
    let status: GameStatus?
    let moundVisits: MoundVisits?
    let absChallenges: ABSChallenges?
    let weather: Weather?
}

struct MoundVisits: Codable, Sendable {
    let away: MoundVisitStats?
    let home: MoundVisitStats?
}

struct MoundVisitStats: Codable, Sendable {
    let used: Int?
    let remaining: Int?
}

struct ABSChallenges: Codable, Sendable {
    let hasChallenges: Bool?
    let away: ChallengeStats?
    let home: ChallengeStats?
}

struct ChallengeStats: Codable, Sendable {
    let remaining: Int?
}

struct Official: Codable, Sendable {
    let official: Player?
    let officialType: String?
}

struct BoxscoreTeams: Codable, Sendable {
    let away: BoxscoreTeam?
    let home: BoxscoreTeam?
}

struct BoxscoreTeam: Codable, Sendable {
    let team: Team?
    let players: [String: BoxscorePlayer]?
    let batters: [Int]?
    let pitchers: [Int]?
    let bench: [Int]?
    let bullpen: [Int]?
    let battingOrder: [Int]?
}

struct BoxscorePlayer: Codable, Sendable {
    let person: Player?
    let jerseyNumber: String?
    let position: Position?
    let stats: PlayerStats?
    let seasonStats: PlayerStats?
    let gameStatus: GameStatusInfo?
}

struct GameStatusRestObject: Codable, Sendable {
    let isCurrentBatter: Bool?
    let isCurrentPitcher: Bool?
    let isOnBench: Bool?
    let isSubstitute: Bool?
}

struct GameStatusInfo: Codable, Sendable {
    let isCurrentBatter: Bool?
    let isCurrentPitcher: Bool?
    let isOnBench: Bool?
    let isSubstitute: Bool?
}

struct PlayerStats: Codable, Sendable {
    let batting: BattingStats?
    let pitching: PitchingStats?
}

struct PitchingStats: Codable, Sendable {
    let gamesPlayed: Int?
    let gamesStarted: Int?
    let groundOuts: Int?
    let airOuts: Int?
    let runs: Int?
    let doubles: Int?
    let triples: Int?
    let homeRuns: Int?
    let strikeOuts: Int?
    let baseOnBalls: Int?
    let hits: Int?
    let avg: String?
    let era: String?
    let inningsPitched: String?
    let wins: Int?
    let losses: Int?
    let saves: Int?
    let holds: Int?
    let blownSaves: Int?
}
