import Foundation

struct LeagueGame: Identifiable, Hashable, Sendable {
    let id: String
    let league: League
    let homeTeamID: String
    let awayTeamID: String
    let homeTeamName: String
    let awayTeamName: String
    let startDate: Date
    let status: LeagueGameStatus
    let homeScore: Int?
    let awayScore: Int?
}

enum LeagueGameStatus: Hashable, Sendable {
    case scheduled
    case live
    case final
    /// Anything that doesn't cleanly map to the three cases above (postponed, suspended, weather delay, ...).
    /// Carries the source's own display text so the UI can still show something meaningful.
    case other(String)

    var isLive: Bool { self == .live }

    var isFinal: Bool {
        if case .final = self { return true }
        return false
    }
}
