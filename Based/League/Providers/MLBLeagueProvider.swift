import Foundation

/// Wraps the existing MLBAPIClient/GameService — behavior-preserving, not a rewrite. This is also
/// where MLB's AL/NL/division-ID mapping now lives, moved out of StandingsViewController/TeamsViewController.
final class MLBLeagueProvider: LeagueProvider {
    let league: League = .mlb

    private let client = MLBAPIClient.shared
    private let currentSeason: Int

    init(currentSeason: Int = Calendar.current.component(.year, from: Date())) {
        self.currentSeason = currentSeason
    }

    func fetchSchedule(date: Date) async throws -> [LeagueGame] {
        try await client.fetchSchedule(date: date).map(Self.makeLeagueGame)
    }

    func fetchTeamSchedule(teamID: String) async throws -> [LeagueGame] {
        guard let teamId = Int(teamID) else { return [] }
        return try await client.fetchTeamSchedule(teamId: teamId, season: currentSeason).map(Self.makeLeagueGame)
    }

    func fetchTeams() async throws -> [LeagueTeam] {
        try await client.fetchTeams().map { team in
            LeagueTeam(id: String(team.id ?? 0), league: .mlb, name: team.name ?? "Unknown", shortName: nil)
        }
    }

    func fetchStandings() async throws -> [StandingsSection] {
        try await Self.buildSections(from: client.fetchStandings(season: currentSeason))
    }

    func fetchRoster(teamID: String) async throws -> [LeagueRosterPlayer] {
        guard let teamId = Int(teamID) else { return [] }
        return try await client.fetchTeamRoster(teamId: teamId).map { entry in
            LeagueRosterPlayer(
                id: String(entry.person?.id ?? 0),
                league: .mlb,
                teamID: teamID,
                fullName: entry.person?.fullName ?? "Unknown",
                position: entry.position?.abbreviation,
                uniformNumber: entry.jerseyNumber,
                bats: nil,
                throwsHand: nil,
                heightDisplay: nil,
                weightDisplay: nil,
                hometown: nil,
                birthDate: nil
            )
        }
    }

    func fetchPlayerSeasonStats(playerID: String) async throws -> PlayerSeasonStats? {
        guard let id = Int(playerID) else { return nil }
        let info = try await client.fetchPlayer(id: id)
        guard let groups = info.stats else { return nil }

        func line(for groupName: String) -> [String: String]? {
            guard let group = groups.first(where: {
                ($0.type?.displayName ?? "").lowercased() == "season" && ($0.group?.displayName ?? "").lowercased() == groupName
            }), let stat = group.splits?.last?.stat else { return nil }

            var values: [String: String] = [:]
            if groupName == "hitting" {
                if let v = stat.atBats { values["AB"] = "\(v)" }
                if let v = stat.runs { values["R"] = "\(v)" }
                if let v = stat.hits { values["H"] = "\(v)" }
                if let v = stat.doubles { values["2B"] = "\(v)" }
                if let v = stat.triples { values["3B"] = "\(v)" }
                if let v = stat.homeRuns { values["HR"] = "\(v)" }
                if let v = stat.rbi { values["RBI"] = "\(v)" }
                if let v = stat.stolenBases { values["SB"] = "\(v)" }
                if let v = stat.baseOnBalls { values["BB"] = "\(v)" }
                if let v = stat.strikeOuts { values["SO"] = "\(v)" }
                if let v = stat.avg { values["AVG"] = v }
                if let v = stat.obp { values["OBP"] = v }
                if let v = stat.slg { values["SLG"] = v }
                if let v = stat.ops { values["OPS"] = v }
            } else {
                if let v = stat.wins { values["W"] = "\(v)" }
                if let v = stat.losses { values["L"] = "\(v)" }
                if let v = stat.era { values["ERA"] = v }
                if let v = stat.inningsPitched { values["IP"] = v }
                if let v = stat.saves { values["SV"] = "\(v)" }
                if let v = stat.strikeOuts { values["SO"] = "\(v)" }
                if let v = stat.baseOnBalls { values["BB"] = "\(v)" }
            }
            return values.isEmpty ? nil : values
        }

        let hitting = line(for: "hitting")
        let pitching = line(for: "pitching")
        guard hitting != nil || pitching != nil else { return nil }
        return PlayerSeasonStats(playerID: playerID, league: .mlb, battingLine: hitting, pitchingLine: pitching, asOf: nil)
    }

    func makeGameDetailDataSource(gameID: String) -> GameDetailDataSource {
        guard let gamePk = Int(gameID) else {
            NSLog("[MLBLeagueProvider] non-numeric game id: %@", gameID)
            return MLBGameDataSource(gamePk: 0)
        }
        return MLBGameDataSource(gamePk: gamePk)
    }

    // MARK: - Mapping

    private static func makeLeagueGame(_ game: ScheduleGame) -> LeagueGame {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        let startDate = isoFormatter.date(from: game.gameDate) ?? fallbackFormatter.date(from: game.gameDate) ?? Date()

        return LeagueGame(
            id: String(game.gamePk),
            league: .mlb,
            homeTeamID: String(game.teams.home.team.id ?? 0),
            awayTeamID: String(game.teams.away.team.id ?? 0),
            homeTeamName: game.teams.home.team.name ?? "Home",
            awayTeamName: game.teams.away.team.name ?? "Away",
            startDate: startDate,
            status: mapStatus(game.status.detailedState),
            homeScore: game.teams.home.score,
            awayScore: game.teams.away.score
        )
    }

    private static func mapStatus(_ detailedState: String) -> LeagueGameStatus {
        let lower = detailedState.lowercased()
        if lower.contains("final") || lower == "game over" || lower == "completed early" { return .final }
        if lower.contains("scheduled") || lower.contains("pre-game") || lower.contains("preview") { return .scheduled }
        if lower.contains("progress") || lower.contains("warmup") || lower.contains("delay") || lower.contains("challenge") { return .live }
        return .other(detailedState)
    }

    // MLB StatsAPI division IDs (public, stable): 200/201/202 = AL West/East/Central, 203/204/205 = NL West/East/Central.
    private static let divisionMeta: [Int: (leagueName: String, leagueID: String, divisionName: String)] = [
        200: ("American League", "AL", "West"),
        201: ("American League", "AL", "East"),
        202: ("American League", "AL", "Central"),
        203: ("National League", "NL", "West"),
        204: ("National League", "NL", "East"),
        205: ("National League", "NL", "Central")
    ]
    private static let divisionOrder = [201, 202, 200, 204, 205, 203]

    private static func buildSections(from records: [StandingsRecord]) -> [StandingsSection] {
        let byDivision = Dictionary(uniqueKeysWithValues: records.map { ($0.division.id, $0) })
        let extraDivisionIDs = byDivision.keys.filter { !divisionOrder.contains($0) }.sorted()

        var alRows: [StandingsRow] = []
        var nlRows: [StandingsRow] = []

        for divisionID in divisionOrder + extraDivisionIDs {
            guard let record = byDivision[divisionID] else { continue }
            let meta = divisionMeta[divisionID]
            let isAL = meta?.leagueID == "AL" || record.league?.id == 103
            let divisionLabel = meta?.divisionName ?? record.division.name ?? "Division"

            let sortedTeams = record.teamRecords.sorted { lhs, rhs in
                if let l = Int(lhs.divisionRank ?? ""), let r = Int(rhs.divisionRank ?? "") { return l < r }
                return lhs.leagueRecord.wins > rhs.leagueRecord.wins
            }
            let teamRows: [StandingsRow] = sortedTeams.map { teamRecord in
                .team(StandingsTeamRow(
                    id: String(teamRecord.team.id ?? 0),
                    teamID: String(teamRecord.team.id ?? 0),
                    teamName: teamRecord.team.name ?? "Unknown",
                    wins: teamRecord.leagueRecord.wins,
                    losses: teamRecord.leagueRecord.losses,
                    winPercentage: teamRecord.leagueRecord.pct ?? "",
                    gamesBack: teamRecord.gamesBack,
                    streak: teamRecord.streak?.streakCode,
                    runDifferential: teamRecord.runDifferential
                ))
            }

            let rows = [StandingsRow.subHeader(divisionLabel)] + teamRows
            if isAL { alRows += rows } else { nlRows += rows }
        }

        var sections: [StandingsSection] = []
        if !alRows.isEmpty { sections.append(StandingsSection(id: "AL", title: "American League", rows: alRows)) }
        if !nlRows.isEmpty { sections.append(StandingsSection(id: "NL", title: "National League", rows: nlRows)) }
        return sections
    }
}
