import Foundation

/// WPBL's equivalent of ScorecardDataTransformer — a WPBLBoxscore -> ScorecardData compiler,
/// producing the exact same output type the MLB path does so the scorecard UI needs no
/// per-league branching.
///
/// The one thing WPBL's feed doesn't give directly (unlike MLB's explicit runner-movement
/// records) is what happened to *pre-existing* baserunners on each play. Each play instead
/// reports a snapshot of who occupies which base *entering* that play. This transformer
/// recovers movement by diffing consecutive plays' snapshots within a half-inning (by runner
/// name — WPBL's plays don't carry runner ids, only names, resolved to real ids via the
/// boxscore roster) and using the play's narrative text to disambiguate "scored" from "out"
/// when a runner disappears between two snapshots.
///
/// Known gaps, all a direct consequence of what WPBL's API does and doesn't expose (not
/// implementation shortcuts): no pitch location/velocity (`PitchEvent.speed`/`.x`/`.z` stay
/// nil), no mound-visit/challenge/weather/umpire detail, fielding position codes are
/// best-effort parsed from free-text narrative rather than structured data, and live
/// in-progress at-bat rendering (`liveCurrentAtBat`) isn't implemented yet — WPBL's `status`
/// block reports the current batter/pitcher but there's no equivalent of MLB's "current
/// incomplete play" object to build a full AtBatEvent from.
struct WPBLBoxscoreTransformer {

    static func transformToScorecardData(_ boxscore: WPBLBoxscore) -> ScorecardData {
        let awayTeam = boxscore.teams.first { $0.side == "away" }
        let homeTeam = boxscore.teams.first { $0.side == "home" }
        let allPlays = boxscore.plays ?? []
        let nameToId = buildNameToIdMap(teams: boxscore.teams)

        let maxInning = max(
            allPlays.map(\.inning).max() ?? 0,
            awayTeam?.line?.count ?? 0,
            homeTeam?.line?.count ?? 0,
            7
        )
        let awayLineByInning = Dictionary(uniqueKeysWithValues: (awayTeam?.line ?? []).map { ($0.inning, $0.runs) })
        let homeLineByInning = Dictionary(uniqueKeysWithValues: (homeTeam?.line ?? []).map { ($0.inning, $0.runs) })

        var innings: [ScorecardInning] = []
        var chronologicalEvents: [AtBatEvent] = []

        if maxInning >= 1 {
            for i in 1...maxInning {
                let inningPlays = allPlays.filter { $0.inning == i }
                let topPlays = inningPlays.filter { $0.half == "top" }
                let bottomPlays = inningPlays.filter { $0.half == "bottom" }
                let awayEvents = buildHalfInningEvents(topPlays, nameToId: nameToId)
                let homeEvents = buildHalfInningEvents(bottomPlays, nameToId: nameToId)

                innings.append(ScorecardInning(
                    num: i,
                    ordinal: "\(i)",
                    home: homeEvents,
                    away: awayEvents,
                    homeRuns: homeLineByInning[i],
                    awayRuns: awayLineByInning[i],
                    homeScoringPlayerIds: scoringPlayerIds(from: bottomPlays, nameToId: nameToId),
                    awayScoringPlayerIds: scoringPlayerIds(from: topPlays, nameToId: nameToId)
                ))
                chronologicalEvents += awayEvents + homeEvents
            }
        }

        let status = boxscore.status
        let lastPlay = allPlays.last
        let currentInning = status.inning > 0 ? status.inning : lastPlay?.inning
        let isTopInning = status.inning > 0 ? (status.half == "top") : lastPlay.map { $0.half == "top" }
        let currentBatterId = status.batterName.isEmpty ? nil : (nameToId[status.batterName] ?? status.batterName)

        return ScorecardData(
            teams: ScorecardTeams(
                home: Team(id: nil, name: homeTeam?.name, link: nil),
                away: Team(id: nil, name: awayTeam?.name, link: nil)
            ),
            lineups: Lineups(home: buildLineup(team: homeTeam), away: buildLineup(team: awayTeam)),
            pitchers: ScorecardPitchers(home: buildPitchers(team: homeTeam), away: buildPitchers(team: awayTeam)),
            innings: innings,
            scheduledInnings: 7,
            timeline: Array(chronologicalEvents.reversed()),
            liveCurrentAtBat: nil,
            advisories: [],
            umpires: [],
            gameInfo: [],
            gameDate: nil,
            currentInning: currentInning,
            isTopInning: isTopInning,
            currentBatterId: currentBatterId
        )
    }

    // MARK: - Lineups / pitchers (explicit in WPBL's data, no inference needed)

    private static func buildNameToIdMap(teams: [WPBLBoxscoreTeam]) -> [String: String] {
        var map: [String: String] = [:]
        for team in teams {
            for player in team.players ?? [] {
                map[player.name] = player.id
            }
        }
        return map
    }

    private static func buildLineup(team: WPBLBoxscoreTeam?) -> [ScorecardBatter] {
        guard let team else { return [] }
        let playersByName = Dictionary(uniqueKeysWithValues: (team.players ?? []).map { ($0.name, $0) })

        return (team.starters ?? []).map { starter in
            let player = playersByName[starter.name]
            let components = starter.name.components(separatedBy: " ")
            var abbreviation = components.last ?? starter.name
            let suffixes = ["Jr", "Sr", "II", "III", "IV", "Jr.", "Sr."]
            if suffixes.contains(abbreviation) && components.count >= 2 {
                abbreviation = "\(components[components.count - 2]) \(abbreviation)"
            }
            return ScorecardBatter(
                id: player?.id ?? starter.name,
                fullName: starter.name,
                abbreviation: abbreviation,
                position: starter.position,
                jerseyNumber: starter.uniform,
                battingOrderSlot: Int(starter.spot),
                inningEntered: nil,
                inningExited: nil
            )
        }
    }

    private static func buildPitchers(team: WPBLBoxscoreTeam?) -> [ScorecardPitcher] {
        guard let team else { return [] }
        return (team.players ?? []).compactMap { player -> ScorecardPitcher? in
            guard let pitching = player.pitching else { return nil }
            let ip = pitching["ip"] ?? "0.0"
            let h = Int(pitching["h"] ?? "") ?? 0
            let r = Int(pitching["r"] ?? "") ?? 0
            let er = Int(pitching["er"] ?? "") ?? 0
            let bb = Int(pitching["bb"] ?? "") ?? 0
            let so = Int(pitching["so"] ?? "") ?? 0
            return ScorecardPitcher(
                id: player.id,
                fullName: player.name,
                stats: "\(ip) IP, \(h) H, \(er) ER, \(bb) BB, \(so) K",
                ip: ip, h: h, r: r, er: er, bb: bb, k: so
            )
        }
    }

    // MARK: - Play-by-play / runner movement inference

    private static func buildHalfInningEvents(_ plays: [WPBLPlay], nameToId: [String: String]) -> [AtBatEvent] {
        var events: [AtBatEvent] = []
        var lastPitcherName: String?

        for (index, play) in plays.enumerated() {
            let batterId = nameToId[play.batterName] ?? play.batterName
            let pitcherId = nameToId[play.pitcherName] ?? play.pitcherName
            let isPitchingChange = lastPitcherName != nil && play.pitcherName != lastPitcherName
            let previousPitcherName = isPitchingChange ? lastPitcherName : nil

            // Runner tracing always scans the full, unfiltered play sequence (including
            // substitution/pickoff/wild-pitch notices below) since those carry real
            // intermediate base-occupancy snapshots — only the *rendered* row is filtered.
            var state = RunnerBaseState()
            if let token = initialReachToken(for: play) {
                state.applyInitialReach(for: token)
                traceRunnerJourney(startingAt: index, in: plays, runnerName: play.batterName, state: &state)
            }

            if isRenderableAtBat(play) {
                events.append(AtBatEvent(
                    atBatIndex: play.sequence,
                    batterId: batterId,
                    batterName: play.batterName,
                    pinchRunnerName: nil,
                    pitcherId: pitcherId,
                    pitcherName: play.pitcherName,
                    previousPitcherName: previousPitcherName,
                    inning: play.inning,
                    isTop: play.half == "top",
                    result: scorecardResult(for: play),
                    description: play.narrative,
                    balls: play.balls,
                    strikes: play.strikes,
                    outs: play.outs,
                    rbi: play.runsScored,
                    isRunnerOnly: false,
                    isPitchingChange: isPitchingChange,
                    bases: state.toBasesReached(includeLines: false),
                    pitches: buildPitchEvents(play.pitchEvents)
                ))
            }
            lastPitcherName = play.pitcherName
        }
        return events
    }

    /// WPBL's plays[] includes non-plate-appearance entries (substitutions, pickoff attempts,
    /// wild pitches, a runner thrown out mid-at-bat) tagged with whatever batter is *next* up,
    /// not the person the narrative is actually about. A play only represents that batter's own
    /// result when the narrative's subject is literally them — verified empirically against two
    /// completed games rather than assumed from event_type (which conflates "reached on an
    /// error" with pure substitution notices under the single value "unknown").
    private static func isRenderableAtBat(_ play: WPBLPlay) -> Bool {
        !play.batterName.isEmpty && play.narrative.hasPrefix(play.batterName)
    }

    /// Traces one runner (originally this play's batter) forward through the rest of the
    /// half-inning by diffing base-occupancy snapshots between consecutive plays, using the
    /// narrative text to tell "scored" apart from "put out" when they disappear from the diff.
    private static func traceRunnerJourney(startingAt index: Int, in plays: [WPBLPlay], runnerName: String, state: inout RunnerBaseState) {
        guard !state.isResolved else { return }
        var k = index
        while k < plays.count {
            let current = plays[k]
            guard k + 1 < plays.count else {
                // Half-inning ended with this runner still on base — left on base, not an out.
                return
            }
            let next = plays[k + 1]
            let nextBases = (first: next.firstBase, second: next.secondBase, third: next.thirdBase)

            if nextBases.third == runnerName {
                state.advanceRunner(to: "3b")
            } else if nextBases.second == runnerName {
                state.advanceRunner(to: "2b")
            } else if nextBases.first == runnerName {
                state.advanceRunner(to: "1b")
            } else if scoredNames(in: current.narrative).contains(runnerName) {
                state.advanceRunner(to: "score")
                return
            } else {
                if let base = state.currentBase, base < 4 {
                    state.recordOut(at: base == 1 ? "1b" : base == 2 ? "2b" : "3b")
                }
                return
            }
            k += 1
        }
        // Ran out of plays without resolving — runner left on base; state stays at last known position.
    }

    private static let scoredPattern = /([A-Z][A-Za-z'.\-]+(?: [A-Z][A-Za-z'.\-]+)+) scored/

    private static func scoredNames(in narrative: String) -> Set<String> {
        Set(narrative.matches(of: scoredPattern).map { String($0.1) })
    }

    private static func narrativeIndicatesReachedOnError(_ narrative: String) -> Bool {
        let lower = narrative.lowercased()
        // A fielder's-choice play can *also* mention "on an error" (e.g. the batter advanced an
        // extra base on a throwing error) without the batter's own reach being the error — FC
        // notation takes priority in that case.
        guard !lower.contains("fielder's choice") else { return false }
        return lower.contains("reached") && lower.contains("on an error")
    }

    /// Maps WPBL's event_type vocabulary onto the tokens RunnerBaseState.applyInitialReach
    /// already recognizes (same tokens MLB's eventType uses). Anything not listed here means
    /// "batter made an out, never became a baserunner" — the default/correct behavior for
    /// strikeouts, routine groundouts/flyouts/etc., matching how a real scorecard draws nothing
    /// on the diamond for those. Vocabulary verified against two completed games' full play
    /// logs (WPBL.md) rather than guessed — notably WPBL tags "reached first on an error" as
    /// event_type "unknown", the same tag used for pure substitution notices, so that case is
    /// detected from the narrative text instead.
    private static func initialReachToken(for play: WPBLPlay) -> String? {
        if narrativeIndicatesReachedOnError(play.narrative) { return "field_error" }
        switch play.eventType {
        case "single": return "single"
        case "double": return "double"
        case "triple": return "triple"
        case "home_run": return "home_run"
        case "walk": return "walk"
        case "hit_by_pitch": return "hit_by_pitch"
        case "intentional_walk", "intent_walk": return "intent_walk"
        case "fielders_choice": return "fielders_choice"
        default: return nil
        }
    }

    private static func scorecardResult(for play: WPBLPlay) -> ScorecardResult {
        if narrativeIndicatesReachedOnError(play.narrative) { return .fieldError }
        switch play.eventType {
        case "single": return .single
        case "double": return .double
        case "triple": return .triple
        case "home_run": return .homeRun
        case "walk": return .walk
        case "intentional_walk", "intent_walk": return .intentionalWalk
        case "hit_by_pitch": return .hitByPitch
        case "strikeout":
            return play.narrative.lowercased().contains("looking") ? .strikeoutLooking : .strikeoutSwinging
        case "fielders_choice": return .fieldersChoice
        case "stolen_base": return .stolenBase
        case "caught_stealing": return .caughtStealing
        case "wild_pitch": return .wildPitch
        case "passed_ball": return .passedBall
        case "balk": return .balk
        case "sacrifice":
            let lower = play.narrative.lowercased()
            if lower.contains("sacrifice bunt") || lower.contains("sac bunt") { return .sacBunt }
            return .sacFly(position: fieldingPosition(from: play.narrative))
        case "groundout": return .groundout(sequence: fieldingPosition(from: play.narrative) ?? "")
        case "flyout": return .flyout(position: fieldingPosition(from: play.narrative) ?? "")
        case "lineout": return .lineout(position: fieldingPosition(from: play.narrative) ?? "")
        case "popup": return .popout(position: fieldingPosition(from: play.narrative) ?? "")
        case "foul_out": return .flyout(position: fieldingPosition(from: play.narrative) ?? "")
        case "forceout", "force_out": return .forceOut(sequence: fieldingPosition(from: play.narrative) ?? "")
        case "pickoff": return .pickoff
        case "out":
            let lower = play.narrative.lowercased()
            if lower.contains("triple play") { return .triplePlay }
            if lower.contains("double play") { return .doublePlay(sequence: fieldingPosition(from: play.narrative) ?? "") }
            return .other(text: "OUT")
        default: return .other(text: String(play.eventType.prefix(3)).uppercased())
        }
    }

    // Keyed by the exact single-word tokens WPBL's narrative text actually uses (verified against
    // two completed games) — not spelled-out names like "third baseman", which weren't observed.
    private static let positionWordToNumber: [String: String] = [
        "pitcher": "1", "p": "1",
        "catcher": "2", "c": "2",
        "1b": "3", "2b": "4", "3b": "5",
        "ss": "6", "shortstop": "6",
        "lf": "7", "cf": "8", "rf": "9"
    ]

    /// Best-effort — WPBL doesn't give structured fielding-position codes like MLB does, only
    /// free-text narrative (e.g. "grounded out to 3b", "grounded into double play p to 2b to 1b").
    /// Observed narratives consistently use short abbreviations (3b/ss/lf/p/c, ...) after "to",
    /// not spelled-out names, so this works token-by-token rather than substring-searching
    /// (a naive `contains("to ")` would also match inside "in*to* double play").
    private static func fieldingPosition(from narrative: String) -> String? {
        let tokens = narrative.lowercased().split(separator: " ").map(String.init)
        var positions: [String] = []
        for (i, token) in tokens.enumerated() where token == "to" {
            // Multi-hop sequences ("p to 2b to 1b") omit the leading fielder from any "to X" pair —
            // capture it once, from the token immediately before the first "to".
            if positions.isEmpty, i > 0, let leading = matchPosition(tokens[i - 1]) {
                positions.append(leading)
            }
            guard i + 1 < tokens.count, let mapped = matchPosition(tokens[i + 1]) else { continue }
            positions.append(mapped)
        }
        return positions.isEmpty ? nil : positions.joined(separator: "-")
    }

    private static func matchPosition(_ rawToken: String) -> String? {
        let token = rawToken.trimmingCharacters(in: CharacterSet(charactersIn: ".,;()"))
        return positionWordToNumber[token]
    }

    private static func buildPitchEvents(_ events: [WPBLPitchEvent]?) -> [PitchEvent]? {
        guard let events, !events.isEmpty else { return nil }
        return events.enumerated().map { index, event in
            PitchEvent(
                pitchNumber: index + 1,
                description: event.description,
                outcome: event.type,
                speed: nil,
                pitchType: nil,
                balls: nil,
                strikes: nil,
                x: nil,
                z: nil,
                zoneTop: nil,
                zoneBottom: nil
            )
        }
    }

    private static func scoringPlayerIds(from plays: [WPBLPlay], nameToId: [String: String]) -> [String] {
        var ids: [String] = []
        for play in plays {
            for name in scoredNames(in: play.narrative) {
                let id = nameToId[name] ?? name
                if !ids.contains(id) { ids.append(id) }
            }
        }
        return ids
    }
}
