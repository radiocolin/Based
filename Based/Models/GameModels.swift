import Foundation

struct Linescore: Codable, Sendable, Equatable {
    let currentInning: Int?
    let currentInningOrdinal: String?
    let inningState: String?
    let inningHalf: String?
    let isTopInning: Bool?
    let scheduledInnings: Int?
    let innings: [Inning]?
    let teams: LinescoreTeams?
    let offense: Offense?
    let defense: Defense?
    let balls: Int?
    let strikes: Int?
    let outs: Int?
    let currentPitchCount: Int?
    let currentPitches: [PitchEvent]?
    let venue: Venue?
    let weather: Weather?
}

struct Venue: Codable, Sendable, Equatable {
    let id: Int?
    let name: String?
    let location: VenueLocation?
}

struct VenueLocation: Codable, Sendable, Equatable {
    let city: String?
    let state: String?
    let stateAbbrev: String?
}

struct Weather: Codable, Sendable, Equatable {
    let condition: String?
    let temp: String?
    let wind: String?
}

struct Inning: Codable, Sendable, Equatable {
    let num: Int?
    let ordinalNum: String?
    let home: InningStats?
    let away: InningStats?
}

struct InningStats: Codable, Sendable, Equatable {
    let runs: Int?
    let hits: Int?
    let errors: Int?
    let leftOnBase: Int?
}

struct LinescoreTeams: Codable, Sendable, Equatable {
    let home: TeamGameStats?
    let away: TeamGameStats?
}

struct TeamGameStats: Codable, Sendable, Equatable {
    let team: Team?
    let runs: Int?
    let hits: Int?
    let errors: Int?
    let leftOnBase: Int?
    let moundVisitsRemaining: Int?
    let challenges: Challenges?
}

struct Challenges: Codable, Sendable, Equatable {
    let used: Int?
    let remaining: Int?
    let successful: Int?
}

struct Team: Codable, Sendable, Equatable {
    let id: Int?
    let name: String?
    let link: String?
}

struct Offense: Codable, Sendable, Equatable {
    let batter: Player?
    let onDeck: Player?
    let inHole: Player?
    let pitcher: Player?
    let first: Player?
    let second: Player?
    let third: Player?
    let team: Team?
}

struct Defense: Codable, Sendable, Equatable {
    let pitcher: Player?
    let catcher: Player?
    let first: Player?
    let second: Player?
    let third: Player?
    let shortstop: Player?
    let left: Player?
    let center: Player?
    let right: Player?
    let team: Team?
}

struct Player: Codable, Sendable, Equatable {
    let id: Int?
    let fullName: String?
    let link: String?
}

// MARK: - Player Info (from /api/v1/people endpoint)

struct PlayerInfoResponse: Decodable, Sendable {
    let people: [PlayerInfo]?
}

struct PlayerInfo: Decodable, Sendable {
    let id: Int?
    let fullName: String?
    let firstName: String?
    let lastName: String?
    let primaryNumber: String?
    let birthDate: String?
    let currentAge: Int?
    let birthCity: String?
    let birthCountry: String?
    let height: String?
    let weight: Int?
    let primaryPosition: Position?
    let batSide: HandSide?
    let pitchHand: HandSide?
    let currentTeam: TeamInfo?
    let stats: [StatGroup]?
}

struct Position: Codable, Sendable, Equatable {
    let code: String?
    let name: String?
    let type: String?
    let abbreviation: String?
}

struct HandSide: Codable, Sendable {
    let code: String?
    let description: String?
}

struct TeamInfo: Codable, Sendable {
    let id: Int?
    let name: String?
}

struct StatGroup: Decodable, Sendable {
    let type: StatType?
    let group: StatGroupType?
    let splits: [StatSplit]?
}

struct StatType: Decodable, Sendable {
    let displayName: String?
}

struct StatGroupType: Decodable, Sendable {
    let displayName: String?
}

struct StatSplit: Decodable, Sendable {
    let season: String?
    let stat: SeasonStatLine?
}

struct SeasonStatLine: Codable, Sendable {
    let gamesPlayed: Int?
    let atBats: Int?
    let runs: Int?
    let hits: Int?
    let doubles: Int?
    let triples: Int?
    let homeRuns: Int?
    let rbi: Int?
    let stolenBases: Int?
    let caughtStealing: Int?
    let baseOnBalls: Int?
    let strikeOuts: Int?
    let avg: String?
    let obp: String?
    let slg: String?
    let ops: String?
    let gamesStarted: Int?
    let groundOuts: Int?
    let airOuts: Int?
    let era: String?
    let inningsPitched: String?
    let wins: Int?
    let losses: Int?
    let saves: Int?
    let holds: Int?
    let blownSaves: Int?
}

struct BattingStats: Codable, Sendable {
    let gamesPlayed: Int?
    let atBats: Int?
    let runs: Int?
    let hits: Int?
    let doubles: Int?
    let triples: Int?
    let homeRuns: Int?
    let rbi: Int?
    let stolenBases: Int?
    let caughtStealing: Int?
    let baseOnBalls: Int?
    let strikeOuts: Int?
    let avg: String?
    let obp: String?
    let slg: String?
    let ops: String?
}
