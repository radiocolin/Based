import Foundation
import Network

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
    
    var useMockData = false
    var currentGamePk: Int?
    
    // Polling state
    private var pollingTask: Task<Void, Never>?
    private var lastLinescore: Linescore?
    private var lastScorecard: ScorecardData?
    private var lastGameData: GameData?
    private var lastFetchTime: Date?
    private var isBackgrounded = false
    
    // Network monitoring: skip polls when there's no connectivity
    // NWPathMonitor cannot be restarted after cancel(), so recreate each time.
    private var networkMonitor: NWPathMonitor?
    private var hasConnectivity = true
    private var isConstrainedNetwork = false  // Low Data Mode
    
    // Error backoff: doubles on each consecutive failure, resets on success
    private var consecutiveErrors = 0
    private let maxBackoffInterval: TimeInterval = 60.0
    
    // Post-inning cleanup: re-poll when a half-inning transition is missing its 3rd out
    private var needsInningCleanup = false
    private var inningCleanupAttempts = 0
    private let maxCleanupAttempts = 5

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
            return
        }
        
        // "Mid" = top of currentInning just ended (away batting → check away events)
        // "End" = bottom of currentInning just ended (home batting → check home events)
        let events = (state == "mid") ? inningData.away : inningData.home
        let maxOuts = events.map { $0.outs }.max() ?? 0
        
        if maxOuts < 3 && inningCleanupAttempts < maxCleanupAttempts {
            needsInningCleanup = true
            inningCleanupAttempts += 1
            print("[InningCleanup] \(state.uppercased()) \(currentInning): only \(maxOuts) outs recorded, attempt \(inningCleanupAttempts)/\(maxCleanupAttempts)")
        } else {
            if maxOuts >= 3 && needsInningCleanup {
                print("[InningCleanup] \(state.uppercased()) \(currentInning): 3 outs now recorded, cleanup complete")
            }
            needsInningCleanup = false
            if maxOuts >= 3 { inningCleanupAttempts = 0 }
        }
    }
    
    func startPolling(gamePk: Int) {
        stopPolling()
        currentGamePk = gamePk
        
        // Create a fresh monitor (NWPathMonitor can't be restarted after cancel)
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            self?.hasConnectivity = (path.status == .satisfied)
            self?.isConstrainedNetwork = path.isConstrained  // Low Data Mode
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
        
        pollingTask = Task {
            do {
                try await performSmartUpdate(gamePk: gamePk)
                consecutiveErrors = 0
                
                // If game is already final, don't start polling
                if let linescore = lastLinescore {
                    let phase = livePhase(for: linescore, gameData: nil)
                    if phase == .final {
                        return
                    }
                }
            } catch {
                consecutiveErrors += 1
                print("Initial update failed: \(error)")
            }
            
            while !Task.isCancelled {
                let interval = calculatePollingInterval()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                
                if Task.isCancelled { break }
                
                // Skip network calls when there's no point — backgrounded or no connectivity.
                // This prevents wasted radio cycles on doomed requests.
                if isBackgrounded || !hasConnectivity { continue }
                
                do {
                    try await performSmartUpdate(gamePk: gamePk)
                    consecutiveErrors = 0
                    
                    // Check if game just finished
                    if let linescore = lastLinescore {
                        let phase = livePhase(for: linescore, gameData: nil)
                        if phase == .final {
                            print("Game is final, stopping polling.")
                            break
                        }
                    }
                } catch {
                    consecutiveErrors += 1
                    let backoff = min(basePollingInterval() * pow(2.0, Double(consecutiveErrors - 1)), maxBackoffInterval)
                    print("Update failed (attempt \(consecutiveErrors), next in \(Int(backoff))s): \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Called by SceneDelegate when app enters background
    func didEnterBackground() {
        isBackgrounded = true
    }
    
    /// Called by SceneDelegate when app returns to foreground — triggers an immediate refresh
    func willEnterForeground() {
        isBackgrounded = false
        guard let gamePk = currentGamePk, pollingTask != nil else { return }
        Task {
            do {
                try await performSmartUpdate(gamePk: gamePk)
                consecutiveErrors = 0
            } catch {
                consecutiveErrors += 1
                print("Foreground refresh failed: \(error.localizedDescription)")
            }
        }
    }
    
    func stopPolling() {
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
    }
    
    /// Base interval before error backoff is applied
    private func basePollingInterval() -> TimeInterval {
        // Fast-poll during inning cleanup to capture the missing 3rd-out play
        if needsInningCleanup { return 5.0 }
        
        guard let linescore = lastLinescore else { return 10.0 }
        // MLB API inningState values: "Top", "Bottom", "Mid", "End"
        let state = linescore.inningState?.lowercased() ?? ""
        
        let interval: TimeInterval
        if state == "top" || state == "bottom" {
            interval = 8.0   // Active play
        } else if state == "mid" || state == "end" {
            interval = 15.0  // Between half-innings
        } else if state.contains("final") {
            interval = 300.0
        } else {
            interval = 30.0  // Pre-game, warmup, or unknown
        }
        
        // Low Data Mode: double all intervals to halve bandwidth usage
        return isConstrainedNetwork ? interval * 2 : interval
    }
    
    private func calculatePollingInterval() -> TimeInterval {
        let base = basePollingInterval()
        guard consecutiveErrors > 0 else { return base }
        // Exponential backoff: base * 2^(errors-1), capped at 60s
        let backoff = min(base * pow(2.0, Double(consecutiveErrors - 1)), maxBackoffInterval)
        return backoff
    }
    
    private func performSmartUpdate(gamePk: Int) async throws {
        // 1. Fetch linescore first (smallest payload, needed for early snapshot)
        let linescore = try await MLBAPIClient.shared.fetchLinescore(gamePk: gamePk)
        
        // 2. Send an early snapshot so the header populates immediately on first load
        let isFirstLoad = lastScorecard == nil
        if isFirstLoad {
            await MainActor.run {
                self.lastLinescore = linescore
                let earlySnapshot = self.makeSnapshot(linescore: linescore, scorecard: nil, gameData: nil)
                self.delegate?.didUpdateSnapshot(earlySnapshot)
            }
        }
        
        // 3. Decide if we need to fetch PBP/Boxscore (ScorecardData)
        var shouldFetchScorecard = false
        
        if lastScorecard != nil {
            if linescore.currentPitchCount != lastLinescore?.currentPitchCount ||
               linescore.outs != lastLinescore?.outs || 
               linescore.balls != lastLinescore?.balls || 
               linescore.strikes != lastLinescore?.strikes ||
               linescore.teams?.home?.runs != lastLinescore?.teams?.home?.runs || 
               linescore.teams?.away?.runs != lastLinescore?.teams?.away?.runs ||
               linescore.currentInning != lastLinescore?.currentInning || 
               linescore.inningHalf != lastLinescore?.inningHalf ||
               linescore.offense?.batter?.id != lastLinescore?.offense?.batter?.id ||
               // Runner changes: SB, CS, WP, PB, pickoff errors, defensive indifference
               linescore.offense?.first?.id != lastLinescore?.offense?.first?.id ||
               linescore.offense?.second?.id != lastLinescore?.offense?.second?.id ||
               linescore.offense?.third?.id != lastLinescore?.offense?.third?.id ||
               // Pitcher changes: mid-inning substitutions
               linescore.defense?.pitcher?.id != lastLinescore?.defense?.pitcher?.id ||
               needsInningCleanup {
                shouldFetchScorecard = true
            }
        } else {
            shouldFetchScorecard = true
        }
        
        // 4. Fetch PBP/Boxscore + LiveFeed together when state changed.
        //    LiveFeed (MVR, challenges, weather) only updates after plays, so piggyback
        //    on scorecard fetches instead of hitting it every cycle.
        if shouldFetchScorecard {
            let scorecard = try await fetchScorecard(linescore: linescore)
            
            // Fetch live feed alongside scorecard (fail-safe, non-blocking)
            if !useMockData {
                if let feed = try? await MLBAPIClient.shared.fetchLiveFeed(gamePk: gamePk) {
                    lastGameData = feed.gameData
                }
            }
            
            await MainActor.run {
                self.lastScorecard = scorecard
            }
        }
        
        // Post-inning cleanup: check if a just-completed half-inning is missing its 3rd out
        if let scorecard = lastScorecard {
            checkInningCleanup(scorecard: scorecard, linescore: linescore)
        }
        
        await MainActor.run {
            self.lastLinescore = linescore
            let snapshot = self.makeSnapshot(linescore: linescore, scorecard: self.lastScorecard, gameData: self.lastGameData)
            self.delegate?.didUpdateSnapshot(snapshot)
        }
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
            throw NSError(domain: "GameService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch game data"])
        }
        
        return transformToScorecardData(playByPlay: pbp, boxscore: box, linescore: linescore)
    }

    private func transformToScorecardData(playByPlay: PlayByPlayResponse, boxscore: BoxscoreResponse, linescore: Linescore? = nil) -> ScorecardData {
        func findPlayer(in team: BoxscoreTeam?, id: Int) -> BoxscorePlayer? {
            guard let team = team, let players = team.players else { return nil }
            return players["ID\(id)"] ?? players["\(id)"]
        }

        let allPlays = playByPlay.allPlays ?? []
        let maxInning = max(allPlays.compactMap { $0.about?.inning }.max() ?? 9, 9)

        // Helper to find participation
        // Tracks the first substitution event AND the first at-bat appearance.
        // If the player batted before their first substitution, the sub is
        // just a position change — they are a starter.
        func getParticipation(for playerId: Int) -> (entered: Int?, exited: Int?) {
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

        func createBatter(id: Int, team: BoxscoreTeam?) -> ScorecardBatter? {
            guard let player = findPlayer(in: team, id: id), let person = player.person else { return nil }
            let name = person.fullName ?? "Unknown"
            let part = getParticipation(for: id)
            
            // Handle suffixes like "Jr", "Sr", "II", "III", "IV"
            let components = name.components(separatedBy: " ")
            var abbreviation = components.last ?? ""
            let suffixes = ["Jr", "Sr", "II", "III", "IV", "Jr.", "Sr."]
            if suffixes.contains(abbreviation) && components.count >= 2 {
                abbreviation = "\(components[components.count - 2]) \(abbreviation)"
            }
            
            return ScorecardBatter(id: id, fullName: name, abbreviation: abbreviation, position: player.position?.abbreviation ?? "", jerseyNumber: player.jerseyNumber, inningEntered: part.entered, inningExited: part.exited)
        }

        func createPitcher(id: Int, team: BoxscoreTeam?) -> ScorecardPitcher? {
            guard let player = findPlayer(in: team, id: id), let person = player.person else { return nil }
            let stats = player.stats?.pitching
            let ip = stats?.inningsPitched ?? "0.0", er = stats?.runs ?? 0, k = stats?.strikeOuts ?? 0, bb = stats?.baseOnBalls ?? 0, h = stats?.hits ?? 0, r = stats?.runs ?? 0
            return ScorecardPitcher(id: id, fullName: person.fullName ?? "Unknown", stats: "\(ip) IP, \(h) H, \(er) ER, \(bb) BB, \(k) K", ip: ip, h: h, r: r, er: er, bb: bb, k: k)
        }

        let homeLineup = (boxscore.teams?.home?.batters ?? [])
            .filter { id in (findPlayer(in: boxscore.teams?.home, id: id)?.position?.abbreviation != "P") }
            .compactMap { createBatter(id: $0, team: boxscore.teams?.home) }
            
        let awayLineup = (boxscore.teams?.away?.batters ?? [])
            .filter { id in (findPlayer(in: boxscore.teams?.away, id: id)?.position?.abbreviation != "P") }
            .compactMap { createBatter(id: $0, team: boxscore.teams?.away) }
        
        let homePitchers = (boxscore.teams?.home?.pitchers ?? []).compactMap { createPitcher(id: $0, team: boxscore.teams?.home) }
        let awayPitchers = (boxscore.teams?.away?.pitchers ?? []).compactMap { createPitcher(id: $0, team: boxscore.teams?.away) }
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

        var umpires: [ScorecardUmpire] = []
        if let officials = boxscore.officials, !officials.isEmpty {
            umpires = officials.compactMap { official -> ScorecardUmpire? in
                guard let name = official.official?.fullName, let type = official.officialType else { return nil }
                let typeMap = ["Home Plate": "HP", "First Base": "1B", "Second Base": "2B", "Third Base": "3B"]
                return ScorecardUmpire(fullName: name, type: typeMap[type] ?? type)
            }
        } else if let info = boxscore.info {
            // Fallback to parsing the "Umpires" string if officials list is missing
            if let umpireNote = info.first(where: { $0.label == "Umpires" }), let value = umpireNote.value {
                // Typical format: "HP: Mark Carlson. 1B: Jordan Baker. 2B: Cory Blaser. 3B: James Hoye."
                let parts = value.components(separatedBy: ". ")
                umpires = parts.compactMap { part -> ScorecardUmpire? in
                    let subParts = part.components(separatedBy: ": ")
                    guard subParts.count == 2 else { return nil }
                    let type = subParts[0].trimmingCharacters(in: .whitespaces)
                    let name = subParts[1].trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
                    return ScorecardUmpire(fullName: name, type: type)
                }
            }
        }

        // Find game advisories or status changes to show in a banner
        let advisories = allPlays.compactMap { play -> String? in
            if play.result?.type == "action" { return play.result?.description }
            return nil
        }.reversed() // Most recent first
        
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

        let liveCurrentAtBat: AtBatEvent?
        let currentBatterId = linescore?.offense?.batter?.id
        if let currentPlay = playByPlay.currentPlay,
           currentPlay.about?.isComplete == false,
           shouldIncludePlayInScorecard(currentPlay, includeLive: true),
           currentBatterId == nil || currentPlay.matchup?.batter?.id == currentBatterId {
            let currentIndex = allPlays.firstIndex(where: { $0.about?.atBatIndex == currentPlay.about?.atBatIndex }) ?? max(allPlays.count - 1, 0)
            liveCurrentAtBat = transformPlayToEvent(
                currentPlay,
                allPlays: allPlays,
                playIndex: currentIndex,
                playerNameMap: playerNameMap,
                playerNumberMap: playerNumberMap
            )
        } else {
            liveCurrentAtBat = nil
        }

        // Timeline is all at-bat plays sorted newest-to-oldest
        let timeline = allPlays.filter { shouldIncludePlayInScorecard($0, includeLive: false) }.enumerated().map { (idx, play) in
            transformPlayToEvent(
                play,
                allPlays: allPlays,
                playIndex: allPlays.firstIndex(where: { $0.about?.atBatIndex == play.about?.atBatIndex }) ?? 0,
                playerNameMap: playerNameMap,
                playerNumberMap: playerNumberMap
            )
        }.reversed()
        
        // Extract game info from boxscore info array
        let gameInfo: [GameInfoItem] = (boxscore.info ?? []).compactMap { note in
            guard let label = note.label else { return nil }
            return GameInfoItem(label: label, value: note.value)
        }

        let activePlay = playByPlay.currentPlay?.about?.isComplete == false ? playByPlay.currentPlay : nil

        return ScorecardData(
            teams: ScorecardTeams(home: boxscore.teams?.home?.team ?? Team(id: 0, name: "Home", link: ""), away: boxscore.teams?.away?.team ?? Team(id: 0, name: "Away", link: "")),
            lineups: Lineups(home: homeLineup, away: awayLineup),
            pitchers: ScorecardPitchers(home: homePitchers, away: awayPitchers),
            innings: scorecardInnings,
            timeline: Array(timeline),
            liveCurrentAtBat: liveCurrentAtBat,
            advisories: Array(advisories.prefix(3)),
            umpires: umpires,
            gameInfo: gameInfo,
            currentInning: linescore?.currentInning ?? activePlay?.about?.inning,
            isTopInning: linescore?.isTopInning ?? activePlay?.about?.isTopInning,
            currentBatterId: linescore?.offense?.batter?.id ?? activePlay?.matchup?.batter?.id
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
        var pinchRunnerName: String?

        var reachFirst = startingBase == 1
        var reachSecond = startingBase == 2
        var reachThird = startingBase == 3
        var reachHome = startingBase == 4

        var lineToFirst = false
        var lineToSecond = false
        var lineToThird = false
        var lineToHome = false

        var outFirst = false
        var outSecond = false
        var outThird = false
        var outHome = false
        var annotations: [BaseAnnotation] = []
        var currentRunnerId = runnerId

        for i in playIndex..<allPlays.count {
            let play = allPlays[i]
            if play.about?.inning != inning || play.about?.isTopInning != isTop { break }

            for event in play.playEvents ?? [] {
                if event.isSubstitution == true && event.replacedPlayer?.id == currentRunnerId {
                    let pinchRunnerId = event.player?.id
                    if pinchRunnerName == nil {
                        pinchRunnerName = pinchRunnerId.flatMap { playerNameMap[$0] } ?? event.player?.fullName
                    }
                    if let base = currentBaseForRunner(
                        reachFirst: reachFirst,
                        reachSecond: reachSecond,
                        reachThird: reachThird,
                        reachHome: reachHome
                    ), base < 4 {
                        let jerseyNumber = pinchRunnerId.flatMap { playerNumberMap[$0] }
                        let label = jerseyNumber.map { "PR\n#\($0)" } ?? "PR"
                        annotations.append(BaseAnnotation(kind: .pinchRunner, base: base, label: label))
                    }
                    if let pinchRunnerId {
                        currentRunnerId = pinchRunnerId
                    }
                }
            }

            for runner in play.runners ?? [] where runner.details?.runner?.id == currentRunnerId {
                let start = runner.movement?.start?.lowercased() ?? runner.movement?.originBase?.lowercased() ?? ""
                let end = runner.movement?.end?.lowercased() ?? ""
                let outBase = runner.movement?.outBase?.lowercased() ?? ""

                if start == "1b" { reachFirst = true }
                if start == "2b" { reachSecond = true }
                if start == "3b" { reachThird = true }

                switch end {
                case "1b":
                    reachFirst = true
                    lineToFirst = true
                case "2b":
                    reachSecond = true
                    lineToSecond = true
                case "3b":
                    reachThird = true
                    lineToThird = true
                case "score", "home":
                    if start == "2b" || reachSecond { reachSecond = true; reachThird = true }
                    if start == "3b" || reachThird { reachThird = true }
                    reachHome = true
                    if start == "2b" || reachSecond { lineToThird = true }
                    lineToHome = true
                default:
                    break
                }

                if runner.movement?.isOut == true {
                    switch outBase {
                    case "1b":
                        reachFirst = false
                        outFirst = true
                        lineToFirst = true
                    case "2b":
                        reachSecond = false
                        outSecond = true
                        lineToSecond = true
                    case "3b":
                        reachThird = false
                        outThird = true
                        lineToThird = true
                    case "home":
                        reachHome = false
                        outHome = true
                        lineToHome = true
                    default:
                        break
                    }
                }

                if let credits = runner.credits,
                   let errorCredit = credits.first(where: { ($0.credit ?? "").lowercased().contains("error") }),
                   let posCode = errorCredit.position?.code {
                    let errBase = end == "2b" ? 2 : end == "3b" ? 3 : end == "score" || end == "home" ? 4 : 1
                    annotations.append(BaseAnnotation(kind: .error, base: errBase, label: "E\(posCode)"))
                }

                if reachHome || outFirst || outSecond || outThird || outHome {
                    break
                }
            }

            if reachHome || outFirst || outSecond || outThird || outHome {
                break
            }
        }

        let startedBaseLabel = startingBase == 2 ? "2nd" : startingBase == 3 ? "3rd" : "\(startingBase)th"
        let baseDescription = reachHome
            ? "\(runnerName) started the inning on \(startedBaseLabel) base and scored."
            : "\(runnerName) started the inning on \(startedBaseLabel) base."
        let description = enrichedDescription(
            baseDescription: baseDescription,
            pinchRunnerName: pinchRunnerName
        )

        return AtBatEvent(
            batterId: runnerId,
            batterName: runnerName,
            pinchRunnerName: pinchRunnerName,
            pitcherId: pitcherId,
            pitcherName: pitcherName,
            inning: inning,
            isTop: isTop,
            result: "",
            description: description,
            balls: 0,
            strikes: 0,
            outs: 0,
            rbi: 0,
            isRunnerOnly: true,
            bases: BasesReached(
                first: reachFirst,
                second: reachSecond,
                third: reachThird,
                home: reachHome,
                lineToFirst: lineToFirst,
                lineToSecond: lineToSecond,
                lineToThird: lineToThird,
                lineToHome: lineToHome,
                outAtFirst: outFirst,
                outAtSecond: outSecond,
                outAtThird: outThird,
                outAtHome: outHome,
                annotations: annotations.isEmpty ? nil : annotations
            ),
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
        var pinchRunnerName: String?
        
        // Track bases reached
        var reachFirst = false, reachSecond = false, reachThird = false, reachHome = false
        var outFirst = false, outSecond = false, outThird = false, outHome = false
        
        // Pass 1: The current play
        if let eventType = play.result?.eventType {
            if ["single", "walk", "hit_by_pitch", "intent_walk", "field_error", "fielders_choice"].contains(eventType) { reachFirst = true }
            else if eventType == "double" { reachFirst = true; reachSecond = true }
            else if eventType == "triple" { reachFirst = true; reachSecond = true; reachThird = true }
            else if eventType == "home_run" { reachFirst = true; reachSecond = true; reachThird = true; reachHome = true }
        }
        
        // Check runners in THIS play (for outs or advancements)
        for runner in play.runners ?? [] {
            if runner.details?.runner?.id == batterId {
                let end = runner.movement?.end?.lowercased() ?? ""
                if end == "1b" { reachFirst = true }
                else if end == "2b" { reachFirst = true; reachSecond = true }
                else if end == "3b" { reachFirst = true; reachSecond = true; reachThird = true }
                else if end == "score" || end == "home" { reachFirst = true; reachSecond = true; reachThird = true; reachHome = true }
                
                if runner.movement?.isOut == true {
                    let outAt = runner.movement?.outBase?.lowercased() ?? ""
                    if outAt == "1b" { reachFirst = false; outFirst = true }
                    else if outAt == "2b" { reachSecond = false; outSecond = true }
                    else if outAt == "3b" { reachThird = false; outThird = true }
                    else if outAt == "home" { reachHome = false; outHome = true }
                }
            }
        }
        
        // Collect diamond annotations (errors, SB, CS)
        var annotations: [BaseAnnotation] = []
        
        // Detect error position from the current play
        let currentEventType = play.result?.eventType ?? ""
        if currentEventType == "field_error" || currentEventType == "error" {
            // Find which base was reached and the fielder position
            if let batterRunner = (play.runners ?? []).first(where: { $0.details?.runner?.id == batterId }) {
                let endBase = batterRunner.movement?.end?.lowercased() ?? "1b"
                let base = endBase == "2b" ? 2 : endBase == "3b" ? 3 : endBase == "score" || endBase == "home" ? 4 : 1
                // Find the error credit's fielding position
                if let errorCredit = batterRunner.credits?.first(where: { ($0.credit ?? "").lowercased().contains("error") }),
                   let posCode = errorCredit.position?.code {
                    annotations.append(BaseAnnotation(kind: .error, base: base, label: "E\(posCode)"))
                } else {
                    annotations.append(BaseAnnotation(kind: .error, base: base, label: "E"))
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
                    if pinchRunnerName == nil {
                        pinchRunnerName = pinchRunnerId.flatMap { playerNameMap[$0] } ?? event.player?.fullName
                    }
                    if let base = currentBaseForRunner(
                        reachFirst: reachFirst,
                        reachSecond: reachSecond,
                        reachThird: reachThird,
                        reachHome: reachHome
                    ), base < 4 {
                        let jerseyNumber = pinchRunnerId.flatMap { playerNumberMap[$0] }
                        let label = jerseyNumber.map { "PR\n#\($0)" } ?? "PR"
                        annotations.append(BaseAnnotation(kind: .pinchRunner, base: base, label: label))
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
                    
                    // Track base advancement (skip for CS/pickoff where end is empty)
                    if end == "1b" { reachFirst = true }
                    else if end == "2b" { reachFirst = true; reachSecond = true }
                    else if end == "3b" { reachFirst = true; reachSecond = true; reachThird = true }
                    else if end == "score" || end == "home" { reachFirst = true; reachSecond = true; reachThird = true; reachHome = true }
                    
                    // Detect stolen bases
                    if isStolenBase {
                        let sbBase = end == "2b" ? 2 : end == "3b" ? 3 : end == "score" || end == "home" ? 4 : 0
                        if sbBase > 0 {
                            annotations.append(BaseAnnotation(kind: .stolenBase, base: sbBase, label: "SB"))
                        }
                    }
                    
                    // Detect errors on runner advancement (e.g. pickoff_error, throwing_error)
                    if let credits = runner.credits {
                        if let errorCredit = credits.first(where: { ($0.credit ?? "").lowercased().contains("error") }),
                           let posCode = errorCredit.position?.code {
                            // The base reached due to the error
                            let errBase = end == "2b" ? 2 : end == "3b" ? 3 : end == "score" || end == "home" ? 4 : 1
                            annotations.append(BaseAnnotation(kind: .error, base: errBase, label: "E\(posCode)"))
                        }
                    }
                    
                    if runner.movement?.isOut == true {
                        // For caught stealing and pickoffs: the runner already reached
                        // the base they were on. Don't clear it — just add the annotation.
                        if isCaughtStealing {
                            // Determine the target base from the event type or start base
                            let start = runner.movement?.start?.lowercased() ?? ""
                            let targetBase: Int
                            if runnerEventType.contains("_2b") || start == "1b" { targetBase = 2 }
                            else if runnerEventType.contains("_3b") || start == "2b" { targetBase = 3 }
                            else if runnerEventType.contains("_home") || start == "3b" { targetBase = 4 }
                            else { targetBase = 2 }
                            annotations.append(BaseAnnotation(kind: .caughtStealing, base: targetBase, label: "CS"))
                        } else if isPickoff {
                            // Pickoff out — don't clear the reached base, just note the out
                            // The perpendicular out line will be shown via outAt flags
                        } else {
                            // Normal out (e.g., thrown out advancing on a hit)
                            let outAt = runner.movement?.outBase?.lowercased() ?? ""
                            if outAt == "1b" { reachFirst = false; outFirst = true }
                            else if outAt == "2b" { reachSecond = false; outSecond = true }
                            else if outAt == "3b" { reachThird = false; outThird = true }
                            else if outAt == "home" { reachHome = false; outHome = true }
                        }
                    }
                }
            }
            if reachHome || outFirst || outSecond || outThird || outHome { break }
        }

        // Suppress out-at-first indicator for flyouts and strikeouts
        let event = play.result?.event ?? ""
        let eventType = play.result?.eventType ?? ""
        if eventType == "strikeout" || event == "Flyout" || event == "Pop Out" || event == "Lineout" {
            outFirst = false
        }
        
        let playDescription = enrichedDescription(
            baseDescription: play.result?.description ?? "",
            pinchRunnerName: pinchRunnerName
        )

        return AtBatEvent(
            batterId: batterId,
            batterName: batterName,
            pinchRunnerName: pinchRunnerName,
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
            bases: BasesReached(
                first: reachFirst,
                second: reachSecond,
                third: reachThird,
                home: reachHome,
                lineToFirst: nil,
                lineToSecond: nil,
                lineToThird: nil,
                lineToHome: nil,
                outAtFirst: outFirst,
                outAtSecond: outSecond,
                outAtThird: outThird,
                outAtHome: outHome,
                annotations: annotations.isEmpty ? nil : annotations
            ),
            pitches: pitches
        )
    }

    private func currentBaseForRunner(
        reachFirst: Bool,
        reachSecond: Bool,
        reachThird: Bool,
        reachHome: Bool
    ) -> Int? {
        if reachHome { return 4 }
        if reachThird { return 3 }
        if reachSecond { return 2 }
        if reachFirst { return 1 }
        return nil
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

    private func scorecardNotation(for play: Play, batterId: Int? = nil) -> String {
        if play.about?.isComplete == false { return "LIVE" }
        let eventType = play.result?.eventType ?? ""
        let event = play.result?.event ?? ""
        let normalizedEvent = event.lowercased()
        switch eventType {
        case "single": return "1B"
        case "double": return "2B"
        case "triple": return "3B"
        case "home_run": return "HR"
        case "walk": return "BB"
        case "intent_walk": return "IBB"
        case "hit_by_pitch": return "HBP"
        case "strikeout":
            let lastPitchCode = play.playEvents?.last(where: { $0.isPitch == true })?.details?.code ?? ""
            return lastPitchCode == "C" ? "Ʞ" : "K"
        case "balk": return "BK"
        case "wild_pitch": return "WP"
        case "passed_ball": return "PB"
        case "stolen_base": return "SB"
        case "caught_stealing": return "CS"
        case "field_error", "error": return "E"
        case "fielders_choice", "fielders_choice_out": return "FC"
        case "sac_fly": return "SF"
        case "sac_bunt", "sac_bunt_double_play", "bunt_groundout", "bunt_pop_out": return "SAC"
        case "field_out", "force_out", "flyout", "foul_fly", "popout", "lineout", "grounded_into_double_play", "grounded_into_triple_play":
            if eventType == "grounded_into_double_play" {
                // Chain credits from all out-runners to get the full fielding sequence (e.g. 4-6-3)
                let outRunners = (play.runners ?? []).filter { $0.movement?.isOut == true }
                let allCodes = outRunners.flatMap { $0.credits?.compactMap { $0.position?.code } ?? [] }
                // Deduplicate consecutive positions (relay player appears at end of one chain and start of next)
                var sequence: [String] = []
                for code in allCodes {
                    if code != sequence.last { sequence.append(code) }
                }
                if !sequence.isEmpty {
                    return "\(sequence.joined(separator: "-"))\nGIDP"
                }
                return "GIDP"
            }
            if eventType == "grounded_into_triple_play" {
                return "TP"
            }
            if event == "Flyout" || event == "Foul Fly" {
                if let loc = play.playEvents?.compactMap({ $0.hitData?.location }).last, loc != "0" {
                    return "F\(loc)"
                }
                return "F"
            }
            if event == "Pop Out" || event == "Lineout" {
                if let loc = play.playEvents?.compactMap({ $0.hitData?.location }).last, loc != "0" {
                    let prefix = (event == "Pop Out") ? "P" : (event == "Lineout" ? "L" : "F")
                    return "\(prefix)\(loc)"
                }
            }
            
            // For other outs, use the credit sequence if available
            if let sequence = play.runners?.first(where: { $0.movement?.isOut == true })?.credits?.compactMap({ $0.position?.code }), !sequence.isEmpty {
                return sequence.joined(separator: "-")
            }
            
            if eventType == "force_out" || normalizedEvent.contains("forceout") || normalizedEvent.contains("force out") { return "FO" }
            if normalizedEvent.contains("unassisted") { return "U" }
            if normalizedEvent.contains("groundout") || normalizedEvent.contains("ground out") { return "G" }
            if normalizedEvent.contains("bunt") { return "BUNT" }
            if normalizedEvent.contains("flyout") || normalizedEvent.contains("foul fly") { return "F" }
            if normalizedEvent.contains("lineout") || normalizedEvent.contains("line drive") { return "L" }
            if normalizedEvent.contains("pop out") || normalizedEvent.contains("popup") { return "P" }
            return String(event.prefix(3)).uppercased()
        case "pickoff_error_1b", "pickoff_error_2b", "pickoff_error_3b": return "E"
        case "pickoff_1b", "pickoff_2b", "pickoff_3b": return "PO"
        default: 
            if normalizedEvent.contains("called out on strikes") || normalizedEvent.contains("strikeout looking") {
                return "Ʞ"
            }
            if normalizedEvent.contains("strikeout") || normalizedEvent.contains("struck out") { return "K" }
            if normalizedEvent.contains("intentional walk") { return "IBB" }
            if normalizedEvent.contains("walk") { return "BB" }
            if normalizedEvent.contains("hit by pitch") { return "HBP" }
            if normalizedEvent.contains("fielder") && normalizedEvent.contains("choice") { return "FC" }
            if normalizedEvent.contains("sacrifice fly") { return "SAC" }
            if normalizedEvent.contains("sacrifice") || normalizedEvent.contains("sac bunt") || normalizedEvent.contains("sacrifice bunt") { return "SAC" }
            if normalizedEvent.contains("double play") { return "GIDP" }
            if normalizedEvent.contains("triple play") { return "TP" }
            if normalizedEvent.contains("stolen base") { return "SB" }
            if normalizedEvent.contains("caught stealing") { return "CS" }
            if normalizedEvent.contains("passed ball") { return "PB" }
            if normalizedEvent.contains("wild pitch") { return "WP" }
            if normalizedEvent.contains("balk") { return "BK" }
            if normalizedEvent.contains("forceout") || normalizedEvent.contains("force out") { return "FO" }
            if normalizedEvent.contains("line drive") { return "L" }
            if normalizedEvent.contains("foul fly") { return "F" }
            if normalizedEvent.contains("error") { return "E" }
            if event.isEmpty { return "" }
            return String(event.prefix(3)).uppercased()
        }
    }

    /// Set to `true` to simulate a network failure on schedule fetch (for testing error/loading states)
    var simulateScheduleFailure = true

    func fetchSchedule(for date: Date) async throws -> [ScheduleGame] {
        if simulateScheduleFailure {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            throw NSError(domain: "GameService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated network failure"])
        }
        return try await MLBAPIClient.shared.fetchSchedule(date: date)
    }
    func selectGame(gamePk: Int) { currentGamePk = gamePk }
    func fetchPlayerInfo(playerId: Int) async throws -> PlayerInfo { return try await MLBAPIClient.shared.fetchPlayer(id: playerId) }
}
