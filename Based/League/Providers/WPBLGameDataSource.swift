import Foundation

/// Polls WPBL's single boxscore endpoint (unlike MLB's 4-endpoint dance, everything — status,
/// box totals, plays — comes back in one GET) and runs each response through
/// WPBLBoxscoreTransformer. Owns its own GamePollingService instance since GameService.shared's
/// is private to the MLB path.
final class WPBLGameDataSource: GameDetailDataSource, GamePollingServiceDelegate {
    private let gameID: String
    private let client = WPBLAPIClient.shared
    private let pollingService = GamePollingService()
    private var onSnapshot: ((LiveGameSnapshot) -> Void)?
    private var onStatus: ((String) -> Void)?
    private var lastGameStatus: String?

    init(gameID: String) {
        self.gameID = gameID
        pollingService.delegate = self
    }

    func start(onSnapshot: @escaping (LiveGameSnapshot) -> Void, onStatus: @escaping (String) -> Void) {
        self.onSnapshot = onSnapshot
        self.onStatus = onStatus
        pollingService.start(gamePk: gameID, scheduledStartTime: nil)
    }

    func stop() {
        pollingService.stop()
        onSnapshot = nil
        onStatus = nil
    }

    func fetchPlayerInfo(playerID: String) async throws -> PlayerInfo {
        let player = try await client.fetchPlayer(playerID: playerID)

        // WPBL's API reports unpopulated bio fields as "" rather than omitting them (see
        // WPBL.md) — PlayerInfo's consumers (PlayerDetailViewController.updateBioInfo) use
        // `if let` to decide what to render, which only hides a field if it's actually nil, not
        // just empty. Normalize here so blank fields disappear now and any that do get
        // populated later show up automatically with no further changes.
        func nonEmpty(_ value: String?) -> String? {
            guard let value, !value.isEmpty else { return nil }
            return value
        }

        let position = nonEmpty(player.position)
        return PlayerInfo(
            id: nil,
            fullName: "\(player.firstName) \(player.lastName)",
            firstName: player.firstName,
            lastName: player.lastName,
            primaryNumber: nonEmpty(player.uniform),
            birthDate: nil,
            currentAge: nil,
            birthCity: nil,
            birthCountry: nil,
            height: nonEmpty(player.bio?.height) ?? nonEmpty(player.height),
            weight: nil,
            primaryPosition: position.map { Position(code: nil, name: $0, type: nil, abbreviation: $0) },
            batSide: nonEmpty(player.bio?.bats).map { HandSide(code: $0, description: nil) },
            pitchHand: nonEmpty(player.bio?.throwsHand).map { HandSide(code: $0, description: nil) },
            currentTeam: nil,
            stats: nil
        )
    }

    // MARK: - GamePollingServiceDelegate

    func pollingService(_ service: GamePollingService, shouldPerformUpdateFor gamePk: String, sessionID: UUID) async throws {
        let boxscore = try await client.fetchBoxscore(gameID: gamePk)
        let scorecard = WPBLBoxscoreTransformer.transformToScorecardData(boxscore)
        let linescore = Self.makeLinescore(from: boxscore)
        let phase = Self.livePhase(for: boxscore)
        let snapshot = LiveGameSnapshot(linescore: linescore, scorecard: scorecard, gameData: nil, phase: phase, currentAtBat: scorecard.liveCurrentAtBat)
        onSnapshot?(snapshot)

        if lastGameStatus != boxscore.gameStatus {
            lastGameStatus = boxscore.gameStatus
            onStatus?(boxscore.gameStatus)
        }
    }

    func pollingService(_ service: GamePollingService, didUpdateRTT rtt: TimeInterval) {}
    func pollingService(_ service: GamePollingService, didChangeConnectivity connected: Bool) {}

    // MARK: - Mapping

    /// Best-effort Linescore built from WPBL's boxscore — reuses the existing (mostly-optional)
    /// MLB-shaped header/live-state UI as-is rather than introducing a parallel generic type.
    /// Fields with no WPBL equivalent (weather, mound visits, challenges, defense) stay nil.
    private static func makeLinescore(from boxscore: WPBLBoxscore) -> Linescore {
        let awayTeam = boxscore.teams.first { $0.side == "away" }
        let homeTeam = boxscore.teams.first { $0.side == "home" }
        let status = boxscore.status

        let awayRunsByInning = Dictionary(uniqueKeysWithValues: (awayTeam?.line ?? []).map { ($0.inning, $0.runs) })
        let homeRunsByInning = Dictionary(uniqueKeysWithValues: (homeTeam?.line ?? []).map { ($0.inning, $0.runs) })
        let maxInning = max(awayRunsByInning.keys.max() ?? 0, homeRunsByInning.keys.max() ?? 0, 7)
        let innings: [Inning] = (1...maxInning).map { num in
            Inning(
                num: num,
                ordinalNum: "\(num)",
                home: InningStats(runs: homeRunsByInning[num], hits: nil, errors: nil, leftOnBase: nil),
                away: InningStats(runs: awayRunsByInning[num], hits: nil, errors: nil, leftOnBase: nil)
            )
        }

        func teamGameStats(_ team: WPBLBoxscoreTeam?) -> TeamGameStats {
            TeamGameStats(
                team: Team(id: nil, name: team?.name, link: nil),
                runs: team?.totals?.runs,
                hits: team?.totals?.hits,
                errors: team?.totals?.errors,
                leftOnBase: team?.totals?.leftOnBase,
                moundVisitsRemaining: nil,
                challenges: nil
            )
        }

        func runnerPlayer(_ name: String) -> Player? {
            name.isEmpty ? nil : Player(id: nil, fullName: name, link: nil)
        }

        let battingTeam = [awayTeam, homeTeam].first { $0?.id == status.battingTeamId } ?? nil
        let offense = Offense(
            batter: runnerPlayer(status.batterName),
            onDeck: nil,
            inHole: nil,
            pitcher: runnerPlayer(status.pitcherName),
            first: runnerPlayer(status.firstBase),
            second: runnerPlayer(status.secondBase),
            third: runnerPlayer(status.thirdBase),
            team: battingTeam.map { Team(id: nil, name: $0.name, link: nil) }
        )

        return Linescore(
            currentInning: status.inning > 0 ? status.inning : nil,
            currentInningOrdinal: status.inning > 0 ? "\(status.inning)" : nil,
            inningState: nil,
            inningHalf: status.half.isEmpty ? nil : status.half,
            isTopInning: status.half.isEmpty ? nil : (status.half == "top"),
            scheduledInnings: 7,
            innings: innings,
            teams: LinescoreTeams(home: teamGameStats(homeTeam), away: teamGameStats(awayTeam)),
            offense: offense,
            defense: nil,
            balls: status.balls,
            strikes: status.strikes,
            outs: status.outs,
            currentPitchCount: nil,
            currentPitches: nil,
            venue: nil,
            weather: nil
        )
    }

    /// WPBL's polling snapshot has no equivalent of MLB's "current incomplete play" object, so
    /// there's no reliable signal to distinguish activeAtBat from betweenBatters — this settles
    /// on betweenBatters as a stable "live" phase (LiveGameSnapshot.isGameLive is true for it).
    private static func livePhase(for boxscore: WPBLBoxscore) -> LiveGamePhase {
        if boxscore.status.complete { return .final }
        let lower = boxscore.gameStatus.lowercased()
        if lower.hasPrefix("final") { return .final }
        if lower == "not started" { return .pregame }
        return .betweenBatters
    }
}
