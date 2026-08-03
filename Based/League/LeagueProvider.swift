import Foundation

/// Adding a new league is implementing this protocol, not modifying an existing one.
protocol LeagueProvider: Sendable {
    var league: League { get }
    /// False for leagues too small to have a wild-card race (e.g. WPBL's 4-team single table) —
    /// the standings screen hides its Division/Wildcard toggle entirely rather than showing an
    /// empty second tab.
    var supportsWildcardStandings: Bool { get }

    func fetchSchedule(date: Date) async throws -> [LeagueGame]
    func fetchTeamSchedule(teamID: String) async throws -> [LeagueGame]
    func fetchTeams() async throws -> [LeagueTeam]
    func fetchStandings() async throws -> [StandingsSection]
    func fetchWildcardStandings() async throws -> [StandingsSection]
    func fetchRoster(teamID: String) async throws -> [LeagueRosterPlayer]
    func fetchPlayerSeasonStats(playerID: String) async throws -> PlayerSeasonStats?
    func makeGameDetailDataSource(gameID: String) -> GameDetailDataSource
}
