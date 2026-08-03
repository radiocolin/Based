import Foundation

struct LeagueTeam: Identifiable, Hashable, Sendable {
    let id: String
    let league: League
    let name: String
    let shortName: String?
}
