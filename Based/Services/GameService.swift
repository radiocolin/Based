import Foundation
import Network
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

class GameService {
    static let shared = GameService()
    weak var delegate: GameUpdateDelegate?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Based",
        category: "GameService"
    )
    
    var useMockData = false
    var currentGamePk: Int?
    
    // Polling state
    private var pollingTask: Task<Void, Never>?
    private var lastLinescore: Linescore?
    private var lastScorecard: ScorecardData?
    private var lastGameData: GameData?
    private var isBackgrounded = false
    
    // Network monitoring: skip polls when there's no connectivity
    // NWPathMonitor cannot be restarted after cancel(), so recreate each time.
    private var networkMonitor: NWPathMonitor?
    private var hasConnectivity = true
    private var isConstrainedNetwork = false  // Low Data Mode
    private var linkQuality: NWPath.LinkQuality = .unknown  // iOS 26+

    // Round-trip time tracking: smoothed average of recent request durations
    private var recentRTT: TimeInterval = 0  // seconds, 0 = no data yet
    
    // Error backoff: doubles on each consecutive failure, resets on success
    private var consecutiveErrors = 0
    private let maxBackoffInterval: TimeInterval = 60.0
    
    // Post-inning cleanup: re-poll when a half-inning transition is missing its 3rd out
    private var needsInningCleanup = false
    private var inningCleanupAttempts = 0
    private let maxCleanupAttempts = 5
    private var lastLoggedPollingInterval: Int?
    private var pollingSessionID = UUID()
    private var scheduledStartTime: Date?
    private var lastPregameLineupProbeAt: Date?

    private let farPregameThreshold: TimeInterval = 3 * 60 * 60
    private let mediumPregameThreshold: TimeInterval = 90 * 60
    private let nearPregameThreshold: TimeInterval = 30 * 60

    private func isStatusOnlyPlay(_ play: Play) -> Bool {
        let type = play.result?.type ?? ""
        let event = play.result?.event?.lowercased() ?? ""

        return type == "action" ||
            event.contains("advisory") ||
            event.contains("status change") ||
            event.contains("pitching change") ||
            event.contains("substitution") ||
            event.contains("defensive sub") ||
            event.contains("coaching change") ||
            event.contains("injury") ||
            event.contains("mound visit") ||
            event.contains("ballpark visit") ||
            event.contains("replay") ||
            event.contains("challenge") ||
            event.contains("delay") ||
            event.contains("timeout") ||
            event.contains("turn")
    }

    private func shouldIncludePlayInScorecard(_ play: Play, includeLive: Bool) -> Bool {
        let type = play.result?.type ?? ""
        let hasEvent = play.result?.event != nil
        let isComplete = play.about?.isComplete == true
        let isLive = play.about?.isComplete == false
        let hasLivePitches = play.playEvents?.contains(where: { $0.isPitch == true }) == true

        guard type == "atBat", !isStatusOnlyPlay(play) else { return false }
        
        if isComplete {
            // Filter out at-bats that ended due to a runner being out (CS, pickoff) 
            // where the batter wasn't the one who was out. These are NOT completed at-bats
            // for the current batter — they will lead off the next inning.
            let eventType = play.result?.eventType ?? ""
            if eventType.contains("caught_stealing") || eventType.contains("pickoff") {
                let batterId = play.matchup?.batter?.id
                let batterWasOut = play.runners?.contains(where: { 
                    $0.details?.runner?.id == batterId && $0.movement?.isOut == true 
                }) ?? false
                if !batterWasOut {
                    return false
                }
            }
            return hasEvent
        }
        
        if includeLive && isLive { return hasEvent || hasLivePitches }
        return false
    }

    private func livePhase(for linescore: Linescore, gameData: GameData?) -> LiveGamePhase {
        let state = linescore.inningState?.lowercased() ?? ""

        if state.contains("final") {
            return .final
        }

        if state.contains("scheduled") || state.contains("pre-game") || state.contains("warmup") {
            return .pregame
        }

        if let status = gameData?.status {
            let detailedState = status.detailedState.lowercased()
            let statusCode = status.statusCode?.lowercased() ?? ""
            if detailedState == "final" || detailedState == "game over" || detailedState == "completed early" || statusCode == "f" || statusCode == "o" {
                return .final
            }
            if detailedState == "scheduled" || detailedState == "pre-game" {
                return .pregame
            }
        }

        if state == "mid" || state == "end" {
            return .betweenHalfInnings
        }

        return .betweenBatters
    }

    private func makeSnapshot(linescore: Linescore, scorecard: ScorecardData?, gameData: GameData?) -> LiveGameSnapshot {
        let basePhase = livePhase(for: linescore, gameData: gameData)
        let currentAtBat = scorecard?.liveCurrentAtBat
        let phase: LiveGamePhase

        switch basePhase {
        case .pregame, .final, .betweenHalfInnings:
            phase = basePhase
        case .betweenBatters, .activeAtBat:
            phase = currentAtBat == nil ? .betweenBatters : .activeAtBat
        }

        return LiveGameSnapshot(
            linescore: linescore,
            scorecard: scorecard,
            gameData: gameData,
            phase: phase,
            currentAtBat: currentAtBat
        )
    }

    private func isGameFinal(linescore: Linescore, gameData: GameData?) -> Bool {
        livePhase(for: linescore, gameData: gameData) == .final
    }

    private func pregamePollingInterval(state: String, now: Date = Date()) -> TimeInterval {
        if state.contains("warmup") || state.contains("starting soon") {
            return 20.0
        }

        guard let scheduledStartTime else {
            return 120.0
        }

        let secondsUntilFirstPitch = scheduledStartTime.timeIntervalSince(now)
        if secondsUntilFirstPitch > farPregameThreshold {
            return 20 * 60
        }
        if secondsUntilFirstPitch > mediumPregameThreshold {
            return 10 * 60
        }
        if secondsUntilFirstPitch > nearPregameThreshold {
            return 3 * 60
        }
        if secondsUntilFirstPitch > 0 {
            return 60
        }
        return 20.0
    }

    private func pregameLineupProbeInterval(now: Date = Date()) -> TimeInterval {
        guard let scheduledStartTime else {
            return 10 * 60
        }

        let secondsUntilFirstPitch = scheduledStartTime.timeIntervalSince(now)
        if secondsUntilFirstPitch > farPregameThreshold {
            return 20 * 60
        }
        if secondsUntilFirstPitch > mediumPregameThreshold {
            return 10 * 60
        }
        if secondsUntilFirstPitch > nearPregameThreshold {
            return 5 * 60
        }
        if secondsUntilFirstPitch > 0 {
            return 2 * 60
        }
        return 60
    }

    private func shouldProbePregameLineup(now: Date = Date()) -> Bool {
        guard let lastProbe = lastPregameLineupProbeAt else { return true }
        let elapsed = now.timeIntervalSince(lastProbe)
        return elapsed >= pregameLineupProbeInterval(now: now)
    }
    
    /// Check if the just-completed half-inning has all 3 outs recorded in PBP data.
    /// If not, flag for re-fetch so we eventually capture the missing final at-bat.
    private func checkInningCleanup(scorecard: ScorecardData, linescore: Linescore) {
        let state = linescore.inningState?.lowercased() ?? ""
        guard state == "mid" || state == "end" else {
            // Not in a transition — clear cleanup state
            needsInningCleanup = false
            inningCleanupAttempts = 0
            return
        }
        
        let currentInning = linescore.currentInning ?? 1
        guard let inningData = scorecard.innings.first(where: { $0.num == currentInning }) else {
            needsInningCleanup = true
            inningCleanupAttempts += 1
            logger.warning("Inning cleanup scheduled: missing inning data for inning \(currentInning, privacy: .public) (\(state, privacy: .public)); attempt \(self.inningCleanupAttempts, privacy: .public)/\(self.maxCleanupAttempts, privacy: .public)")
            return
        }
        
        // "Mid" = top of currentInning just ended (away batting → check away events)
        // "End" = bottom of currentInning just ended (home batting → check home events)
        let events = (state == "mid") ? inningData.away : inningData.home
        let maxOuts = events.map { $0.outs }.max() ?? 0
        
        if maxOuts < 3 && inningCleanupAttempts < maxCleanupAttempts {
            needsInningCleanup = true
            inningCleanupAttempts += 1
            logger.warning("Inning cleanup needed: \(state.uppercased(), privacy: .public) \(currentInning, privacy: .public) has \(maxOuts, privacy: .public) outs, attempt \(self.inningCleanupAttempts, privacy: .public)/\(self.maxCleanupAttempts, privacy: .public)")
        } else {
            if maxOuts >= 3 && needsInningCleanup {
                logger.info("Inning cleanup complete: \(state.uppercased(), privacy: .public) \(currentInning, privacy: .public) now has 3 outs")
            }
            needsInningCleanup = false
            if maxOuts >= 3 { inningCleanupAttempts = 0 }
        }
    }
    
    func startPolling(gamePk: Int, scheduledStartTime: Date? = nil) {
        logger.info("Starting polling for gamePk \(gamePk, privacy: .public)")
        stopPolling()
        currentGamePk = gamePk
        let sessionID = UUID()
        pollingSessionID = sessionID
        self.scheduledStartTime = scheduledStartTime
        if let scheduledStartTime {
            logger.debug("Scheduled start time for gamePk \(gamePk, privacy: .public): \(scheduledStartTime.formatted(date: .abbreviated, time: .shortened), privacy: .public)")
        }
        
        // Create a fresh monitor (NWPathMonitor can't be restarted after cancel)
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let hasConnectivity = (path.status == .satisfied)
            let isConstrained = path.isConstrained
            let linkQuality = path.linkQuality

            if self.hasConnectivity != hasConnectivity ||
                self.isConstrainedNetwork != isConstrained ||
                self.linkQuality != linkQuality {
                self.logger.info(
                    "Network path changed: connected=\(hasConnectivity, privacy: .public), constrained=\(isConstrained, privacy: .public), linkQuality=\(String(describing: linkQuality), privacy: .public)"
                )
            }

            self.hasConnectivity = hasConnectivity
            self.isConstrainedNetwork = isConstrained  // Low Data Mode
            self.linkQuality = linkQuality
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
        
        pollingTask = Task {
            do {
                let start = CFAbsoluteTimeGetCurrent()
                try await performSmartUpdate(gamePk: gamePk, sessionID: sessionID)
                updateRTT(CFAbsoluteTimeGetCurrent() - start)
                consecutiveErrors = 0
                logger.debug("Initial smart update succeeded for gamePk \(gamePk, privacy: .public)")

                // If game is already final, don't start polling
                if let linescore = lastLinescore {
                    if isGameFinal(linescore: linescore, gameData: lastGameData) {
                        logger.info("Skipping polling loop because game is already final for gamePk \(gamePk, privacy: .public)")
                        return
                    }
                }
            } catch {
                if error is CancellationError { return }
                consecutiveErrors += 1
                logger.error("Initial update failed for gamePk \(gamePk, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            
            while !Task.isCancelled {
                // Skip network calls when there's no point — backgrounded or no connectivity.
                // This prevents wasted radio cycles on doomed requests.
                if isBackgrounded || !hasConnectivity {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s check interval
                    continue
                }

                // Long-polling: delay is measured AFTER the previous request completes,
                // so slow responses naturally space themselves out.
                let interval = calculatePollingInterval()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                if Task.isCancelled { break }
                if isBackgrounded || !hasConnectivity { continue }

                do {
                    let start = CFAbsoluteTimeGetCurrent()
                    try await performSmartUpdate(gamePk: gamePk, sessionID: sessionID)
                    let elapsed = CFAbsoluteTimeGetCurrent() - start
                    updateRTT(elapsed)
                    consecutiveErrors = 0

                    // Check if game just finished
                    if let linescore = lastLinescore {
                        if isGameFinal(linescore: linescore, gameData: lastGameData) {
                            logger.info("Game reached final; stopping polling loop for gamePk \(gamePk, privacy: .public)")
                            break
                        }
                    }
                } catch {
                    if error is CancellationError { break }
                    consecutiveErrors += 1
                    let backoff = min(basePollingInterval() * pow(2.0, Double(consecutiveErrors - 1)), maxBackoffInterval)
                    logger.error("Update failed for gamePk \(gamePk, privacy: .public), attempt \(self.consecutiveErrors, privacy: .public), next in \(Int(backoff), privacy: .public)s: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    /// Called by SceneDelegate when app enters background
    func didEnterBackground() {
        isBackgrounded = true
        logger.info("App entered background; polling will pause network calls")
    }
    
    /// Called by SceneDelegate when app returns to foreground — triggers an immediate refresh
    func willEnterForeground() {
        isBackgrounded = false
        logger.info("App entering foreground; attempting immediate refresh if polling is active")
        guard let gamePk = currentGamePk, pollingTask != nil else { return }
        let sessionID = pollingSessionID
        Task {
            do {
                let start = CFAbsoluteTimeGetCurrent()
                try await performSmartUpdate(gamePk: gamePk, sessionID: sessionID)
                updateRTT(CFAbsoluteTimeGetCurrent() - start)
                consecutiveErrors = 0
                logger.debug("Foreground refresh succeeded for gamePk \(gamePk, privacy: .public)")
            } catch {
                if error is CancellationError { return }
                consecutiveErrors += 1
                logger.error("Foreground refresh failed for gamePk \(gamePk, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    func stopPolling() {
        if pollingTask != nil || currentGamePk != nil {
            logger.info("Stopping polling and clearing cached game state")
        }
        pollingSessionID = UUID()
        pollingTask?.cancel()
        pollingTask = nil
        networkMonitor?.cancel()
        networkMonitor = nil
        lastLinescore = nil
        lastScorecard = nil
        lastGameData = nil
        needsInningCleanup = false
        inningCleanupAttempts = 0
        consecutiveErrors = 0
        recentRTT = 0
        linkQuality = .unknown
        lastLoggedPollingInterval = nil
        scheduledStartTime = nil
        lastPregameLineupProbeAt = nil
    }
    
    /// Exponential moving average of request round-trip time
    private func updateRTT(_ sample: TimeInterval) {
        if recentRTT == 0 {
            recentRTT = sample
        } else {
            // Smooth with α=0.3 so recent samples dominate without jitter
            recentRTT = 0.3 * sample + 0.7 * recentRTT
        }
    }

    /// Base interval before error backoff is applied
    private func basePollingInterval() -> TimeInterval {
        // 1. Phase-based base interval
        var interval: TimeInterval
        if needsInningCleanup {
            interval = 5.0   // Fast-poll to capture missing 3rd-out play
        } else if let linescore = lastLinescore {
            // MLB API inningState values: "Top", "Bottom", "Mid", "End"
            let state = linescore.inningState?.lowercased() ?? ""
            if state == "top" || state == "bottom" {
                interval = 8.0   // Active play
            } else if state == "mid" || state == "end" {
                interval = 15.0  // Between half-innings
            } else if state.contains("final") {
                interval = 300.0
            } else if state.contains("scheduled") || state.contains("pre-game") || state.contains("warmup") || state.contains("starting soon") {
                interval = pregamePollingInterval(state: state)
            } else {
                interval = 30.0  // Unknown/non-standard state
            }
        } else {
            interval = 10.0
        }

        // 2. Network quality multiplier (capped so adjustments don't compound wildly)
        var qualityMultiplier = 1.0

        // Low Data Mode: halve bandwidth usage
        if isConstrainedNetwork { qualityMultiplier *= 2 }

        // Link quality adjustment: stretch intervals on poor links
        switch linkQuality {
        case .minimal:
            qualityMultiplier *= 2.0
        case .moderate:
            qualityMultiplier *= 1.5
        case .good, .unknown:
            break
        @unknown default:
            break
        }

        // Cap the combined quality multiplier at 4× to stay responsive
        interval *= min(qualityMultiplier, 4.0)

        // 3. RTT-based floor: don't poll faster than 1.5× the recent response time.
        // Since we use long-polling (delay starts after response), the actual
        // gap between request starts is already ~RTT + interval.
        if recentRTT > 0 {
            interval = max(interval, recentRTT * 1.5)
        }

        return interval
    }
    
    private func calculatePollingInterval() -> TimeInterval {
        let base = basePollingInterval()
        guard consecutiveErrors > 0 else {
            logPollingIntervalIfNeeded(base, base: base)
            return base
        }
        // Exponential backoff: base * 2^(errors-1), capped at 60s
        let backoff = min(base * pow(2.0, Double(consecutiveErrors - 1)), maxBackoffInterval)
        logPollingIntervalIfNeeded(backoff, base: base)
        return backoff
    }
    
    private func performSmartUpdate(gamePk: Int, sessionID: UUID) async throws {
        guard shouldApplyUpdate(for: gamePk, sessionID: sessionID) else {
            logger.debug("Skipping smart update for stale session on gamePk \(gamePk, privacy: .public)")
            return
        }
        logger.debug("Starting smart update for gamePk \(gamePk, privacy: .public)")
        // 1. Fetch linescore first (smallest payload, needed for early snapshot)
        let linescore = try await MLBAPIClient.shared.fetchLinescore(gamePk: gamePk)
        guard shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }
        
        // 2. Send an early snapshot so the header populates immediately on first load
        let isFirstLoad = lastScorecard == nil
        if isFirstLoad {
            await MainActor.run {
                guard self.shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }
                self.lastLinescore = linescore
                let earlySnapshot = self.makeSnapshot(linescore: linescore, scorecard: nil, gameData: nil)
                self.delegate?.didUpdateSnapshot(earlySnapshot)
            }
            logger.debug("Published early snapshot for initial load (linescore only)")
        }
        
        // 3. Decide if we need to fetch PBP/Boxscore (ScorecardData)
        var fetchReasons: [String] = []
        let phase = livePhase(for: linescore, gameData: lastGameData)
        
        if lastScorecard != nil {
            fetchReasons = scorecardFetchReasons(new: linescore, old: lastLinescore)
        } else {
            fetchReasons = ["no cached scorecard"]
        }

        if phase == .pregame && fetchReasons.isEmpty && shouldProbePregameLineup() {
            fetchReasons.append("pregame lineup probe")
        }

        let shouldFetchScorecard = !fetchReasons.isEmpty
        let reasonsText = fetchReasons.isEmpty ? "none" : fetchReasons.joined(separator: ", ")
        logger.debug("Smart update scorecard decision for gamePk \(gamePk, privacy: .public): shouldFetch=\(shouldFetchScorecard, privacy: .public), reasons=\(reasonsText, privacy: .public)")
        
        // 4. Fetch PBP/Boxscore + LiveFeed together when state changed.
        //    LiveFeed (MVR, challenges, weather) only updates after plays, so piggyback
        //    on scorecard fetches instead of hitting it every cycle.
        if shouldFetchScorecard {
            let scorecard = try await fetchScorecard(linescore: linescore)
            guard shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }
            if phase == .pregame {
                lastPregameLineupProbeAt = Date()
            }
            
            // Fetch live feed alongside scorecard (fail-safe, non-blocking)
            if !useMockData {
                if let feed = try? await MLBAPIClient.shared.fetchLiveFeed(gamePk: gamePk) {
                    guard shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }
                    lastGameData = feed.gameData
                    logger.debug("Updated live feed gameData for gamePk \(gamePk, privacy: .public)")
                } else {
                    logger.warning("Live feed fetch failed for gamePk \(gamePk, privacy: .public); continuing with scorecard update")
                }
            }
            
            await MainActor.run {
                guard self.shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }
                self.lastScorecard = scorecard
            }
        } else {
            logger.debug("Smart update reused cached scorecard for gamePk \(gamePk, privacy: .public)")
        }
        
        // Post-inning cleanup: check if a just-completed half-inning is missing its 3rd out
        if let scorecard = lastScorecard {
            checkInningCleanup(scorecard: scorecard, linescore: linescore)
        }
        
        await MainActor.run {
            guard self.shouldApplyUpdate(for: gamePk, sessionID: sessionID) else { return }
            self.lastLinescore = linescore
            let snapshot = self.makeSnapshot(linescore: linescore, scorecard: self.lastScorecard, gameData: self.lastGameData)
            self.delegate?.didUpdateSnapshot(snapshot)
        }
        logger.debug("Smart update completed for gamePk \(gamePk, privacy: .public)")
    }

    func fetchCurrentGame() async throws -> Linescore {
        guard let gamePk = currentGamePk else {
            logger.error("fetchCurrentGame called without a selected game")
            throw NSError(domain: "GameService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No game selected"])
        }
        logger.debug("Fetching current linescore for gamePk \(gamePk, privacy: .public)")
        return try await MLBAPIClient.shared.fetchLinescore(gamePk: gamePk)
    }

    func fetchScorecard(linescore: Linescore? = nil) async throws -> ScorecardData {
        guard let gamePk = currentGamePk else {
            logger.error("fetchScorecard called without a selected game")
            throw NSError(domain: "GameService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No game selected"])
        }
        logger.debug("Fetching scorecard inputs (playByPlay + boxscore) for gamePk \(gamePk, privacy: .public)")
        
        // Fetch PBP and boxscore in parallel using TaskGroup (avoids async let runtime issues)
        var pbp: PlayByPlayResponse?
        var box: BoxscoreResponse?
        
        try await withThrowingTaskGroup(of: Any.self) { group in
            group.addTask {
                try await MLBAPIClient.shared.fetchPlayByPlay(gamePk: gamePk) as Any
            }
            group.addTask {
                try await MLBAPIClient.shared.fetchBoxscore(gamePk: gamePk) as Any
            }
            for try await result in group {
                if let p = result as? PlayByPlayResponse { pbp = p }
                else if let b = result as? BoxscoreResponse { box = b }
            }
        }
        
        guard let pbp, let box else {
            logger.error("Scorecard input fetch incomplete for gamePk \(gamePk, privacy: .public): pbp=\(pbp != nil, privacy: .public), box=\(box != nil, privacy: .public)")
            throw NSError(domain: "GameService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch game data"])
        }
        logger.debug("Fetched scorecard inputs successfully for gamePk \(gamePk, privacy: .public)")
        
        return transformToScorecardData(playByPlay: pbp, boxscore: box, linescore: linescore)
    }

    private func logPollingIntervalIfNeeded(_ interval: TimeInterval, base: TimeInterval) {
        let rounded = Int(interval.rounded())
        guard lastLoggedPollingInterval != rounded else { return }
        lastLoggedPollingInterval = rounded
        logger.debug(
            "Polling interval updated to \(rounded, privacy: .public)s (base=\(Int(base.rounded()), privacy: .public)s, consecutiveErrors=\(self.consecutiveErrors, privacy: .public), constrained=\(self.isConstrainedNetwork, privacy: .public), linkQuality=\(String(describing: self.linkQuality), privacy: .public), needsCleanup=\(self.needsInningCleanup, privacy: .public))"
        )
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
        if needsInningCleanup { reasons.append("inning cleanup requested") }

        return reasons
    }

    private func shouldApplyUpdate(for gamePk: Int, sessionID: UUID) -> Bool {
        guard !Task.isCancelled else { return false }
        return currentGamePk == gamePk && pollingSessionID == sessionID
    }

    private func transformToScorecardData(playByPlay: PlayByPlayResponse, boxscore: BoxscoreResponse, linescore: Linescore? = nil) -> ScorecardData {
        let allPlays = playByPlay.allPlays ?? []
        let maxInning = max(allPlays.compactMap { $0.about?.inning }.max() ?? 9, 9)

        let (playerNameMap, playerNumberMap) = buildPlayerMaps(boxscore: boxscore)
        let lineups = buildLineups(boxscore: boxscore, allPlays: allPlays)
        let pitchers = buildPitchers(boxscore: boxscore)
        let umpires = buildUmpires(boxscore: boxscore)
        let scorecardInnings = buildInnings(
            allPlays: allPlays,
            linescore: linescore,
            playerNameMap: playerNameMap,
            playerNumberMap: playerNumberMap,
            maxInning: maxInning
        )
        let timeline = buildTimeline(
            allPlays: allPlays,
            playerNameMap: playerNameMap,
            playerNumberMap: playerNumberMap
        )
        let liveCurrentAtBat = buildLiveAtBat(
            playByPlay: playByPlay,
            allPlays: allPlays,
            linescore: linescore,
            playerNameMap: playerNameMap,
            playerNumberMap: playerNumberMap
        )

        // Find game advisories or status changes to show in a banner
        let advisories = allPlays.compactMap { play -> String? in
            if play.result?.type == "action" { return play.result?.description }
            return nil
        }.reversed() // Most recent first

        // Extract game info from boxscore info array
        let gameInfo: [GameInfoItem] = (boxscore.info ?? []).compactMap { note in
            guard let label = note.label else { return nil }
            return GameInfoItem(label: label, value: note.value)
        }

        let activePlay = playByPlay.currentPlay?.about?.isComplete == false ? playByPlay.currentPlay : nil

        return ScorecardData(
            teams: ScorecardTeams(home: boxscore.teams?.home?.team ?? Team(id: 0, name: "Home", link: ""), away: boxscore.teams?.away?.team ?? Team(id: 0, name: "Away", link: "")),
            lineups: lineups,
            pitchers: pitchers,
            innings: scorecardInnings,
            timeline: timeline,
            liveCurrentAtBat: liveCurrentAtBat,
            advisories: Array(advisories.prefix(3)),
            umpires: umpires,
            gameInfo: gameInfo,
            currentInning: linescore?.currentInning ?? activePlay?.about?.inning,
            isTopInning: linescore?.isTopInning ?? activePlay?.about?.isTopInning,
            currentBatterId: linescore?.offense?.batter?.id ?? activePlay?.matchup?.batter?.id
        )
    }

    // MARK: - Scorecard Build Helpers

    private func findPlayer(in team: BoxscoreTeam?, id: Int) -> BoxscorePlayer? {
        guard let team = team, let players = team.players else { return nil }
        return players["ID\(id)"] ?? players["\(id)"]
    }

    /// Tracks the first substitution event AND the first at-bat appearance.
    /// If the player batted before their first substitution, the sub is
    /// just a position change — they are a starter.
    private func getParticipation(for playerId: Int, allPlays: [Play]) -> (entered: Int?, exited: Int?) {
        var firstSubInning: Int?
        var firstBattingInning: Int?
        var exitInning: Int?

        for play in allPlays {
            let inning = play.about?.inning ?? 1

            // Track first at-bat appearance
            if play.matchup?.batter?.id == playerId && firstBattingInning == nil {
                firstBattingInning = inning
            }

            // Also check runners (e.g., pinch runner who hasn't batted yet)
            if firstBattingInning == nil {
                for runner in play.runners ?? [] {
                    if runner.details?.runner?.id == playerId {
                        firstBattingInning = inning
                        break
                    }
                }
            }

            for event in play.playEvents ?? [] {
                // Track first substitution event only
                if event.isSubstitution == true && event.player?.id == playerId && firstSubInning == nil {
                    firstSubInning = inning
                }
                // Track exit (last replacement wins)
                if event.replacedPlayer?.id == playerId {
                    exitInning = inning
                }
            }
        }

        // Determine entry inning
        let entryInning: Int?
        if let subInning = firstSubInning {
            // If they appeared on the field before the sub, it's a position change
            if let batInning = firstBattingInning, batInning < subInning {
                entryInning = nil // Starter
            } else if subInning <= 1 {
                entryInning = nil // Inning 1 sub = starter
            } else {
                entryInning = subInning
            }
        } else {
            entryInning = nil // No sub event = starter
        }

        return (entryInning, exitInning)
    }

    private func createBatter(id: Int, team: BoxscoreTeam?, allPlays: [Play]) -> ScorecardBatter? {
        guard let player = findPlayer(in: team, id: id), let person = player.person else { return nil }
        let name = person.fullName ?? "Unknown"
        let part = getParticipation(for: id, allPlays: allPlays)

        // Handle suffixes like "Jr", "Sr", "II", "III", "IV"
        let components = name.components(separatedBy: " ")
        var abbreviation = components.last ?? ""
        let suffixes = ["Jr", "Sr", "II", "III", "IV", "Jr.", "Sr."]
        if suffixes.contains(abbreviation) && components.count >= 2 {
            abbreviation = "\(components[components.count - 2]) \(abbreviation)"
        }

        return ScorecardBatter(id: id, fullName: name, abbreviation: abbreviation, position: player.position?.abbreviation ?? "", jerseyNumber: player.jerseyNumber, inningEntered: part.entered, inningExited: part.exited)
    }

    private func createPitcher(id: Int, team: BoxscoreTeam?) -> ScorecardPitcher? {
        guard let player = findPlayer(in: team, id: id), let person = player.person else { return nil }
        let stats = player.stats?.pitching
        let ip = stats?.inningsPitched ?? "0.0", er = stats?.runs ?? 0, k = stats?.strikeOuts ?? 0, bb = stats?.baseOnBalls ?? 0, h = stats?.hits ?? 0, r = stats?.runs ?? 0
        return ScorecardPitcher(id: id, fullName: person.fullName ?? "Unknown", stats: "\(ip) IP, \(h) H, \(er) ER, \(bb) BB, \(k) K", ip: ip, h: h, r: r, er: er, bb: bb, k: k)
    }

    private func buildPlayerMaps(boxscore: BoxscoreResponse) -> (nameMap: [Int: String], numberMap: [Int: String]) {
        let playerNameMap = Dictionary(
            uniqueKeysWithValues:
                (boxscore.teams?.home?.players ?? [:]).values.compactMap { player -> (Int, String)? in
                    guard let id = player.person?.id, let fullName = player.person?.fullName else { return nil }
                    return (id, fullName)
                } +
                (boxscore.teams?.away?.players ?? [:]).values.compactMap { player -> (Int, String)? in
                    guard let id = player.person?.id, let fullName = player.person?.fullName else { return nil }
                    return (id, fullName)
                }
        )
        let playerNumberMap = Dictionary(
            uniqueKeysWithValues:
                (boxscore.teams?.home?.players ?? [:]).values.compactMap { player -> (Int, String)? in
                    guard let id = player.person?.id, let jerseyNumber = player.jerseyNumber else { return nil }
                    return (id, jerseyNumber)
                } +
                (boxscore.teams?.away?.players ?? [:]).values.compactMap { player -> (Int, String)? in
                    guard let id = player.person?.id, let jerseyNumber = player.jerseyNumber else { return nil }
                    return (id, jerseyNumber)
                }
        )
        return (playerNameMap, playerNumberMap)
    }

    private func buildLineups(boxscore: BoxscoreResponse, allPlays: [Play]) -> Lineups {
        let homeLineup = (boxscore.teams?.home?.batters ?? [])
            .filter { id in (findPlayer(in: boxscore.teams?.home, id: id)?.position?.abbreviation != "P") }
            .compactMap { createBatter(id: $0, team: boxscore.teams?.home, allPlays: allPlays) }

        let awayLineup = (boxscore.teams?.away?.batters ?? [])
            .filter { id in (findPlayer(in: boxscore.teams?.away, id: id)?.position?.abbreviation != "P") }
            .compactMap { createBatter(id: $0, team: boxscore.teams?.away, allPlays: allPlays) }

        return Lineups(home: homeLineup, away: awayLineup)
    }

    private func buildPitchers(boxscore: BoxscoreResponse) -> ScorecardPitchers {
        let homePitchers = (boxscore.teams?.home?.pitchers ?? []).compactMap { createPitcher(id: $0, team: boxscore.teams?.home) }
        let awayPitchers = (boxscore.teams?.away?.pitchers ?? []).compactMap { createPitcher(id: $0, team: boxscore.teams?.away) }
        return ScorecardPitchers(home: homePitchers, away: awayPitchers)
    }

    private func buildUmpires(boxscore: BoxscoreResponse) -> [ScorecardUmpire] {
        if let officials = boxscore.officials, !officials.isEmpty {
            return officials.compactMap { official -> ScorecardUmpire? in
                guard let name = official.official?.fullName, let type = official.officialType else { return nil }
                let typeMap = ["Home Plate": "HP", "First Base": "1B", "Second Base": "2B", "Third Base": "3B"]
                return ScorecardUmpire(fullName: name, type: typeMap[type] ?? type)
            }
        } else if let info = boxscore.info {
            // Fallback to parsing the "Umpires" string if officials list is missing
            if let umpireNote = info.first(where: { $0.label == "Umpires" }), let value = umpireNote.value {
                // Typical format: "HP: Mark Carlson. 1B: Jordan Baker. 2B: Cory Blaser. 3B: James Hoye."
                let parts = value.components(separatedBy: ". ")
                return parts.compactMap { part -> ScorecardUmpire? in
                    let subParts = part.components(separatedBy: ": ")
                    guard subParts.count == 2 else { return nil }
                    let type = subParts[0].trimmingCharacters(in: .whitespaces)
                    let name = subParts[1].trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
                    return ScorecardUmpire(fullName: name, type: type)
                }
            }
        }
        return []
    }

    private func buildInnings(
        allPlays: [Play],
        linescore: Linescore?,
        playerNameMap: [Int: String],
        playerNumberMap: [Int: String],
        maxInning: Int
    ) -> [ScorecardInning] {
        var scorecardInnings: [ScorecardInning] = []
        let linescoreInnings = linescore?.innings ?? []
        for i in 1...maxInning {
            let inningPlays = allPlays.filter { $0.about?.inning == i }

            // Only include actual at-bats for the scorecard grid
            let atBatPlays = inningPlays.filter { shouldIncludePlayInScorecard($0, includeLive: true) }

            let awayEvents = buildHalfInningEvents(
                from: atBatPlays.filter { $0.about?.isTopInning == true },
                allPlays: allPlays,
                playerNameMap: playerNameMap,
                playerNumberMap: playerNumberMap
            )
            let homeEvents = buildHalfInningEvents(
                from: atBatPlays.filter { $0.about?.isTopInning == false },
                allPlays: allPlays,
                playerNameMap: playerNameMap,
                playerNumberMap: playerNumberMap
            )
            let awayScoringPlayerIds = scoringPlayerIds(
                from: inningPlays.filter { $0.about?.isTopInning == true }
            )
            let homeScoringPlayerIds = scoringPlayerIds(
                from: inningPlays.filter { $0.about?.isTopInning == false }
            )

            // Authoritative per-inning runs from linescore (always correct, even when PBP lags)
            let linescoreInning = linescoreInnings.first { $0.num == i }

            scorecardInnings.append(
                ScorecardInning(
                    num: i,
                    ordinal: "\(i)",
                    home: homeEvents,
                    away: awayEvents,
                    homeRuns: linescoreInning?.home?.runs,
                    awayRuns: linescoreInning?.away?.runs,
                    homeScoringPlayerIds: homeScoringPlayerIds,
                    awayScoringPlayerIds: awayScoringPlayerIds
                )
            )
        }
        return scorecardInnings
    }

    private func buildTimeline(
        allPlays: [Play],
        playerNameMap: [Int: String],
        playerNumberMap: [Int: String]
    ) -> [AtBatEvent] {
        let timeline = allPlays.filter { shouldIncludePlayInScorecard($0, includeLive: false) }.enumerated().map { (idx, play) in
            transformPlayToEvent(
                play,
                allPlays: allPlays,
                playIndex: allPlays.firstIndex(where: { $0.about?.atBatIndex == play.about?.atBatIndex }) ?? 0,
                playerNameMap: playerNameMap,
                playerNumberMap: playerNumberMap
            )
        }.reversed()
        return Array(timeline)
    }

    private func buildLiveAtBat(
        playByPlay: PlayByPlayResponse,
        allPlays: [Play],
        linescore: Linescore?,
        playerNameMap: [Int: String],
        playerNumberMap: [Int: String]
    ) -> AtBatEvent? {
        let currentBatterId = linescore?.offense?.batter?.id
        guard let currentPlay = playByPlay.currentPlay,
              currentPlay.about?.isComplete == false,
              shouldIncludePlayInScorecard(currentPlay, includeLive: true),
              currentBatterId == nil || currentPlay.matchup?.batter?.id == currentBatterId else {
            return nil
        }
        let currentIndex = allPlays.firstIndex(where: { $0.about?.atBatIndex == currentPlay.about?.atBatIndex }) ?? max(allPlays.count - 1, 0)
        return transformPlayToEvent(
            currentPlay,
            allPlays: allPlays,
            playIndex: currentIndex,
            playerNameMap: playerNameMap,
            playerNumberMap: playerNumberMap
        )
    }

    private func scoringPlayerIds(from plays: [Play]) -> [Int] {
        var scoringIds: [Int] = []

        for play in plays {
            for runner in play.runners ?? [] {
                guard let runnerId = runner.details?.runner?.id else { continue }
                let endBase = runner.movement?.end?.lowercased()
                let didScore = endBase == "score" || endBase == "home" || runner.details?.isScoringEvent == true
                if didScore, !scoringIds.contains(runnerId) {
                    scoringIds.append(runnerId)
                }
            }
        }

        return scoringIds
    }

    private func buildHalfInningEvents(
        from plays: [Play],
        allPlays: [Play],
        playerNameMap: [Int: String],
        playerNumberMap: [Int: String]
    ) -> [AtBatEvent] {
        var events: [AtBatEvent] = []
        var placedRunnerIds = Set<Int>()

        for play in plays {
            let playIndex = allPlays.firstIndex(where: { $0.about?.atBatIndex == play.about?.atBatIndex }) ?? 0

            for runner in placedRunnersStartingInInning(in: play, playerNameMap: playerNameMap) {
                if placedRunnerIds.insert(runner.id).inserted {
                    events.append(
                        transformPlacedRunnerToEvent(
                            runnerId: runner.id,
                            runnerName: runner.name,
                            startingBase: runner.base,
                            seedPlay: play,
                            allPlays: allPlays,
                            playIndex: playIndex,
                            playerNameMap: playerNameMap,
                            playerNumberMap: playerNumberMap
                        )
                    )
                }
            }

            events.append(
                transformPlayToEvent(
                    play,
                    allPlays: allPlays,
                    playIndex: playIndex,
                    playerNameMap: playerNameMap,
                    playerNumberMap: playerNumberMap
                )
            )
        }

        return events
    }

    private func placedRunnersStartingInInning(
        in play: Play,
        playerNameMap: [Int: String]
    ) -> [(id: Int, name: String, base: Int)] {
        let pattern = /^(.+) starts inning at ([1234])(st|nd|rd|th) base\.$/

        return (play.playEvents ?? []).compactMap { event in
            guard event.type == "action",
                  let description = event.details?.description,
                  let match = description.wholeMatch(of: pattern),
                  let base = Int(match.2),
                  let playerId = playerNameMap.first(where: { $0.value == String(match.1) })?.key else {
                return nil
            }

            return (id: playerId, name: String(match.1), base: base)
        }
    }

    private func transformPlacedRunnerToEvent(
        runnerId: Int,
        runnerName: String,
        startingBase: Int,
        seedPlay: Play,
        allPlays: [Play],
        playIndex: Int,
        playerNameMap: [Int: String],
        playerNumberMap: [Int: String]
    ) -> AtBatEvent {
        let inning = seedPlay.about?.inning ?? 1
        let isTop = seedPlay.about?.isTopInning ?? true
        let pitcherId = seedPlay.matchup?.pitcher?.id ?? 0
        let pitcherName = seedPlay.matchup?.pitcher?.fullName ?? "Unknown"

        var state = RunnerBaseState()
        // Set starting base directly
        switch startingBase {
        case 1: state.reachFirst = true
        case 2: state.reachSecond = true
        case 3: state.reachThird = true
        case 4: state.reachHome = true
        default: break
        }

        var currentRunnerId = runnerId

        for i in playIndex..<allPlays.count {
            let play = allPlays[i]
            if play.about?.inning != inning || play.about?.isTopInning != isTop { break }

            for event in play.playEvents ?? [] {
                if event.isSubstitution == true && event.replacedPlayer?.id == currentRunnerId {
                    let pinchRunnerId = event.player?.id
                    if state.pinchRunnerName == nil {
                        state.pinchRunnerName = pinchRunnerId.flatMap { playerNameMap[$0] } ?? event.player?.fullName
                    }
                    if let base = state.currentBase, base < 4 {
                        let jerseyNumber = pinchRunnerId.flatMap { playerNumberMap[$0] }
                        let label = jerseyNumber.map { "PR\n#\($0)" } ?? "PR"
                        state.annotations.append(BaseAnnotation(kind: .pinchRunner, base: base, label: label))
                    }
                    if let pinchRunnerId {
                        currentRunnerId = pinchRunnerId
                    }
                }
            }

            for runner in play.runners ?? [] where runner.details?.runner?.id == currentRunnerId {
                let start = runner.movement?.start?.lowercased() ?? runner.movement?.originBase?.lowercased() ?? ""
                let end = runner.movement?.end?.lowercased() ?? ""

                if start == "1b" { state.reachFirst = true }
                if start == "2b" { state.reachSecond = true }
                if start == "3b" { state.reachThird = true }

                // advanceRunner handles line tracking for normal advancement
                state.advanceRunner(to: end)

                // For scoring from 2nd, ensure intermediate bases are marked
                if end == "score" || end == "home" {
                    if start == "2b" || state.reachSecond { state.reachSecond = true; state.reachThird = true; state.lineToThird = true }
                    if start == "3b" || state.reachThird { state.reachThird = true }
                }

                if runner.movement?.isOut == true {
                    let outBase = runner.movement?.outBase?.lowercased() ?? ""
                    state.recordOut(at: outBase)
                    // recordOut doesn't set lines; placed runners show lines to the out base
                    switch outBase {
                    case "1b": break // no lineToFirst in RunnerBaseState
                    case "2b": state.lineToSecond = true
                    case "3b": state.lineToThird = true
                    case "home": state.lineToHome = true
                    default: break
                    }
                }

                if let credits = runner.credits,
                   let errorCredit = credits.first(where: { ($0.credit ?? "").lowercased().contains("error") }),
                   let posCode = errorCredit.position?.code {
                    let errBase = end == "2b" ? 2 : end == "3b" ? 3 : end == "score" || end == "home" ? 4 : 1
                    state.annotations.append(BaseAnnotation(kind: .error, base: errBase, label: "E\(posCode)"))
                }

                if state.isResolved { break }
            }

            if state.isResolved { break }
        }

        let startedBaseLabel = startingBase == 2 ? "2nd" : startingBase == 3 ? "3rd" : "\(startingBase)th"
        let baseDescription = state.reachHome
            ? "\(runnerName) started the inning on \(startedBaseLabel) base and scored."
            : "\(runnerName) started the inning on \(startedBaseLabel) base."
        let description = enrichedDescription(
            baseDescription: baseDescription,
            pinchRunnerName: state.pinchRunnerName
        )

        return AtBatEvent(
            atBatIndex: seedPlay.about?.atBatIndex,
            batterId: runnerId,
            batterName: runnerName,
            pinchRunnerName: state.pinchRunnerName,
            pitcherId: pitcherId,
            pitcherName: pitcherName,
            inning: inning,
            isTop: isTop,
            result: .runnerOnly,
            description: description,
            balls: 0,
            strikes: 0,
            outs: 0,
            rbi: 0,
            isRunnerOnly: true,
            bases: state.toBasesReached(includeLines: true),
            pitches: nil
        )
    }

    private func transformPlayToEvent(
        _ play: Play,
        allPlays: [Play],
        playIndex: Int,
        playerNameMap: [Int: String],
        playerNumberMap: [Int: String]
    ) -> AtBatEvent {
        let pitches = (play.playEvents ?? []).filter { $0.isPitch == true }.enumerated().map { (index, event) in
            PitchEvent(
                pitchNumber: index + 1,
                description: event.details?.description ?? "",
                outcome: event.details?.call?.description ?? "",
                speed: event.pitchData?.startSpeed,
                pitchType: event.details?.type?.description ?? event.pitchType?.description ?? event.details?.type?.code ?? event.pitchType?.code,
                balls: event.count?.balls,
                strikes: event.count?.strikes,
                x: event.pitchData?.coordinates?.pX,
                z: event.pitchData?.coordinates?.pZ,
                zoneTop: event.pitchData?.strikeZoneTop,
                zoneBottom: event.pitchData?.strikeZoneBottom
            )
        }

        let batterId = play.matchup?.batter?.id ?? 0
        let batterName = play.matchup?.batter?.fullName ?? "Unknown"
        let pitcherId = play.matchup?.pitcher?.id ?? 0
        let pitcherName = play.matchup?.pitcher?.fullName ?? "Unknown"
        let inning = play.about?.inning ?? 1
        let isTop = play.about?.isTopInning ?? true

        var state = RunnerBaseState()

        // Pass 1: Initial reach from the play result
        if let eventType = play.result?.eventType {
            state.applyInitialReach(for: eventType)
        }

        // Check runners in THIS play (for outs or advancements)
        for runner in play.runners ?? [] {
            if runner.details?.runner?.id == batterId {
                let end = runner.movement?.end?.lowercased() ?? ""
                state.advanceBatter(to: end)

                if runner.movement?.isOut == true {
                    let outAt = runner.movement?.outBase?.lowercased() ?? ""
                    state.recordOut(at: outAt)
                }
            }
        }

        // Detect error position from the current play
        let currentEventType = play.result?.eventType ?? ""
        if currentEventType == "field_error" || currentEventType == "error" {
            if let batterRunner = (play.runners ?? []).first(where: { $0.details?.runner?.id == batterId }) {
                let endBase = batterRunner.movement?.end?.lowercased() ?? "1b"
                let base = endBase == "2b" ? 2 : endBase == "3b" ? 3 : endBase == "score" || endBase == "home" ? 4 : 1
                if let errorCredit = batterRunner.credits?.first(where: { ($0.credit ?? "").lowercased().contains("error") }),
                   let posCode = errorCredit.position?.code {
                    state.annotations.append(BaseAnnotation(kind: .error, base: base, label: "E\(posCode)"))
                } else {
                    state.annotations.append(BaseAnnotation(kind: .error, base: base, label: "E"))
                }
            }
        }

        // Pass 2: Subsequent plays in the same inning/half
        var currentRunnerId = batterId
        for i in (playIndex + 1)..<allPlays.count {
            let nextPlay = allPlays[i]
            if nextPlay.about?.inning != inning || nextPlay.about?.isTopInning != isTop { break }

            // Track substitutions for the current runner in this square
            for event in nextPlay.playEvents ?? [] {
                if event.isSubstitution == true && event.replacedPlayer?.id == currentRunnerId {
                    let pinchRunnerId = event.player?.id
                    if state.pinchRunnerName == nil {
                        state.pinchRunnerName = pinchRunnerId.flatMap { playerNameMap[$0] } ?? event.player?.fullName
                    }
                    if let base = state.currentBase, base < 4 {
                        let jerseyNumber = pinchRunnerId.flatMap { playerNumberMap[$0] }
                        let label = jerseyNumber.map { "PR\n#\($0)" } ?? "PR"
                        state.annotations.append(BaseAnnotation(kind: .pinchRunner, base: base, label: label))
                    }
                    if let newId = pinchRunnerId {
                        currentRunnerId = newId
                    }
                }
            }

            for runner in nextPlay.runners ?? [] {
                if runner.details?.runner?.id == currentRunnerId {
                    let end = runner.movement?.end?.lowercased() ?? ""
                    let runnerEventType = runner.details?.eventType?.lowercased() ?? ""
                    let isCaughtStealing = runnerEventType.contains("caught_stealing")
                    let isPickoff = runnerEventType.contains("pickoff") && !isCaughtStealing
                    let isStolenBase = runnerEventType.contains("stolen_base") && !isCaughtStealing

                    // Track base advancement (batter-style: fills all intermediate bases)
                    state.advanceBatter(to: end)

                    // Detect stolen bases
                    if isStolenBase {
                        let sbBase = end == "2b" ? 2 : end == "3b" ? 3 : end == "score" || end == "home" ? 4 : 0
                        if sbBase > 0 {
                            state.annotations.append(BaseAnnotation(kind: .stolenBase, base: sbBase, label: "SB"))
                        }
                    }

                    // Detect errors on runner advancement (e.g. pickoff_error, throwing_error)
                    if let credits = runner.credits {
                        if let errorCredit = credits.first(where: { ($0.credit ?? "").lowercased().contains("error") }),
                           let posCode = errorCredit.position?.code {
                            let errBase = end == "2b" ? 2 : end == "3b" ? 3 : end == "score" || end == "home" ? 4 : 1
                            state.annotations.append(BaseAnnotation(kind: .error, base: errBase, label: "E\(posCode)"))
                        }
                    }

                    if runner.movement?.isOut == true {
                        if isCaughtStealing {
                            let start = runner.movement?.start?.lowercased() ?? ""
                            let targetBase: Int
                            if runnerEventType.contains("_2b") || start == "1b" { targetBase = 2 }
                            else if runnerEventType.contains("_3b") || start == "2b" { targetBase = 3 }
                            else if runnerEventType.contains("_home") || start == "3b" { targetBase = 4 }
                            else { targetBase = 2 }
                            state.annotations.append(BaseAnnotation(kind: .caughtStealing, base: targetBase, label: "CS"))
                        } else if isPickoff {
                            // Pickoff out — don't clear the reached base, just note the out
                        } else {
                            let outAt = runner.movement?.outBase?.lowercased() ?? ""
                            state.recordOut(at: outAt)
                        }
                    }
                }
            }
            if state.isResolved { break }
        }

        // Suppress out-at-first indicator for flyouts and strikeouts
        let event = play.result?.event ?? ""
        let eventType = play.result?.eventType ?? ""
        if eventType == "strikeout" || event == "Flyout" || event == "Pop Out" || event == "Lineout" {
            state.outAtFirst = false
        }

        let playDescription = enrichedDescription(
            baseDescription: play.result?.description ?? "",
            pinchRunnerName: state.pinchRunnerName
        )

        return AtBatEvent(
            atBatIndex: play.about?.atBatIndex,
            batterId: batterId,
            batterName: batterName,
            pinchRunnerName: state.pinchRunnerName,
            pitcherId: pitcherId,
            pitcherName: pitcherName,
            inning: inning,
            isTop: isTop,
            result: scorecardNotation(for: play, batterId: batterId),
            description: playDescription,
            balls: play.count?.balls ?? 0,
            strikes: play.count?.strikes ?? 0,
            outs: play.count?.outs ?? 0,
            rbi: play.result?.rbi ?? 0,
            isRunnerOnly: false,
            bases: state.toBasesReached(includeLines: false),
            pitches: pitches
        )
    }

    private func enrichedDescription(baseDescription: String, pinchRunnerName: String?) -> String {
        guard let pinchRunnerName, !pinchRunnerName.isEmpty else {
            return baseDescription
        }

        let note = "Pinch runner: \(pinchRunnerName)."
        if baseDescription.isEmpty {
            return note
        }
        return "\(baseDescription) \(note)"
    }

    private func scorecardNotation(for play: Play, batterId: Int? = nil) -> ScorecardResult {
        if play.about?.isComplete == false { return .live }
        let eventType = play.result?.eventType ?? ""
        let event = play.result?.event ?? ""
        let normalizedEvent = event.lowercased()
        switch eventType {
        case "single": return .single
        case "double": return .double
        case "triple": return .triple
        case "home_run": return .homeRun
        case "walk": return .walk
        case "intent_walk": return .intentionalWalk
        case "hit_by_pitch": return .hitByPitch
        case "strikeout":
            let lastPitchCode = play.playEvents?.last(where: { $0.isPitch == true })?.details?.code ?? ""
            return lastPitchCode == "C" ? .strikeoutLooking : .strikeoutSwinging
        case "balk": return .balk
        case "wild_pitch": return .wildPitch
        case "passed_ball": return .passedBall
        case "stolen_base": return .stolenBase
        case "caught_stealing": return .caughtStealing
        case "field_error", "error": return .fieldError
        case "fielders_choice", "fielders_choice_out": return .fieldersChoice
        case "sac_fly":
            let loc = play.playEvents?.compactMap({ $0.hitData?.location }).last
            if let loc, loc != "0" { return .sacFly(position: loc) }
            return .sacFly(position: nil)
        case "sac_bunt", "sac_bunt_double_play", "bunt_groundout", "bunt_pop_out": return .sacBunt
        case "field_out", "force_out", "flyout", "foul_fly", "popout", "lineout", "grounded_into_double_play", "grounded_into_triple_play":
            if eventType == "grounded_into_double_play" {
                let outRunners = (play.runners ?? []).filter { $0.movement?.isOut == true }
                let allCodes = outRunners.flatMap { $0.credits?.compactMap { $0.position?.code } ?? [] }
                var sequence: [String] = []
                for code in allCodes {
                    if code != sequence.last { sequence.append(code) }
                }
                return .doublePlay(sequence: sequence.isEmpty ? "" : sequence.joined(separator: "-"))
            }
            if eventType == "grounded_into_triple_play" { return .triplePlay }
            if event == "Flyout" || event == "Foul Fly" {
                let loc = play.playEvents?.compactMap({ $0.hitData?.location }).last
                return .flyout(position: (loc != nil && loc != "0") ? loc! : "")
            }
            if event == "Pop Out" {
                let loc = play.playEvents?.compactMap({ $0.hitData?.location }).last
                return .popout(position: (loc != nil && loc != "0") ? loc! : "")
            }
            if event == "Lineout" {
                let loc = play.playEvents?.compactMap({ $0.hitData?.location }).last
                return .lineout(position: (loc != nil && loc != "0") ? loc! : "")
            }
            if let sequence = play.runners?.first(where: { $0.movement?.isOut == true })?.credits?.compactMap({ $0.position?.code }), !sequence.isEmpty {
                let joined = sequence.joined(separator: "-")
                if eventType == "force_out" { return .forceOut(sequence: joined) }
                return .groundout(sequence: joined)
            }
            if eventType == "force_out" || normalizedEvent.contains("forceout") || normalizedEvent.contains("force out") { return .forceOut(sequence: "") }
            if normalizedEvent.contains("groundout") || normalizedEvent.contains("ground out") || normalizedEvent.contains("unassisted") { return .groundout(sequence: "G") }
            if normalizedEvent.contains("bunt") { return .sacBunt }
            if normalizedEvent.contains("flyout") || normalizedEvent.contains("foul fly") { return .flyout(position: "") }
            if normalizedEvent.contains("lineout") || normalizedEvent.contains("line drive") { return .lineout(position: "") }
            if normalizedEvent.contains("pop out") || normalizedEvent.contains("popup") { return .popout(position: "") }
            return .other(text: String(event.prefix(3)).uppercased())
        case "pickoff_error_1b", "pickoff_error_2b", "pickoff_error_3b": return .fieldError
        case "pickoff_1b", "pickoff_2b", "pickoff_3b": return .pickoff
        default:
            if normalizedEvent.contains("called out on strikes") || normalizedEvent.contains("strikeout looking") { return .strikeoutLooking }
            if normalizedEvent.contains("strikeout") || normalizedEvent.contains("struck out") { return .strikeoutSwinging }
            if normalizedEvent.contains("intentional walk") { return .intentionalWalk }
            if normalizedEvent.contains("walk") { return .walk }
            if normalizedEvent.contains("hit by pitch") { return .hitByPitch }
            if normalizedEvent.contains("fielder") && normalizedEvent.contains("choice") { return .fieldersChoice }
            if normalizedEvent.contains("sacrifice fly") { return .sacFly(position: nil) }
            if normalizedEvent.contains("sacrifice") || normalizedEvent.contains("sac bunt") || normalizedEvent.contains("sacrifice bunt") { return .sacBunt }
            if normalizedEvent.contains("double play") { return .doublePlay(sequence: "") }
            if normalizedEvent.contains("triple play") { return .triplePlay }
            if normalizedEvent.contains("stolen base") { return .stolenBase }
            if normalizedEvent.contains("caught stealing") { return .caughtStealing }
            if normalizedEvent.contains("passed ball") { return .passedBall }
            if normalizedEvent.contains("wild pitch") { return .wildPitch }
            if normalizedEvent.contains("balk") { return .balk }
            if normalizedEvent.contains("forceout") || normalizedEvent.contains("force out") { return .forceOut(sequence: "") }
            if normalizedEvent.contains("line drive") { return .lineout(position: "") }
            if normalizedEvent.contains("foul fly") { return .flyout(position: "") }
            if normalizedEvent.contains("error") { return .fieldError }
            if event.isEmpty { return .empty }
            return .other(text: String(event.prefix(3)).uppercased())
        }
    }

    #if DEBUG
    /// Set to `true` to simulate a network failure on schedule fetch (for testing error/loading states)
    var simulateScheduleFailure = false
    #endif

    func fetchSchedule(for date: Date) async throws -> [ScheduleGame] {
        #if DEBUG
        if simulateScheduleFailure {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            throw NSError(domain: "GameService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated network failure"])
        }
        #endif
        return try await MLBAPIClient.shared.fetchSchedule(date: date)
    }
    func selectGame(gamePk: Int) { currentGamePk = gamePk }
    func fetchPlayerInfo(playerId: Int) async throws -> PlayerInfo { return try await MLBAPIClient.shared.fetchPlayer(id: playerId) }
}
