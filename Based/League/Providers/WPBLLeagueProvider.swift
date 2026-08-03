import Foundation

/// Placeholder — replaced with a real implementation in M3 (WPBLAPIClient/WPBLAPIModels/
/// WPBLBoxscoreTransformer). Exists now only so LeagueRegistry compiles and the app builds
/// end-to-end while M2 wires up the MLB path.
final class WPBLLeagueProvider: LeagueProvider {
    let league: League = .wpbl
    let supportsWildcardStandings = false

    func fetchSchedule(date: Date) async throws -> [LeagueGame] { [] }
    func fetchTeamSchedule(teamID: String) async throws -> [LeagueGame] { [] }
    func fetchTeams() async throws -> [LeagueTeam] { [] }
    func fetchStandings() async throws -> [StandingsSection] { [] }
    func fetchWildcardStandings() async throws -> [StandingsSection] { [] }
    func fetchRoster(teamID: String) async throws -> [LeagueRosterPlayer] { [] }
    func fetchPlayerSeasonStats(playerID: String) async throws -> PlayerSeasonStats? { nil }

    func makeGameDetailDataSource(gameID: String) -> GameDetailDataSource {
        fatalError("WPBLLeagueProvider.makeGameDetailDataSource not yet implemented (see M3/M4)")
    }
}
