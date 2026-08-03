import Foundation
import OSLog

protocol GameUpdateDelegate: AnyObject {
    func didUpdateSnapshot(_ snapshot: LiveGameSnapshot)
    func didUpdateGameStatus(_ status: String)
}

enum LiveGamePhase: Equatable {
    case pregame
    case activeAtBat
    case betweenBatters
    case betweenHalfInnings
    case final
}

struct LiveGameSnapshot {
    let linescore: Linescore
    let scorecard: ScorecardData?
    let gameData: GameData?
    let phase: LiveGamePhase
    let currentAtBat: AtBatEvent?

    var isGameLive: Bool {
        switch phase {
        case .activeAtBat, .betweenBatters, .betweenHalfInnings:
            return true
        case .pregame, .final:
            return false
        }
    }
}

class GameService: GamePollingServiceDelegate {
    static let shared = GameService()
    weak var delegate: GameUpdateDelegate?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Based", category: "GameService")
    private let pollingService = GamePollingService()

    var useMockData = false
    var currentGamePk: Int?

    private var lastLinescore: Linescore?
    private var lastScorecard: ScorecardData?
    private var lastGameData: GameData?

    init() {
        pollingService.delegate = self
    }

    func startPolling(gamePk: Int, scheduledStartTime: Date? = nil) {
        currentGamePk = gamePk
        pollingService.start(gamePk: String(gamePk), scheduledStartTime: scheduledStartTime)
    }

    func stopPolling() {
        currentGamePk = nil
        pollingService.stop()
        lastLinescore = nil
        lastScorecard = nil
        lastGameData = nil
    }

    func didEnterBackground() {
        pollingService.didEnterBackground()
    }

    func willEnterForeground() {
        guard let gamePk = currentGamePk else { return }
        pollingService.willEnterForeground(gamePk: String(gamePk))
    }

    // MARK: - GamePollingServiceDelegate

    func pollingService(_ service: GamePollingService, shouldPerformUpdateFor gamePk: String, sessionID: UUID) async throws {
        guard let gamePk = Int(gamePk) else { return }
        try await performSmartUpdate(gamePk: gamePk, sessionID: sessionID)
    }

    func pollingService(_ service: GamePollingService, didUpdateRTT rtt: TimeInterval) {
        // Handle RTT updates if needed
    }

    func pollingService(_ service: GamePollingService, didChangeConnectivity connected: Bool) {
        // Handle connectivity changes
    }

    func fetchCurrentGame() async throws -> Linescore {
        guard let gamePk = currentGamePk else {
            throw NSError(domain: "GameService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No game selected"])
        }
        return try await MLBAPIClient.shared.fetchLinescore(gamePk: gamePk)
    }

    func fetchScorecard(linescore: Linescore? = nil) async throws -> ScorecardData {
        guard let gamePk = currentGamePk else {
            throw NSError(domain: "GameService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No game selected"])
        }
        var pbp: PlayByPlayResponse?
        var box: BoxscoreResponse?

        try await withThrowingTaskGroup(of: Any.self) { group in
            group.addTask { try await MLBAPIClient.shared.fetchPlayByPlay(gamePk: gamePk) as Any }
            group.addTask { try await MLBAPIClient.shared.fetchBoxscore(gamePk: gamePk) as Any }
            for try await result in group {
                if let p = result as? PlayByPlayResponse { pbp = p }
                else if let b = result as? BoxscoreResponse { box = b }
            }
        }

        guard let pbp, let box else {
            throw NSError(domain: "GameService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch game data"])
        }

        return ScorecardDataTransformer.transformToScorecardData(playByPlay: pbp, boxscore: box, linescore: linescore)
    }

    private func performSmartUpdate(gamePk: Int, sessionID: UUID) async throws {
        guard shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }

        let linescore = try await MLBAPIClient.shared.fetchLinescore(gamePk: gamePk)
        guard shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }

        let isFirstLoad = lastScorecard == nil
        if isFirstLoad {
            await MainActor.run {
                guard self.shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }
                self.lastLinescore = linescore
                let earlySnapshot = ScorecardDataTransformer.makeSnapshot(linescore: linescore, scorecard: nil, gameData: nil)
                self.delegate?.didUpdateSnapshot(earlySnapshot)
            }
        }

        var fetchReasons: [String] = []
        let phase = ScorecardDataTransformer.livePhase(for: linescore, gameData: lastGameData)

        if lastScorecard != nil {
            fetchReasons = scorecardFetchReasons(new: linescore, old: lastLinescore)
        } else {
            fetchReasons = ["no cached scorecard"]
        }

        if phase == .pregame && fetchReasons.isEmpty && pollingService.shouldProbePregameLineup() {
            fetchReasons.append("pregame lineup probe")
        }

        if !fetchReasons.isEmpty {
            let scorecard = try await fetchScorecard(gamePk: gamePk, linescore: linescore)
            guard shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }

            if phase == .pregame {
                pollingService.lastPregameLineupProbeAt = Date()
            }

            if !useMockData {
                if let feed = try? await MLBAPIClient.shared.fetchLiveFeed(gamePk: gamePk) {
                    guard shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }
                    lastGameData = feed.gameData
                }
            }

            await MainActor.run {
                guard self.shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }
                self.lastScorecard = scorecard
            }
        }

        if let scorecard = lastScorecard {
            checkInningCleanup(scorecard: scorecard, linescore: linescore)
        }

        await MainActor.run {
            guard self.shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }
            self.lastLinescore = linescore
            let snapshot = ScorecardDataTransformer.makeSnapshot(linescore: linescore, scorecard: self.lastScorecard, gameData: self.lastGameData)
            self.delegate?.didUpdateSnapshot(snapshot)
        }
    }

    private func fetchScorecard(gamePk: Int, linescore: Linescore? = nil) async throws -> ScorecardData {
        var pbp: PlayByPlayResponse?
        var box: BoxscoreResponse?

        try await withThrowingTaskGroup(of: Any.self) { group in
            group.addTask { try await MLBAPIClient.shared.fetchPlayByPlay(gamePk: gamePk) as Any }
            group.addTask { try await MLBAPIClient.shared.fetchBoxscore(gamePk: gamePk) as Any }
            for try await result in group {
                if let p = result as? PlayByPlayResponse { pbp = p }
                else if let b = result as? BoxscoreResponse { box = b }
            }
        }

        guard let pbp, let box else {
            throw NSError(domain: "GameService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch game data"])
        }

        return ScorecardDataTransformer.transformToScorecardData(playByPlay: pbp, boxscore: box, linescore: linescore)
    }

    private func scorecardFetchReasons(new linescore: Linescore, old previous: Linescore?) -> [String] {
        guard let previous else { return ["missing previous linescore"] }
        var reasons: [String] = []

        if linescore.currentPitchCount != previous.currentPitchCount { reasons.append("pitch count changed") }
        if linescore.outs != previous.outs { reasons.append("outs changed") }
        if linescore.balls != previous.balls { reasons.append("balls changed") }
        if linescore.strikes != previous.strikes { reasons.append("strikes changed") }
        if linescore.teams?.home?.runs != previous.teams?.home?.runs { reasons.append("home runs changed") }
        if linescore.teams?.away?.runs != previous.teams?.away?.runs { reasons.append("away runs changed") }
        if linescore.currentInning != previous.currentInning { reasons.append("inning changed") }
        if linescore.inningHalf != previous.inningHalf { reasons.append("inning half changed") }
        if linescore.offense?.batter?.id != previous.offense?.batter?.id { reasons.append("batter changed") }
        if linescore.offense?.first?.id != previous.offense?.first?.id { reasons.append("runner on first changed") }
        if linescore.offense?.second?.id != previous.offense?.second?.id { reasons.append("runner on second changed") }
        if linescore.offense?.third?.id != previous.offense?.third?.id { reasons.append("runner on third changed") }
        if linescore.defense?.pitcher?.id != previous.defense?.pitcher?.id { reasons.append("pitcher changed") }
        if pollingService.needsInningCleanup { reasons.append("inning cleanup requested") }

        return reasons
    }

    private func checkInningCleanup(scorecard: ScorecardData, linescore: Linescore) {
        let state = linescore.inningState?.lowercased() ?? ""
        guard state == "mid" || state == "end" else {
            pollingService.needsInningCleanup = false
            pollingService.inningCleanupAttempts = 0
            return
        }

        let currentInning = linescore.currentInning ?? 1
        guard let inningData = scorecard.innings.first(where: { $0.num == currentInning }) else {
            pollingService.needsInningCleanup = true
            pollingService.inningCleanupAttempts += 1
            return
        }

        let events = (state == "mid") ? inningData.away : inningData.home
        let maxOuts = events.map { $0.outs }.max() ?? 0

        if maxOuts < 3 && pollingService.inningCleanupAttempts < pollingService.maxCleanupAttempts {
            pollingService.needsInningCleanup = true
            pollingService.inningCleanupAttempts += 1
        } else {
            pollingService.needsInningCleanup = false
            if maxOuts >= 3 { pollingService.inningCleanupAttempts = 0 }
        }
    }

    private func shouldApplyUpdate(for gamePk: Int, sessionID: UUID) -> Bool {
        return currentGamePk == gamePk && pollingService.pollingSessionID == sessionID
    }

    func selectGame(gamePk: Int) { currentGamePk = gamePk }

    func fetchSchedule(for date: Date) async throws -> [ScheduleGame] {
        return try await MLBAPIClient.shared.fetchSchedule(date: date)
    }

    func fetchPlayerInfo(playerId: Int) async throws -> PlayerInfo {
        return try await MLBAPIClient.shared.fetchPlayer(id: playerId)
    }
}
