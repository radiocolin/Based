import Foundation

protocol GameUpdateDelegate: AnyObject {
    func didUpdateLinescore(_ linescore: Linescore, pitches: [PitchEvent], gameData: GameData?)
    func didUpdateScorecard(_ scorecard: ScorecardData)
    func didUpdateGameStatus(_ status: String)
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
    private var lastFetchTime: Date?
    
    func startPolling(gamePk: Int) {
        stopPolling()
        currentGamePk = gamePk
        
        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    try await performSmartUpdate(gamePk: gamePk)
                } catch {
                    print("Update failed: \(error)")
                }
                
                let interval = calculatePollingInterval()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        lastLinescore = nil
        lastScorecard = nil
    }
    
    private func calculatePollingInterval() -> TimeInterval {
        guard let linescore = lastLinescore else { return 10.0 }
        let state = linescore.inningState?.lowercased() ?? ""
        
        if state.contains("in progress") || state.contains("live") {
            return 8.0 // Fast polling during active play
        } else if state.contains("warmup") || state.contains("pre-game") {
            return 30.0
        } else if state.contains("final") {
            return 300.0 // Game over, stop or poll very slowly
        } else {
            return 15.0 // Between innings, etc.
        }
    }
    
    private func performSmartUpdate(gamePk: Int) async throws {
        // 1. Always fetch linescore (smallest, highest frequency)
        let linescore = try await MLBAPIClient.shared.fetchLinescore(gamePk: gamePk)
        
        // 2. Fetch live feed (optional, for MVR/Challenges) - Fail-safe
        var liveFeed: LiveFeedResponse?
        if !useMockData {
            liveFeed = try? await MLBAPIClient.shared.fetchLiveFeed(gamePk: gamePk)
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
               linescore.inningHalf != lastLinescore?.inningHalf {
                shouldFetchScorecard = true
            }
        } else {
            shouldFetchScorecard = true
        }
        
        if shouldFetchScorecard {
            let scorecard = try await fetchScorecard()
            await MainActor.run {
                self.lastScorecard = scorecard
                self.delegate?.didUpdateScorecard(scorecard)
            }
        }
        
        await MainActor.run {
            self.lastLinescore = linescore
            
            // Extract current at-bat pitches from the scorecard
            var currentPitches: [PitchEvent] = []
            if let scorecard = lastScorecard {
                let inningNum = linescore.currentInning ?? 1
                let isTop = linescore.inningHalf?.lowercased() == "top"
                let batterId = linescore.offense?.batter?.id
                
                if let inning = scorecard.innings.first(where: { $0.num == inningNum }) {
                    let events = isTop ? inning.away : inning.home
                    if let currentAtBat = events.last(where: { $0.batterId == batterId }) {
                        currentPitches = currentAtBat.pitches ?? []
                    }
                }
            }
            
            self.delegate?.didUpdateLinescore(linescore, pitches: currentPitches, gameData: liveFeed?.gameData)
        }
    }

    func fetchCurrentGame() async throws -> Linescore {
        guard let gamePk = currentGamePk else {
            throw NSError(domain: "GameService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No game selected"])
        }
        return try await MLBAPIClient.shared.fetchLinescore(gamePk: gamePk)
    }

    func fetchScorecard() async throws -> ScorecardData {
        guard let gamePk = currentGamePk else {
            throw NSError(domain: "GameService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No game selected"])
        }
        
        let pbp = try await MLBAPIClient.shared.fetchPlayByPlay(gamePk: gamePk)
        let box = try await MLBAPIClient.shared.fetchBoxscore(gamePk: gamePk)
        
        return transformToScorecardData(playByPlay: pbp, boxscore: box)
    }

    private func transformToScorecardData(playByPlay: PlayByPlayResponse, boxscore: BoxscoreResponse) -> ScorecardData {
        func findPlayer(in team: BoxscoreTeam?, id: Int) -> BoxscorePlayer? {
            guard let team = team, let players = team.players else { return nil }
            return players["ID\(id)"] ?? players["\(id)"]
        }

        let allPlays = playByPlay.allPlays ?? []
        let maxInning = max(allPlays.compactMap { $0.about?.inning }.max() ?? 9, 9)

        // Helper to find participation
        func getParticipation(for playerId: Int) -> (entered: Int?, exited: Int?) {
            var entryInning: Int?
            var exitInning: Int?
            var seenInGame = false

            // 1. Check if they were in the very first play (starting lineup)
            if let firstPlay = allPlays.first {
                // If they are the batter, pitcher, or in any event of the first play (that isn't a sub event), they started.
                if firstPlay.matchup?.batter?.id == playerId || firstPlay.matchup?.pitcher?.id == playerId {
                    seenInGame = true
                }
                for event in firstPlay.playEvents ?? [] {
                    if event.player?.id == playerId && event.isSubstitution != true {
                        seenInGame = true
                    }
                }
            }

            // 2. Scan all plays for substitutions
            for play in allPlays {
                let inning = play.about?.inning ?? 1
                
                // If they appear as a batter in any play, they are in the game
                if play.matchup?.batter?.id == playerId || play.matchup?.pitcher?.id == playerId {
                    seenInGame = true
                }

                for event in play.playEvents ?? [] {
                    // Entry via substitution
                    if event.isSubstitution == true && event.player?.id == playerId {
                        entryInning = inning
                        seenInGame = true
                    }
                    // Exit via replacement
                    if event.replacedPlayer?.id == playerId {
                        exitInning = inning
                    }
                    // Generic appearance
                    if event.player?.id == playerId {
                        seenInGame = true
                    }
                }
            }
            
            // If they are in the boxscore (which they are if we're calling this) 
            // and we never saw an explicit 'substitution' entry for them, 
            // they must have started (or were in the lineup from inning 1).
            if entryInning == nil && seenInGame {
                entryInning = nil // Started
            } else if entryInning == 1 {
                entryInning = nil // Also considered a starter
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
            let ip = stats?.inningsPitched ?? "0.0", er = stats?.runs ?? 0, k = stats?.strikeOuts ?? 0, bb = stats?.baseOnBalls ?? 0, h = stats?.hits ?? 0
            return ScorecardPitcher(id: id, fullName: person.fullName ?? "Unknown", stats: "\(ip) IP, \(h) H, \(er) ER, \(bb) BB, \(k) K")
        }

        let homeLineup = (boxscore.teams?.home?.batters ?? [])
            .filter { id in (findPlayer(in: boxscore.teams?.home, id: id)?.position?.abbreviation != "P") }
            .compactMap { createBatter(id: $0, team: boxscore.teams?.home) }
            
        let awayLineup = (boxscore.teams?.away?.batters ?? [])
            .filter { id in (findPlayer(in: boxscore.teams?.away, id: id)?.position?.abbreviation != "P") }
            .compactMap { createBatter(id: $0, team: boxscore.teams?.away) }
        
        let homePitchers = (boxscore.teams?.home?.pitchers ?? []).compactMap { createPitcher(id: $0, team: boxscore.teams?.home) }
        let awayPitchers = (boxscore.teams?.away?.pitchers ?? []).compactMap { createPitcher(id: $0, team: boxscore.teams?.away) }

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
        for i in 1...maxInning {
            let inningPlays = allPlays.filter { $0.about?.inning == i }
            
            // Only include actual at-bats for the scorecard grid
            let atBatPlays = inningPlays.filter { play in
                let type = play.result?.type ?? ""
                let event = play.result?.event?.lowercased() ?? ""
                
                // Exclude non-at-bat events that should not be in the grid
                let isAction = type == "action" || 
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
                
                let isFinished = play.result?.event != nil
                let isLive = play.about?.isComplete == false
                return type == "atBat" && !isAction && (isFinished || isLive)
            }
            
            let awayEvents = atBatPlays.filter { $0.about?.isTopInning == true }.enumerated().map { (idx, play) in
                transformPlayToEvent(play, allPlays: allPlays, playIndex: allPlays.firstIndex(where: { $0.about?.atBatIndex == play.about?.atBatIndex }) ?? 0)
            }
            let homeEvents = atBatPlays.filter { $0.about?.isTopInning == false }.enumerated().map { (idx, play) in
                transformPlayToEvent(play, allPlays: allPlays, playIndex: allPlays.firstIndex(where: { $0.about?.atBatIndex == play.about?.atBatIndex }) ?? 0)
            }
            
            scorecardInnings.append(ScorecardInning(num: i, ordinal: "\(i)", home: homeEvents, away: awayEvents))
        }
        
        // Extract game info from boxscore info array
        let gameInfo: [GameInfoItem] = (boxscore.info ?? []).compactMap { note in
            guard let label = note.label else { return nil }
            return GameInfoItem(label: label, value: note.value)
        }

        return ScorecardData(
            teams: ScorecardTeams(home: boxscore.teams?.home?.team ?? Team(id: 0, name: "Home", link: ""), away: boxscore.teams?.away?.team ?? Team(id: 0, name: "Away", link: "")),
            lineups: Lineups(home: homeLineup, away: awayLineup),
            pitchers: ScorecardPitchers(home: homePitchers, away: awayPitchers),
            innings: scorecardInnings,
            advisories: Array(advisories.prefix(3)),
            umpires: umpires,
            gameInfo: gameInfo,
            currentInning: playByPlay.currentPlay?.about?.inning,
            isTopInning: playByPlay.currentPlay?.about?.isTopInning,
            currentBatterId: playByPlay.currentPlay?.matchup?.batter?.id
        )
    }

    private func transformPlayToEvent(_ play: Play, allPlays: [Play], playIndex: Int) -> AtBatEvent {
        let pitches = (play.playEvents ?? []).filter { $0.isPitch == true }.enumerated().map { (index, event) in
            PitchEvent(
                pitchNumber: index + 1,
                description: event.details?.description ?? "",
                outcome: event.details?.call?.description ?? "",
                speed: event.pitchData?.startSpeed,
                pitchType: event.pitchType?.code ?? event.pitchType?.description,
                balls: event.count?.balls,
                strikes: event.count?.strikes,
                x: event.pitchData?.coordinates?.pX,
                z: event.pitchData?.coordinates?.pZ,
                zoneTop: event.pitchData?.strikeZoneTop,
                zoneBottom: event.pitchData?.strikeZoneBottom
            )
        }
        
        let batterId = play.matchup?.batter?.id ?? 0
        let inning = play.about?.inning ?? 1
        let isTop = play.about?.isTopInning ?? true
        
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
        
        // Pass 2: Subsequent plays in the same inning/half
        for i in (playIndex + 1)..<allPlays.count {
            let nextPlay = allPlays[i]
            if nextPlay.about?.inning != inning || nextPlay.about?.isTopInning != isTop { break }
            
            for runner in nextPlay.runners ?? [] {
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
            if reachHome || outFirst || outSecond || outThird || outHome { break }
        }

        // Suppress out-at-first indicator for flyouts and strikeouts
        let event = play.result?.event ?? ""
        let eventType = play.result?.eventType ?? ""
        if eventType == "strikeout" || event == "Flyout" || event == "Pop Out" || event == "Lineout" {
            outFirst = false
        }
        
        return AtBatEvent(batterId: batterId, result: scorecardNotation(for: play, batterId: batterId), description: play.result?.description ?? "", balls: play.count?.balls ?? 0, strikes: play.count?.strikes ?? 0, outs: play.count?.outs ?? 0, rbi: play.result?.rbi ?? 0, bases: BasesReached(first: reachFirst, second: reachSecond, third: reachThird, home: reachHome, outAtFirst: outFirst, outAtSecond: outSecond, outAtThird: outThird, outAtHome: outHome), pitches: pitches)
    }

    private func scorecardNotation(for play: Play, batterId: Int? = nil) -> String {
        if play.about?.isComplete == false { return "LIVE" }
        let eventType = play.result?.eventType ?? "", event = play.result?.event ?? ""
        switch eventType {
        case "single": return "1B"
        case "double": return "2B"
        case "triple": return "3B"
        case "home_run": return "HR"
        case "walk": return "BB"
        case "intent_walk": return "IBB"
        case "hit_by_pitch": return "HBP"
        case "strikeout": return event.contains("Looking") ? "Ʞ" : "K"
        case "field_error", "error": return "E"
        case "field_out", "force_out", "flyout", "popout", "lineout", "grounded_into_double_play":
            if eventType == "grounded_into_double_play" {
                // Find the longest credit sequence in this play, usually the one involving the batter's out
                let allCredits = play.runners?.compactMap { $0.credits?.compactMap { $0.position?.code } } ?? []
                if let sequence = allCredits.max(by: { $0.count < $1.count }), !sequence.isEmpty {
                    return "\(sequence.joined(separator: "-"))\nDP"
                }
                return "DP"
            }
            if event == "Flyout" || event == "Pop Out" || event == "Lineout" {
                if let loc = play.playEvents?.compactMap({ $0.hitData?.location }).last, loc != "0" {
                    let prefix = (event == "Pop Out") ? "P" : (event == "Lineout" ? "L" : "F")
                    return "\(prefix)\(loc)"
                }
            }
            
            // For other outs, use the credit sequence if available
            if let sequence = play.runners?.first(where: { $0.movement?.isOut == true })?.credits?.compactMap({ $0.position?.code }), !sequence.isEmpty {
                return sequence.joined(separator: "-")
            }
            
            if event == "Groundout" { return "G" }
            if event == "Flyout" { return "F" }
            if event == "Pop Out" { return "P" }
            if event == "Lineout" { return "L" }
            return String(event.prefix(3)).uppercased()
        case "sac_fly": return "SF"
        case "sac_bunt": return "SAC"
        case "fielders_choice": return "FC"
        case "stolen_base": return "SB"
        case "caught_stealing": return "CS"
        case "wild_pitch": return "WP"
        case "passed_ball": return "PB"
        case "balk": return "BK"
        case "pickoff_error_1b", "pickoff_error_2b", "pickoff_error_3b": return "E"
        case "pickoff_1b", "pickoff_2b", "pickoff_3b": return "PO"
        default: 
            if event.lowercased().contains("double play") { return "DP" }
            if event.lowercased().contains("triple play") { return "TP" }
            if event.lowercased().contains("stolen base") { return "SB" }
            if event.lowercased().contains("caught stealing") { return "CS" }
            if event.isEmpty { return "" }
            return String(event.prefix(3)).uppercased()
        }
    }

    func fetchSchedule(for date: Date) async throws -> [ScheduleGame] { return try await MLBAPIClient.shared.fetchSchedule(date: date) }
    func selectGame(gamePk: Int) { currentGamePk = gamePk }
    func fetchPlayerInfo(playerId: Int) async throws -> PlayerInfo { return try await MLBAPIClient.shared.fetchPlayer(id: playerId) }
}
