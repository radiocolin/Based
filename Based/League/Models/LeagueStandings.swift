import Foundation

/// One group of standings rows. A `title` of `nil` renders as a plain, headerless table —
/// this is how a flat single-table league (WPBL) and a divisional league (MLB) share one
/// rendering path with no per-league branching in the view layer.
struct StandingsSection: Identifiable, Sendable {
    let id: String
    let title: String?
    let rows: [StandingsRow]
}

enum StandingsRow: Sendable {
    case subHeader(String)
    case team(StandingsTeamRow)
}

struct StandingsTeamRow: Identifiable, Sendable {
    let id: String
    let teamID: String
    let teamName: String
    /// Division rank ("1", "2", ...) in division mode; "L" (leader) or wildcard slot number in wildcard mode.
    let rank: String
    let wins: Int
    let losses: Int
    let winPercentage: String
    let gamesBack: String?
    let wildCardGamesBack: String?
    let lastTen: String?
    let streak: String?
    let runDifferential: Int?
}
