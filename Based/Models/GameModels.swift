import Foundation

struct Linescore: Codable, Sendable {
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

struct Venue: Codable, Sendable {
    let id: Int?
    let name: String?
    let location: VenueLocation?
}

struct VenueLocation: Codable, Sendable {
    let city: String?
    let state: String?
    let stateAbbrev: String?
}

struct Weather: Codable, Sendable {
    let condition: String?
    let temp: String?
    let wind: String?
}

struct Inning: Codable, Sendable {
    let num: Int?
    let ordinalNum: String?
    let home: InningStats?
    let away: InningStats?
}

struct InningStats: Codable, Sendable {
    let runs: Int?
    let hits: Int?
    let errors: Int?
    let leftOnBase: Int?
}

struct LinescoreTeams: Codable, Sendable {
    let home: TeamGameStats?
    let away: TeamGameStats?
}

struct TeamGameStats: Codable, Sendable {
    let team: Team?
    let runs: Int?
    let hits: Int?
    let errors: Int?
    let leftOnBase: Int?
    let moundVisitsRemaining: Int?
    let challenges: Challenges?
}

struct Challenges: Codable, Sendable {
    let used: Int?
    let remaining: Int?
    let successful: Int?
}

struct Team: Codable, Sendable {
    let id: Int?
    let name: String?
    let link: String?
}

struct Offense: Codable, Sendable {
    let batter: Player?
    let onDeck: Player?
    let inHole: Player?
    let pitcher: Player?
    let first: Player?
    let second: Player?
    let third: Player?
    let team: Team?
}

struct Defense: Codable, Sendable {
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

struct Player: Codable, Sendable {
    let id: Int?
    let fullName: String?
    let link: String?
}

// MARK: - Player Info (from /api/v1/people endpoint)

struct PlayerInfoResponse: Codable, Sendable {
    let people: [PlayerInfo]?
}

struct PlayerInfo: Codable, Sendable {
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

struct Position: Codable, Sendable {
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

struct StatGroup: Codable, Sendable {
    let type: StatType?
    let group: StatGroupType?
    let splits: [StatSplit]?
}

struct StatType: Codable, Sendable {
    let displayName: String?
}

struct StatGroupType: Codable, Sendable {
    let displayName: String?
}

struct StatSplit: Codable, Sendable {
    let season: String?
    let stat: BattingStats?
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
