import Foundation
import OSLog

struct ScorecardDataTransformer {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Based", category: "ScorecardDataTransformer")

    static func transformToScorecardData(playByPlay: PlayByPlayResponse, boxscore: BoxscoreResponse, linescore: Linescore? = nil) -> ScorecardData {
        let allPlays = playByPlay.allPlays ?? []
        let maxInning = max(allPlays.compactMap { $0.about?.inning }.max() ?? 9, 9)

        let isGameComplete = linescore.map { livePhase(for: $0, gameData: nil) == .final } ?? false

        let (playerNameMap, playerNumberMap) = buildPlayerMaps(boxscore: boxscore)
        let lineups = buildLineups(boxscore: boxscore, allPlays: allPlays, isGameComplete: isGameComplete)
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

        let advisories = allPlays.compactMap { play -> String? in
            if play.result?.type == "action" { return play.result?.description }
            return nil
        }.reversed()

        let gameInfo: [GameInfoItem] = (boxscore.info ?? []).compactMap { note in
            guard let label = note.label else { return nil }
            return GameInfoItem(label: label, value: note.value)
        }

        let activePlay = playByPlay.currentPlay?.about?.isComplete == false ? playByPlay.currentPlay : nil

        let gameDate: String? = {
            guard let iso = allPlays.first?.about?.startTime else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return nil }
            let display = DateFormatter()
            display.dateFormat = "EEEE, MMMM d, yyyy"
            return display.string(from: date)
        }()

        return ScorecardData(
            teams: ScorecardTeams(home: boxscore.teams?.home?.team ?? Team(id: 0, name: "Home", link: ""), away: boxscore.teams?.away?.team ?? Team(id: 0, name: "Away", link: "")),
            lineups: lineups,
            pitchers: pitchers,
            innings: scorecardInnings,
            scheduledInnings: linescore?.scheduledInnings ?? 9,
            timeline: timeline,
            liveCurrentAtBat: liveCurrentAtBat,
            advisories: Array(advisories.prefix(3)),
            umpires: umpires,
            gameInfo: gameInfo,
            gameDate: gameDate,
            currentInning: linescore?.currentInning ?? activePlay?.about?.inning,
            isTopInning: linescore?.isTopInning ?? activePlay?.about?.isTopInning,
            currentBatterId: (linescore?.offense?.batter?.id ?? activePlay?.matchup?.batter?.id).map(String.init)
        )
    }

    private static func buildPlayerMaps(boxscore: BoxscoreResponse) -> (nameMap: [Int: String], numberMap: [Int: String]) {
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

    private static func buildLineups(boxscore: BoxscoreResponse, allPlays: [Play], isGameComplete: Bool) -> Lineups {
        let homeLineup = buildLineup(team: boxscore.teams?.home, allPlays: allPlays, isGameComplete: isGameComplete)
        let awayLineup = buildLineup(team: boxscore.teams?.away, allPlays: allPlays, isGameComplete: isGameComplete)

        return Lineups(home: homeLineup, away: awayLineup)
    }

    private static func buildLineup(team: BoxscoreTeam?, allPlays: [Play], isGameComplete: Bool) -> [ScorecardBatter] {
        guard let team else { return [] }

        typealias LineupEntry = (id: Int, batter: ScorecardBatter, battingSlot: Int, entryInning: Int, exitInning: Int, originalIndex: Int)
        let batterIds = uniquePreservingOrder(team.batters ?? [])

        let entries: [LineupEntry] = batterIds
            .compactMap { id in
                guard let batter = createBatter(id: id, team: team, allPlays: allPlays) else { return nil }
                let player = findPlayer(in: team, id: id)
                let battingSlot = battingOrderSlot(for: player, fallbackIds: team.battingOrder, playerId: id)
                let isPitcherWithoutLineupSlot = player?.position?.abbreviation == "P" && battingSlot == Int.max
                guard !isPitcherWithoutLineupSlot else { return nil }
                let entryInning = batter.inningEntered ?? 0
                let exitInning = batter.inningExited ?? Int.max
                let originalIndex = batterIds.firstIndex(of: id) ?? Int.max
                return (id, batter, battingSlot, entryInning, exitInning, originalIndex)
            }
            // A player who was assigned a batting-order slot but was displaced (a later occupant
            // is on record) or the game has ended without him ever facing a pitch never actually
            // batted, even though the box score formally slotted him in — very common for a relief
            // pitcher who's pulled again before his turn comes up. Those get no scorecard row.
            .filter { entry in
                let wasDisplaced = entry.batter.inningExited != nil
                guard wasDisplaced || isGameComplete else { return true }
                return hasPlateAppearance(playerId: entry.id, allPlays: allPlays)
            }
        return entries
            .sorted { lhs, rhs in
                if lhs.battingSlot != rhs.battingSlot { return lhs.battingSlot < rhs.battingSlot }
                if lhs.entryInning != rhs.entryInning { return lhs.entryInning < rhs.entryInning }
                if lhs.exitInning != rhs.exitInning { return lhs.exitInning < rhs.exitInning }
                return lhs.originalIndex < rhs.originalIndex
            }
            .map(\.batter)
    }

    private static func hasPlateAppearance(playerId: Int, allPlays: [Play]) -> Bool {
        allPlays.contains {
            $0.matchup?.batter?.id == playerId && shouldIncludePlayInScorecard($0, includeLive: true)
        }
    }

    private static func buildPitchers(boxscore: BoxscoreResponse) -> ScorecardPitchers {
        let homePitchers = (boxscore.teams?.home?.pitchers ?? []).compactMap { createPitcher(id: $0, team: boxscore.teams?.home) }
        let awayPitchers = (boxscore.teams?.away?.pitchers ?? []).compactMap { createPitcher(id: $0, team: boxscore.teams?.away) }
        return ScorecardPitchers(home: homePitchers, away: awayPitchers)
    }

    private static func buildUmpires(boxscore: BoxscoreResponse) -> [ScorecardUmpire] {
        if let officials = boxscore.officials, !officials.isEmpty {
            return officials.compactMap { official -> ScorecardUmpire? in
                guard let name = official.official?.fullName, let type = official.officialType else { return nil }
                let typeMap = ["Home Plate": "HP", "First Base": "1B", "Second Base": "2B", "Third Base": "3B"]
                return ScorecardUmpire(fullName: name, type: typeMap[type] ?? type)
            }
        } else if let info = boxscore.info {
            if let umpireNote = info.first(where: { $0.label == "Umpires" }), let value = umpireNote.value {
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

    private static func buildInnings(
        allPlays: [Play],
        linescore: Linescore?,
        playerNameMap: [Int: String],
        playerNumberMap: [Int: String],
        maxInning: Int
    ) -> [ScorecardInning] {
        var scorecardInnings: [ScorecardInning] = []
        let linescoreInnings = linescore?.innings ?? []
        var awayLastPitcherId: String?
        var awayLastPitcherName: String?
        var homeLastPitcherId: String?
        var homeLastPitcherName: String?

        for i in 1...maxInning {
            let inningPlays = allPlays.filter { $0.about?.inning == i }
            let atBatPlays = inningPlays.filter { shouldIncludePlayInScorecard($0, includeLive: true) }

            let awayResult = buildHalfInningEvents(
                from: atBatPlays.filter { $0.about?.isTopInning == true },
                allPlays: allPlays,
                playerNameMap: playerNameMap,
                playerNumberMap: playerNumberMap,
                initialPitcherId: awayLastPitcherId,
                initialPitcherName: awayLastPitcherName
            )
            awayLastPitcherId = awayResult.lastPitcherId
            awayLastPitcherName = awayResult.lastPitcherName

            let homeResult = buildHalfInningEvents(
                from: atBatPlays.filter { $0.about?.isTopInning == false },
                allPlays: allPlays,
                playerNameMap: playerNameMap,
                playerNumberMap: playerNumberMap,
                initialPitcherId: homeLastPitcherId,
                initialPitcherName: homeLastPitcherName
            )
            homeLastPitcherId = homeResult.lastPitcherId
            homeLastPitcherName = homeResult.lastPitcherName

            let awayScoringPlayerIds = scoringPlayerIds(from: inningPlays.filter { $0.about?.isTopInning == true })
            let homeScoringPlayerIds = scoringPlayerIds(from: inningPlays.filter { $0.about?.isTopInning == false })

            let linescoreInning = linescoreInnings.first { $0.num == i }

            scorecardInnings.append(
                ScorecardInning(
                    num: i,
                    ordinal: "\(i)",
                    home: homeResult.events,
                    away: awayResult.events,
                    homeRuns: linescoreInning?.home?.runs,
                    awayRuns: linescoreInning?.away?.runs,
                    homeScoringPlayerIds: homeScoringPlayerIds,
                    awayScoringPlayerIds: awayScoringPlayerIds
                )
            )
        }
        return scorecardInnings
    }

    private static func buildTimeline(
        allPlays: [Play],
        playerNameMap: [Int: String],
        playerNumberMap: [Int: String]
    ) -> [AtBatEvent] {
        let filteredPlays = allPlays.filter { shouldIncludePlayInScorecard($0, includeLive: false) }
        
        var awayLastPitcherId: String?
        var awayLastPitcherName: String?
        var homeLastPitcherId: String?
        var homeLastPitcherName: String?
        
        let timelineEvents = filteredPlays.map { play -> AtBatEvent in
            let isTop = play.about?.isTopInning ?? true
            let lastId = isTop ? awayLastPitcherId : homeLastPitcherId
            let lastName = isTop ? awayLastPitcherName : homeLastPitcherName
            
            let event = transformPlayToEvent(
                play,
                allPlays: allPlays,
                playIndex: allPlays.firstIndex(where: { $0.about?.atBatIndex == play.about?.atBatIndex }) ?? 0,
                playerNameMap: playerNameMap,
                playerNumberMap: playerNumberMap,
                lastPitcherId: lastId,
                lastPitcherName: lastName
            )
            
            if isTop {
                awayLastPitcherId = event.pitcherId
                awayLastPitcherName = event.pitcherName
            } else {
                homeLastPitcherId = event.pitcherId
                homeLastPitcherName = event.pitcherName
            }
            
            return event
        }
        
        return Array(timelineEvents.reversed())
    }

    private static func buildLiveAtBat(
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
        let currentIsTop = currentPlay.about?.isTopInning ?? true
        let previousPlay = allPlays[..<currentIndex].reversed().first {
            shouldIncludePlayInScorecard($0, includeLive: false) &&
            ($0.about?.isTopInning ?? true) == currentIsTop
        }
        return transformPlayToEvent(
            currentPlay,
            allPlays: allPlays,
            playIndex: currentIndex,
            playerNameMap: playerNameMap,
            playerNumberMap: playerNumberMap,
            lastPitcherId: previousPlay?.matchup?.pitcher?.id.map(String.init),
            lastPitcherName: previousPlay?.matchup?.pitcher?.fullName
        )
    }

    private static func scoringPlayerIds(from plays: [Play]) -> [String] {
        var scoringIds: [String] = []
        for play in plays {
            for runner in play.runners ?? [] {
                guard let runnerId = runner.details?.runner?.id else { continue }
                let endBase = runner.movement?.end?.lowercased()
                let didScore = endBase == "score" || endBase == "home" || runner.details?.isScoringEvent == true
                let idString = String(runnerId)
                if didScore, !scoringIds.contains(idString) {
                    scoringIds.append(idString)
                }
            }
        }
        return scoringIds
    }

    private static func buildHalfInningEvents(
        from plays: [Play],
        allPlays: [Play],
        playerNameMap: [Int: String],
        playerNumberMap: [Int: String],
        initialPitcherId: String?,
        initialPitcherName: String?
    ) -> (events: [AtBatEvent], lastPitcherId: String?, lastPitcherName: String?) {
        var events: [AtBatEvent] = []
        var placedRunnerIds = Set<Int>()
        var currentLastPitcherId = initialPitcherId
        var currentLastPitcherName = initialPitcherName

        for play in plays {
            let playIndex = allPlays.firstIndex(where: { $0.about?.atBatIndex == play.about?.atBatIndex }) ?? 0

            for runner in placedRunnersStartingInInning(in: play, playerNameMap: playerNameMap) {
                if placedRunnerIds.insert(runner.id).inserted {
                    let event = transformPlacedRunnerToEvent(
                        runnerId: runner.id,
                        runnerName: runner.name,
                        startingBase: runner.base,
                        seedPlay: play,
                        allPlays: allPlays,
                        playIndex: playIndex,
                        playerNameMap: playerNameMap,
                        playerNumberMap: playerNumberMap,
                        lastPitcherId: currentLastPitcherId,
                        lastPitcherName: currentLastPitcherName
                    )
                    events.append(event)
                    currentLastPitcherId = event.pitcherId
                    currentLastPitcherName = event.pitcherName
                }
            }

            let event = transformPlayToEvent(
                play,
                allPlays: allPlays,
                playIndex: playIndex,
                playerNameMap: playerNameMap,
                playerNumberMap: playerNumberMap,
                lastPitcherId: currentLastPitcherId,
                lastPitcherName: currentLastPitcherName
            )
            events.append(event)
            currentLastPitcherId = event.pitcherId
            currentLastPitcherName = event.pitcherName
        }
        return (events, currentLastPitcherId, currentLastPitcherName)
    }

    private static func placedRunnersStartingInInning(in play: Play, playerNameMap: [Int: String]) -> [(id: Int, name: String, base: Int)] {
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

    private static func transformPlacedRunnerToEvent(
        runnerId: Int,
        runnerName: String,
        startingBase: Int,
        seedPlay: Play,
        allPlays: [Play],
        playIndex: Int,
        playerNameMap: [Int: String],
        playerNumberMap: [Int: String],
        lastPitcherId: String?,
        lastPitcherName: String?
    ) -> AtBatEvent {
        let inning = seedPlay.about?.inning ?? 1
        let isTop = seedPlay.about?.isTopInning ?? true
        let pitcherId = String(seedPlay.matchup?.pitcher?.id ?? 0)
        let pitcherName = seedPlay.matchup?.pitcher?.fullName ?? "Unknown"
        let isPitchingChange = lastPitcherId != nil && pitcherId != lastPitcherId
        let previousPitcherName = isPitchingChange ? lastPitcherName : nil

        var state = RunnerBaseState()
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

                state.advanceRunner(to: end)

                if end == "score" || end == "home" {
                    if start == "2b" || state.reachSecond { state.reachSecond = true; state.reachThird = true; state.lineToThird = true }
                    if start == "3b" || state.reachThird { state.reachThird = true }
                }

                if runner.movement?.isOut == true {
                    let outBase = runner.movement?.outBase?.lowercased() ?? ""
                    state.recordOut(at: outBase)
                    switch outBase {
                    case "1b": break
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
        let description = enrichedDescription(baseDescription: baseDescription, pinchRunnerName: state.pinchRunnerName)

        return AtBatEvent(
            atBatIndex: seedPlay.about?.atBatIndex,
            batterId: String(runnerId),
            batterName: runnerName,
            pinchRunnerName: state.pinchRunnerName,
            pitcherId: pitcherId,
            pitcherName: pitcherName,
            previousPitcherName: previousPitcherName,
            inning: inning,
            isTop: isTop,
            result: .runnerOnly,
            description: description,
            balls: 0,
            strikes: 0,
            outs: 0,
            rbi: 0,
            isRunnerOnly: true,
            isPitchingChange: isPitchingChange,
            bases: state.toBasesReached(includeLines: true),
            pitches: nil
        )
    }

    private static func transformPlayToEvent(
        _ play: Play,
        allPlays: [Play],
        playIndex: Int,
        playerNameMap: [Int: String],
        playerNumberMap: [Int: String],
        lastPitcherId: String?,
        lastPitcherName: String?
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
        let pitcherId = String(play.matchup?.pitcher?.id ?? 0)
        let pitcherName = play.matchup?.pitcher?.fullName ?? "Unknown"
        let inning = play.about?.inning ?? 1
        let isTop = play.about?.isTopInning ?? true
        let isPitchingChange = lastPitcherId != nil && pitcherId != lastPitcherId
        let previousPitcherName = isPitchingChange ? lastPitcherName : nil

        var state = RunnerBaseState()
        if let eventType = play.result?.eventType {
            state.applyInitialReach(for: eventType)
        }

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

        var currentRunnerId = batterId
        for i in (playIndex + 1)..<allPlays.count {
            let nextPlay = allPlays[i]
            if nextPlay.about?.inning != inning || nextPlay.about?.isTopInning != isTop { break }

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
                    let isStolenBase = runnerEventType.contains("stolen_base") && !isCaughtStealing

                    state.advanceBatter(to: end)

                    if isStolenBase {
                        let sbBase = end == "2b" ? 2 : end == "3b" ? 3 : end == "score" || end == "home" ? 4 : 0
                        if sbBase > 0 {
                            state.annotations.append(BaseAnnotation(kind: .stolenBase, base: sbBase, label: "SB"))
                        }
                    }

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
                        } else if !runnerEventType.contains("pickoff") {
                            let outAt = runner.movement?.outBase?.lowercased() ?? ""
                            state.recordOut(at: outAt)
                        }
                    }
                }
            }
            if state.isResolved { break }
        }

        let eventType = play.result?.eventType ?? ""
        let event = play.result?.event ?? ""
        if eventType == "strikeout" || event == "Flyout" || event == "Pop Out" || event == "Lineout" {
            state.outAtFirst = false
        }

        let result = scorecardNotation(for: play, batterId: batterId)
        let playDescription = appendingNote(
            noteForUnmappedResult(result),
            to: enrichedDescription(baseDescription: play.result?.description ?? "", pinchRunnerName: state.pinchRunnerName)
        )

        return AtBatEvent(
            atBatIndex: play.about?.atBatIndex,
            batterId: String(batterId),
            batterName: batterName,
            pinchRunnerName: state.pinchRunnerName,
            pitcherId: pitcherId,
            pitcherName: pitcherName,
            previousPitcherName: previousPitcherName,
            inning: inning,
            isTop: isTop,
            result: result,
            description: playDescription,
            balls: play.count?.balls ?? 0,
            strikes: play.count?.strikes ?? 0,
            outs: play.count?.outs ?? 0,
            rbi: play.result?.rbi ?? 0,
            isRunnerOnly: false,
            isPitchingChange: isPitchingChange,
            bases: state.toBasesReached(includeLines: false),
            pitches: pitches
        )
    }

    private static func enrichedDescription(baseDescription: String, pinchRunnerName: String?) -> String {
        guard let pinchRunnerName, !pinchRunnerName.isEmpty else { return baseDescription }
        let note = "Pinch runner: \(pinchRunnerName)."
        return baseDescription.isEmpty ? note : "\(baseDescription) \(note)"
    }

    static func scorecardNotation(for play: Play, batterId: Int? = nil) -> ScorecardResult {
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
                for code in allCodes { if code != sequence.last { sequence.append(code) } }
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
                return eventType == "force_out" ? .forceOut(sequence: joined) : .groundout(sequence: joined)
            }
            if eventType == "force_out" || normalizedEvent.contains("forceout") || normalizedEvent.contains("force out") { return .forceOut(sequence: "") }
            if normalizedEvent.contains("groundout") || normalizedEvent.contains("ground out") || normalizedEvent.contains("unassisted") { return .groundout(sequence: "G") }
            if normalizedEvent.contains("bunt") { return .sacBunt }
            if normalizedEvent.contains("flyout") || normalizedEvent.contains("foul fly") { return .flyout(position: "") }
            if normalizedEvent.contains("lineout") || normalizedEvent.contains("line drive") { return .lineout(position: "") }
            if normalizedEvent.contains("pop out") || normalizedEvent.contains("popup") { return .popout(position: "") }
            return unmappedResult(event: event, eventType: eventType)
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
            return unmappedResult(event: event, eventType: eventType)
        }
    }

    /// A truncated slice of an unrecognized `event` string (e.g. "Run" from "Runner Out") can
    /// coincidentally spell a real scorecard abbreviation and read as correct notation instead of
    /// a gap in this switch — that's exactly how "Runner Out" produced a misleading "RUN" cell.
    /// A plain dash can't be mistaken for real notation, and the raw strings still land in the log
    /// so an unmapped `event`/`eventType` pair gets noticed during development instead of shipping
    /// silently as plausible-looking wrong data.
    static let unmappedResultText = "—"

    private static func unmappedResult(event: String, eventType: String) -> ScorecardResult {
        guard !event.isEmpty else { return .empty }
        logger.warning("Unmapped scorecard result — eventType: \(eventType, privacy: .public), event: \(event, privacy: .public)")
        return .other(text: unmappedResultText)
    }

    /// A plain "—" in the box doesn't explain itself the way "K" or "1B" do, so a play that hits
    /// the fallback above also gets a plain-language note appended to its description — written
    /// for the person reading the app, not for whoever's debugging it (no mention of event types,
    /// APIs, or which league's feed this came from).
    private static func noteForUnmappedResult(_ result: ScorecardResult) -> String? {
        guard result == .other(text: unmappedResultText) else { return nil }
        return "We couldn't match this play to one of our scorecard symbols, so the box just shows “\(unmappedResultText)”."
    }

    private static func appendingNote(_ note: String?, to description: String) -> String {
        guard let note, !note.isEmpty else { return description }
        return description.isEmpty ? note : "\(description) \(note)"
    }

    static func isStatusOnlyPlay(_ play: Play) -> Bool {
        let type = play.result?.type ?? ""
        let event = play.result?.event?.lowercased() ?? ""
        return type == "action" || event.contains("advisory") || event.contains("status change") || event.contains("pitching change") || event.contains("substitution") || event.contains("defensive sub") || event.contains("coaching change") || event.contains("injury") || event.contains("mound visit") || event.contains("ballpark visit") || event.contains("replay") || event.contains("challenge") || event.contains("delay") || event.contains("timeout") || event.contains("turn")
    }

    static func shouldIncludePlayInScorecard(_ play: Play, includeLive: Bool) -> Bool {
        let type = play.result?.type ?? ""
        let isComplete = play.about?.isComplete == true
        guard type == "atBat", !isStatusOnlyPlay(play) else { return false }
        if isComplete {
            let eventType = play.result?.eventType ?? ""
            // "other_out" covers plays like a challenged/overturned tag play or rundown that
            // retires a runner already on base mid-at-bat (e.g. a caught stealing that ends the
            // half-inning) — MLB's feed still tags `matchup.batter` with whoever was up at the
            // time even though they never got a result, the same way it does for caught_stealing/
            // pickoff. Without this check that batter's still-in-progress PA renders as its own
            // scorecard cell with a misleading result (e.g. "RUN", from truncating "Runner Out").
            if eventType.contains("caught_stealing") || eventType.contains("pickoff") || eventType == "other_out" {
                let batterId = play.matchup?.batter?.id
                let batterWasOut = play.runners?.contains(where: { $0.details?.runner?.id == batterId && $0.movement?.isOut == true }) ?? false
                if !batterWasOut { return false }
            }
            return play.result?.event != nil
        }
        return includeLive && play.about?.isComplete == false && (play.result?.event != nil || play.playEvents?.contains(where: { $0.isPitch == true }) == true)
    }

    static func livePhase(for linescore: Linescore, gameData: GameData?) -> LiveGamePhase {
        let state = linescore.inningState?.lowercased() ?? ""
        if state.contains("final") { return .final }
        if state.contains("scheduled") || state.contains("pre-game") || state.contains("warmup") { return .pregame }
        if let status = gameData?.status {
            let detailedState = status.detailedState.lowercased()
            let statusCode = status.statusCode?.lowercased() ?? ""
            if detailedState == "final" || detailedState == "game over" || detailedState == "completed early" || statusCode == "f" || statusCode == "o" { return .final }
            if detailedState == "scheduled" || detailedState == "pre-game" { return .pregame }
        }
        return (state == "mid" || state == "end") ? .betweenHalfInnings : .betweenBatters
    }

    static func makeSnapshot(linescore: Linescore, scorecard: ScorecardData?, gameData: GameData?) -> LiveGameSnapshot {
        let basePhase = livePhase(for: linescore, gameData: gameData)
        let currentAtBat = scorecard?.liveCurrentAtBat
        let phase: LiveGamePhase
        switch basePhase {
        case .pregame, .final, .betweenHalfInnings: phase = basePhase
        case .betweenBatters, .activeAtBat: phase = currentAtBat == nil ? .betweenBatters : .activeAtBat
        }
        return LiveGameSnapshot(linescore: linescore, scorecard: scorecard, gameData: gameData, phase: phase, currentAtBat: currentAtBat)
    }

    static func isGameFinal(linescore: Linescore, gameData: GameData?) -> Bool {
        livePhase(for: linescore, gameData: gameData) == .final
    }

    private static func findPlayer(in team: BoxscoreTeam?, id: Int) -> BoxscorePlayer? {
        guard let team = team, let players = team.players else { return nil }
        return players["ID\(id)"] ?? players["\(id)"]
    }

    private static func uniquePreservingOrder(_ values: [Int]) -> [Int] {
        var seen = Set<Int>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func battingOrderSlot(for player: BoxscorePlayer?, fallbackIds: [Int]?, playerId: Int) -> Int {
        if let raw = player?.battingOrder, raw.count >= 3, let value = Int(raw) {
            return max(1, value / 100)
        }
        if let fallbackIndex = fallbackIds?.firstIndex(of: playerId) {
            return fallbackIndex + 1
        }
        return Int.max
    }

    private static func createBatter(id: Int, team: BoxscoreTeam?, allPlays: [Play]) -> ScorecardBatter? {
        guard let player = findPlayer(in: team, id: id), let person = player.person else { return nil }
        let name = person.fullName ?? "Unknown"
        let part = getParticipation(for: id, allPlays: allPlays)
        let components = name.components(separatedBy: " ")
        var abbreviation = components.last ?? ""
        let suffixes = ["Jr", "Sr", "II", "III", "IV", "Jr.", "Sr."]
        if suffixes.contains(abbreviation) && components.count >= 2 { abbreviation = "\(components[components.count - 2]) \(abbreviation)" }
        let battingSlot = battingOrderSlot(for: player, fallbackIds: team?.battingOrder, playerId: id)
        return ScorecardBatter(
            id: String(id),
            fullName: name,
            abbreviation: abbreviation,
            position: player.position?.abbreviation ?? "",
            jerseyNumber: player.jerseyNumber,
            battingOrderSlot: battingSlot == Int.max ? nil : battingSlot,
            inningEntered: part.entered,
            inningExited: part.exited
        )
    }

    private static func createPitcher(id: Int, team: BoxscoreTeam?) -> ScorecardPitcher? {
        guard let player = findPlayer(in: team, id: id), let person = player.person else { return nil }
        let stats = player.stats?.pitching
        let ip = stats?.inningsPitched ?? "0.0", h = stats?.hits ?? 0, er = stats?.runs ?? 0, bb = stats?.baseOnBalls ?? 0, k = stats?.strikeOuts ?? 0, r = stats?.runs ?? 0
        return ScorecardPitcher(id: String(id), fullName: person.fullName ?? "Unknown", stats: "\(ip) IP, \(h) H, \(er) ER, \(bb) BB, \(k) K", ip: ip, h: h, r: r, er: er, bb: bb, k: k)
    }

    private static func getParticipation(for playerId: Int, allPlays: [Play]) -> (entered: Int?, exited: Int?) {
        var firstSubInning: Int?, firstBattingInning: Int?, exitInning: Int?
        for play in allPlays {
            let inning = play.about?.inning ?? 1
            if play.matchup?.batter?.id == playerId && firstBattingInning == nil { firstBattingInning = inning }
            if firstBattingInning == nil {
                for runner in play.runners ?? [] { if runner.details?.runner?.id == playerId { firstBattingInning = inning; break } }
            }
            for event in play.playEvents ?? [] {
                if event.isSubstitution == true && event.player?.id == playerId && firstSubInning == nil { firstSubInning = inning }
                if event.replacedPlayer?.id == playerId { exitInning = inning }
            }
        }
        let entryInning: Int?
        if let subInning = firstSubInning {
            if let batInning = firstBattingInning, batInning < subInning { entryInning = nil }
            else if subInning <= 1 { entryInning = nil }
            else { entryInning = subInning }
        } else { entryInning = nil }
        return (entryInning, exitInning)
    }
}
