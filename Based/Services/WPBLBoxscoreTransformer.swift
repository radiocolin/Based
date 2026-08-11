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

            if let placed = parsePlacedRunner(from: play) {
                events.append(placedRunnerEvent(
                    for: play,
                    runnerName: placed.name,
                    startingBase: placed.base,
                    index: index,
                    in: plays,
                    nameToId: nameToId,
                    isPitchingChange: isPitchingChange,
                    previousPitcherName: previousPitcherName
                ))
                lastPitcherName = play.pitcherName
                continue
            }

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
    ///
    /// One more notice happens to pass that same-subject check: the international-tiebreaker
    /// "runner placed on second" line WPBL emits to start extra innings, e.g. "Elodie Ciamarro
    /// London Studer placed on second (0-0)." — its narrative is tagged with the *next* batter's
    /// name (Elodie Ciamarro) followed by the placed runner's name (London Studer), so it also
    /// starts with `batterName` and would otherwise fall through scorecardResult's switch to the
    /// truncated-eventType fallback ("UNK"). It isn't a plate appearance for either named player —
    /// `parsePlacedRunner`/`placedRunnerEvent` below turn it into its own runner-only "Z" cell for
    /// the placed runner instead (the same way MLB's automatic extra-inning runner is rendered),
    /// so in the normal case this play is handled by `continue` before it ever reaches this check.
    /// This guard stays as a fallback so a "placed on <base>" notice that fails to parse (e.g. an
    /// unexpected name format) still doesn't get misread as `batterName`'s own plate appearance.
    private static func isRenderableAtBat(_ play: WPBLPlay) -> Bool {
        guard !play.batterName.isEmpty && play.narrative.hasPrefix(play.batterName) else { return false }
        return !narrativeIndicatesRunnerPlacement(play.narrative)
    }

    private static func narrativeIndicatesRunnerPlacement(_ narrative: String) -> Bool {
        let lower = narrative.lowercased()
        return lower.contains("placed on second") || lower.contains("placed on first") || lower.contains("placed on third")
    }

    /// Parses "<next batter name><placed runner name> placed on <base> (...)." into the placed
    /// runner's own name and starting base. `batterName` is only ever the *next* batter up, not
    /// the runner the notice is about, so it has to be stripped off the front first.
    private static func parsePlacedRunner(from play: WPBLPlay) -> (name: String, base: Int)? {
        guard play.narrative.hasPrefix(play.batterName) else { return nil }
        let afterBatter = play.narrative.dropFirst(play.batterName.count)
        guard let markerRange = afterBatter.range(of: " placed on ") else { return nil }
        let runnerName = afterBatter[afterBatter.startIndex..<markerRange.lowerBound]
            .trimmingCharacters(in: .whitespaces)
        guard !runnerName.isEmpty else { return nil }
        let rest = afterBatter[markerRange.upperBound...]
        if rest.hasPrefix("first") { return (runnerName, 1) }
        if rest.hasPrefix("second") { return (runnerName, 2) }
        if rest.hasPrefix("third") { return (runnerName, 3) }
        return nil
    }

    /// Builds the placed runner's own runner-only ("Z") cell, tracing her fate through the rest
    /// of the half-inning the same way a real baserunner's journey is traced — mirroring MLB's
    /// automatic extra-inning runner handling in ScorecardDataTransformer.
    private static func placedRunnerEvent(
        for play: WPBLPlay,
        runnerName: String,
        startingBase: Int,
        index: Int,
        in plays: [WPBLPlay],
        nameToId: [String: String],
        isPitchingChange: Bool,
        previousPitcherName: String?
    ) -> AtBatEvent {
        var state = RunnerBaseState()
        switch startingBase {
        case 1: state.reachFirst = true
        case 2: state.reachSecond = true
        case 3: state.reachThird = true
        default: break
        }
        traceRunnerJourney(startingAt: index, in: plays, runnerName: runnerName, state: &state)

        let baseLabel = startingBase == 2 ? "2nd" : startingBase == 3 ? "3rd" : "1st"
        let description = state.reachHome
            ? "\(runnerName) started the inning on \(baseLabel) base and scored."
            : "\(runnerName) started the inning on \(baseLabel) base."

        return AtBatEvent(
            atBatIndex: play.sequence,
            batterId: nameToId[runnerName] ?? runnerName,
            batterName: runnerName,
            pinchRunnerName: nil,
            pitcherId: nameToId[play.pitcherName] ?? play.pitcherName,
            pitcherName: play.pitcherName,
            previousPitcherName: previousPitcherName,
            inning: play.inning,
            isTop: play.half == "top",
            result: .runnerOnly,
            description: description,
            balls: 0,
            strikes: 0,
            outs: play.outs,
            rbi: 0,
            isRunnerOnly: true,
            isPitchingChange: isPitchingChange,
            bases: state.toBasesReached(includeLines: true),
            pitches: nil
        )
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
            guard next.inning == current.inning, next.half == current.half else {
                // The half-inning ended (third out recorded by someone else) with this runner
                // still on base — left on base, not an out. Without this check, the next play's
                // occupancy belongs to the *other* team's fresh, empty-bases state, which the
                // diff below would misread as this runner having vanished/been put out.
                return
            }
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
            } else if let explicitBase = explicitOutBase(for: runnerName, in: current.narrative) {
                state.recordOut(at: explicitBase)
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

    /// WPBL's narrative explicitly names the retired runner and the base they were thrown out at
    /// (e.g. "Ticara Geldenhuis out at second 2b to ss") on force-out/fielder's-choice plays where
    /// a preceding runner is retired advancing to a base *further* than their last confirmed
    /// position. The occupancy diff alone can't distinguish that from "still on their old base" —
    /// a retired runner simply vanishes from every later snapshot either way — so this is read
    /// from the narrative text instead. Verified against both fixture games: every "<name> out at
    /// <base>" occurrence names the base the runner was actually retired at, not their prior one.
    private static func explicitOutBase(for runnerName: String, in narrative: String) -> String? {
        guard let range = narrative.range(of: "\(runnerName) out at ") else { return nil }
        let rest = narrative[range.upperBound...]
        if rest.hasPrefix("first") { return "1b" }
        if rest.hasPrefix("second") { return "2b" }
        if rest.hasPrefix("third") { return "3b" }
        if rest.hasPrefix("home") { return "home" }
        return nil
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

    /// WPBL's raw description text is already clean for recognized pitch types ("Foul", "Ball",
    /// "Swinging strike"), with two exceptions confirmed against two full completed games'
    /// worth of data (not guessed):
    /// - type "unknown" comes back as the literal, unhelpful "Unknown pitch code" (WPBL's own
    ///   backend doesn't recognize the code either, e.g. "K" — shown as a plain generic pitch
    ///   instead of exposing that internal-sounding text).
    /// - code "P" is labeled "pitchout" by the API, but is *always* the last pitch of an at-bat
    ///   that ends in a batted-ball outcome (a hit or a ball-in-play out) — never once a real
    ///   pitchout across every occurrence in both games. WPBL's own type/description are simply
    ///   wrong for this code; it means the ball was put in play.
    /// outcome/description are set to the same value so PitchCell's "only show a subtitle when
    /// it differs" logic collapses to one clean line instead of duplicating it.
    private static func buildPitchEvents(_ events: [WPBLPitchEvent]?) -> [PitchEvent]? {
        guard let events, !events.isEmpty else { return nil }
        return events.enumerated().map { index, event in
            let label: String
            if event.code == "P" {
                label = "In Play"
            } else if event.type == "unknown" {
                label = "Pitch"
            } else {
                label = event.description
            }
            return PitchEvent(
                pitchNumber: index + 1,
                description: label,
                outcome: label,
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
