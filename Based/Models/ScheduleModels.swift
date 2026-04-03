import Foundation

// MARK: - Schedule API Response (/api/v1/schedule)

struct ScheduleResponse: Codable, Sendable {
    let dates: [ScheduleDate]
}

struct ScheduleDate: Codable, Sendable {
    let date: String
    let games: [ScheduleGame]
}

struct ScheduleGame: Codable, Sendable {
    let gamePk: Int
    let gameDate: String
    let status: GameStatus
    let teams: ScheduleTeams
    let venue: Venue?
}

struct GameStatus: Codable, Sendable {
    let detailedState: String
    let statusCode: String?
}

struct ScheduleTeams: Codable, Sendable {
    let away: ScheduleTeamInfo
    let home: ScheduleTeamInfo
}

struct ScheduleTeamInfo: Codable, Sendable {
    let team: Team
    let score: Int?
}
