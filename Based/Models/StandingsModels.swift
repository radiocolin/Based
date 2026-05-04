import Foundation

struct StandingsResponse: Decodable, Sendable {
    let records: [StandingsRecord]
}

struct StandingsRecord: Decodable, Sendable {
    let league: StandingsLeague?
    let division: StandingsDivision
    let teamRecords: [TeamRecord]
}

struct StandingsLeague: Decodable, Sendable {
    let id: Int
    let name: String?
}

struct StandingsDivision: Decodable, Sendable {
    let id: Int
    let name: String?
}

struct TeamRecord: Decodable, Sendable {
    let team: Team
    let leagueRecord: LeagueRecord
    let gamesBack: String?
    let wildCardGamesBack: String?
    let divisionRank: String?
    let runsScored: Int?
    let runsAllowed: Int?
    let runDifferential: Int?
    let streak: TeamStreak?
    let records: TeamRecords?
}

struct LeagueRecord: Decodable, Sendable {
    let wins: Int
    let losses: Int
    let pct: String?
}

struct TeamStreak: Decodable, Sendable {
    let streakCode: String?
}

struct TeamRecords: Decodable, Sendable {
    let splitRecords: [SplitRecord]?
}

struct SplitRecord: Decodable, Sendable {
    let type: String?
    let wins: Int?
    let losses: Int?
}
