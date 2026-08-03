import Foundation

final class WPBLLeagueProvider: LeagueProvider {
    let league: League = .wpbl
    let supportsWildcardStandings = false

    private let client = WPBLAPIClient.shared

    /// WPBL's /v1/games occasionally includes placeholder entries with no teams assigned yet
    /// (home_team_id/away_team_id both "", presto_data.teams both null) — not TBD-flagged
    /// (presto_data.tba is false on them too), just genuinely empty. Filter those out everywhere
    /// rather than showing an unusable blank game card.
    private func wellFormedGames() async throws -> [WPBLGame] {
        try await client.fetchGames().filter { !$0.homeTeamId.isEmpty && !$0.awayTeamId.isEmpty }
    }

    func fetchSchedule(date: Date) async throws -> [LeagueGame] {
        try await wellFormedGames()
            .filter { game in
                guard let start = Self.parseISODate(game.scheduledStart) else { return false }
                return Calendar.current.isDate(start, inSameDayAs: date)
            }
            .map(Self.makeLeagueGame)
    }

    func fetchTeamSchedule(teamID: String) async throws -> [LeagueGame] {
        try await wellFormedGames()
            .filter { $0.homeTeamId == teamID || $0.awayTeamId == teamID }
            .map(Self.makeLeagueGame)
    }

    func fetchTeams() async throws -> [LeagueTeam] {
        try await client.fetchTeams().map {
            LeagueTeam(id: $0.teamId, league: .wpbl, name: $0.teamName, shortName: nil)
        }
    }

    /// Always derived from completed games' scores — /v1/teams' own wins/losses/record fields
    /// are demonstrated stale (reported 0-0 even after real games completed, per WPBL.md).
    func fetchStandings() async throws -> [StandingsSection] {
        async let gamesTask = wellFormedGames()
        async let teamsTask = client.fetchTeams()
        let (games, teams) = try await (gamesTask, teamsTask)

        var wins: [String: Int] = [:]
        var losses: [String: Int] = [:]
        var runsScored: [String: Int] = [:]
        var runsAllowed: [String: Int] = [:]

        for game in games where game.state.status.lowercased().hasPrefix("final") {
            let home = game.homeTeamId, away = game.awayTeamId
            let homeScore = game.state.homeScore, awayScore = game.state.awayScore
            runsScored[home, default: 0] += homeScore
            runsAllowed[home, default: 0] += awayScore
            runsScored[away, default: 0] += awayScore
            runsAllowed[away, default: 0] += homeScore
            if homeScore > awayScore {
                wins[home, default: 0] += 1
                losses[away, default: 0] += 1
            } else if awayScore > homeScore {
                wins[away, default: 0] += 1
                losses[home, default: 0] += 1
            }
        }

        let teamRows: [StandingsTeamRow] = teams.map { team in
            let w = wins[team.teamId] ?? 0
            let l = losses[team.teamId] ?? 0
            let rd = (runsScored[team.teamId] ?? 0) - (runsAllowed[team.teamId] ?? 0)
            return StandingsTeamRow(
                id: team.teamId,
                teamID: team.teamId,
                teamName: team.teamName,
                rank: "",
                wins: w,
                losses: l,
                winPercentage: Self.formatPct(wins: w, losses: l),
                gamesBack: nil,
                wildCardGamesBack: nil,
                lastTen: nil,
                streak: nil,
                runDifferential: rd
            )
        }.sorted { $0.wins > $1.wins }

        // A single untitled section — the standings screen renders this headerless/flat,
        // which is how WPBL's 4-team, no-division shape differs from MLB's AL/NL sections.
        return [StandingsSection(id: "WPBL", title: nil, rows: teamRows.map { .team($0) })]
    }

    func fetchWildcardStandings() async throws -> [StandingsSection] { [] }

    func fetchRoster(teamID: String) async throws -> [LeagueRosterPlayer] {
        try await client.fetchRoster(teamID: teamID).map(Self.makeRosterPlayer)
    }

    /// WPBL has no season-stats endpoint (unlike MLB's hydrated /people call) — aggregate by
    /// summing this player's box-score lines across their team's completed games. No caching
    /// yet (each call re-fetches every completed game's boxscore); worth adding if this proves
    /// slow for teams with many games played, but not needed for correctness.
    func fetchPlayerSeasonStats(playerID: String) async throws -> PlayerSeasonStats? {
        let player = try await client.fetchPlayer(playerID: playerID)
        let games = try await client.fetchGames().filter {
            ($0.homeTeamId == player.teamId || $0.awayTeamId == player.teamId) &&
            $0.state.status.lowercased().hasPrefix("final")
        }

        var hittingTotals: [String: Int] = [:]
        var pitchingTotals: [String: Int] = [:]
        var didHit = false
        var didPitch = false

        for game in games {
            guard let boxscore = try? await client.fetchBoxscore(gameID: game.gameId) else { continue }
            for team in boxscore.teams {
                guard let boxPlayer = team.players?.first(where: { $0.id == playerID }) else { continue }
                if let hitting = boxPlayer.hitting {
                    didHit = true
                    for (key, value) in hitting {
                        if let intValue = Int(value) { hittingTotals[key, default: 0] += intValue }
                    }
                }
                if let pitching = boxPlayer.pitching {
                    didPitch = true
                    for (key, value) in pitching {
                        if let intValue = Int(value) { pitchingTotals[key, default: 0] += intValue }
                    }
                }
            }
        }

        guard didHit || didPitch else { return nil }

        var battingLine: [String: String] = [:]
        if didHit {
            for (source, label) in [("ab", "AB"), ("r", "R"), ("h", "H"), ("double", "2B"), ("triple", "3B"), ("hr", "HR"), ("rbi", "RBI"), ("sb", "SB"), ("bb", "BB"), ("so", "SO")] {
                if let v = hittingTotals[source] { battingLine[label] = "\(v)" }
            }
            if let ab = hittingTotals["ab"], ab > 0, let h = hittingTotals["h"] {
                battingLine["AVG"] = Self.formatAvg(Double(h) / Double(ab))
            }
        }

        var pitchingLine: [String: String] = [:]
        if didPitch {
            for (source, label) in [("r", "R"), ("er", "ER"), ("h", "H"), ("bb", "BB"), ("so", "SO")] {
                if let v = pitchingTotals[source] { pitchingLine[label] = "\(v)" }
            }
        }

        return PlayerSeasonStats(
            playerID: playerID,
            league: .wpbl,
            battingLine: battingLine.isEmpty ? nil : battingLine,
            pitchingLine: pitchingLine.isEmpty ? nil : pitchingLine,
            asOf: nil
        )
    }

    func makeGameDetailDataSource(gameID: String) -> GameDetailDataSource {
        WPBLGameDataSource(gameID: gameID)
    }

    // MARK: - Mapping

    private static func makeLeagueGame(_ game: WPBLGame) -> LeagueGame {
        LeagueGame(
            id: game.gameId,
            league: .wpbl,
            homeTeamID: game.homeTeamId,
            awayTeamID: game.awayTeamId,
            homeTeamName: game.homeTeamName,
            awayTeamName: game.awayTeamName,
            startDate: parseISODate(game.scheduledStart) ?? Date(),
            status: mapStatus(game.status),
            homeScore: game.state.homeScore,
            awayScore: game.state.awayScore,
            venue: game.venue.isEmpty ? nil : game.venue,
            currentInning: nil,
            scheduledInnings: nil
        )
    }

    private static func mapStatus(_ status: String) -> LeagueGameStatus {
        let lower = status.lowercased()
        if lower.hasPrefix("final") { return .final }
        if lower == "not started" { return .scheduled }
        if lower.contains("progress") || lower.contains("delay") { return .live }
        return .other(status)
    }

    private static func parseISODate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func formatPct(wins: Int, losses: Int) -> String {
        guard wins + losses > 0 else { return ".000" }
        let pct = Double(wins) / Double(wins + losses)
        var formatted = String(format: "%.3f", pct)
        if formatted.hasPrefix("0.") { formatted.removeFirst() }
        return formatted
    }

    private static func formatAvg(_ value: Double) -> String {
        var formatted = String(format: "%.3f", value)
        if formatted.hasPrefix("0.") { formatted.removeFirst() }
        return formatted
    }

    private static func makeRosterPlayer(_ player: WPBLRosterPlayer) -> LeagueRosterPlayer {
        func nonEmpty(_ value: String?) -> String? {
            guard let value, !value.isEmpty else { return nil }
            return value
        }

        return LeagueRosterPlayer(
            id: player.playerId,
            league: .wpbl,
            teamID: player.teamId,
            fullName: "\(player.firstName) \(player.lastName)",
            position: nonEmpty(player.position),
            uniformNumber: nonEmpty(player.uniform),
            bats: nonEmpty(player.bio?.bats),
            throwsHand: nonEmpty(player.bio?.throwsHand),
            heightDisplay: nonEmpty(player.bio?.height ?? player.height),
            weightDisplay: nonEmpty(player.bio?.weight ?? player.weight),
            hometown: nonEmpty(player.bio?.hometown ?? player.hometown),
            birthDate: nil
        )
    }
}
