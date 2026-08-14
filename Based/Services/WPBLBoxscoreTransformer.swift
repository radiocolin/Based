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
        let substitutions = dedupeCanceledSubstitutions(parseSubstitutions(from: allPlays))
        let positionChanges = parsePositionChanges(from: allPlays)

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
            lineups: Lineups(
                home: buildLineup(team: homeTeam, substitutions: substitutions, positionChanges: positionChanges),
                away: buildLineup(team: awayTeam, substitutions: substitutions, positionChanges: positionChanges)
            ),
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

    /// Batting-order spot WPBL assigns the pitcher alongside the 9 fielding/DH spots — she never
    /// actually bats under WPBL's DH rule, so relief pitchers (who do get their own `team.players`
    /// entry with a "10" spot once they take the mound, purely as bookkeeping for buildPitchers)
    /// must never turn into extra rows here; only the starting pitcher's own row is kept, exactly
    /// as before this function started tracking real substitutions.
    private static let pitcherLineupSlot = 10

    private static func buildLineup(
        team: WPBLBoxscoreTeam?,
        substitutions: [WPBLSubstitution],
        positionChanges: [WPBLPositionChange]
    ) -> [ScorecardBatter] {
        guard let team else { return [] }
        let playersByName = Dictionary(uniqueKeysWithValues: (team.players ?? []).map { ($0.name, $0) })
        // team.players always lists the full roster (spot "0"/no stats for anyone who never
        // entered), so this doubles as "does this name belong to this team" for routing
        // substitution notices to the right side without relying on the play's team_id (which
        // is tagged with whichever team is *batting* at that moment, not the team the
        // substitution notice is actually about).
        let knownNames = Set(playersByName.keys).union((team.starters ?? []).map(\.name))

        func abbreviation(for name: String) -> String {
            let components = name.components(separatedBy: " ")
            var abbreviation = components.last ?? name
            let suffixes = ["Jr", "Sr", "II", "III", "IV", "Jr.", "Sr."]
            if suffixes.contains(abbreviation) && components.count >= 2 {
                abbreviation = "\(components[components.count - 2]) \(abbreviation)"
            }
            return abbreviation
        }

        func makeBatter(name: String, position: String, slot: Int, entryInning: Int?, exitInning: Int?) -> ScorecardBatter {
            ScorecardBatter(
                id: playersByName[name]?.id ?? name,
                fullName: name,
                abbreviation: abbreviation(for: name),
                position: position,
                jerseyNumber: playersByName[name]?.uniform,
                battingOrderSlot: slot,
                inningEntered: entryInning,
                inningExited: exitInning
            )
        }

        typealias Row = (batter: ScorecardBatter, slot: Int, entryInning: Int, exitInning: Int?, originalIndex: Int)
        var rows: [Row] = []
        var slotForName: [String: Int] = [:]

        for (index, starter) in (team.starters ?? []).enumerated() {
            let slot = Int(starter.spot) ?? index
            slotForName[starter.name] = slot
            rows.append((makeBatter(name: starter.name, position: starter.position, slot: slot, entryInning: nil, exitInning: nil), slot, 0, nil, index))
        }

        var nextIndex = rows.count
        for sub in substitutions where knownNames.contains(sub.outgoingName) {
            guard let slot = slotForName[sub.outgoingName], slot != pitcherLineupSlot else { continue }
            // The replaced player must have a currently-open row to hand the slot off from.
            // WPBL's play log occasionally restates a substitution for someone who has already
            // left the game (observed in a real completed game — a second "X for Y" notice for a
            // Y already substituted out earlier); without a real open row, the notice doesn't
            // correspond to an actual lineup change, so it's skipped rather than fabricating a
            // second, overlapping row for the incoming player.
            guard let outgoingIndex = rows.lastIndex(where: { $0.batter.fullName == sub.outgoingName && $0.exitInning == nil }) else { continue }
            let old = rows[outgoingIndex].batter
            rows[outgoingIndex].batter = makeBatter(name: old.fullName, position: old.position, slot: old.battingOrderSlot ?? slot, entryInning: old.inningEntered, exitInning: sub.inning)
            rows[outgoingIndex].exitInning = sub.inning

            slotForName[sub.incomingName] = slot
            rows.append((makeBatter(name: sub.incomingName, position: sub.position, slot: slot, entryInning: sub.inning, exitInning: nil), slot, sub.inning, nil, nextIndex))
            nextIndex += 1
        }

        // Bare "X to <pos>." notices (no "for Y") are a player already in the lineup — a
        // starter or an already-substituted-in player — changing position rather than a new
        // entrant. They only relabel an existing row's position; they never create a row or
        // touch entry/exit innings.
        for change in positionChanges where knownNames.contains(change.name) {
            guard let slot = slotForName[change.name], slot != pitcherLineupSlot else { continue }
            if let idx = rows.lastIndex(where: { $0.batter.fullName == change.name && $0.exitInning == nil }) {
                let old = rows[idx].batter
                rows[idx].batter = makeBatter(name: old.fullName, position: change.position, slot: old.battingOrderSlot ?? slot, entryInning: old.inningEntered, exitInning: old.inningExited)
            }
        }

        // A player can legitimately leave and later re-enter this same team's lineup (e.g. a
        // lifted DH returning later as a fielder) — but the shared ScorecardData model (mirroring
        // MLB's own buildLineup, which also assumes one row per unique batter id) has
        // calculatePlayerStats and the scorecard grid both keying strictly by batter id; two rows
        // for the same id would double-count her stats in the totals row. Multiple stints are
        // therefore collapsed into a single row spanning her first entry to her last exit,
        // anchored at the slot she first appeared in — `rows` is already in chronological order
        // (starters, then substitutions in narrative order), so simply overwriting on each repeat
        // keeps the most recent position/exit while the first occurrence's slot/entry sticks.
        var mergedByName: [String: Row] = [:]
        var order: [String] = []
        for row in rows {
            if let existing = mergedByName[row.batter.fullName] {
                mergedByName[row.batter.fullName] = (
                    makeBatter(name: row.batter.fullName, position: row.batter.position, slot: existing.slot, entryInning: existing.batter.inningEntered, exitInning: row.exitInning),
                    existing.slot, existing.entryInning, row.exitInning, existing.originalIndex
                )
            } else {
                mergedByName[row.batter.fullName] = row
                order.append(row.batter.fullName)
            }
        }

        return order
            .compactMap { mergedByName[$0] }
            .sorted { lhs, rhs in
                if lhs.slot != rhs.slot { return lhs.slot < rhs.slot }
                if lhs.entryInning != rhs.entryInning { return lhs.entryInning < rhs.entryInning }
                return lhs.originalIndex < rhs.originalIndex
            }
            .map(\.batter)
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

    // MARK: - Substitutions

    /// A lineup change that moves a real batting-order spot from one player to another —
    /// pinch hit, pinch run, or a defensive/pitching swap. Not every WPBL team plays with a DH:
    /// some games assign the pitcher her own real 1-9 batting spot (she bats), others give the
    /// pitcher a separate non-batting spot "10" alongside a DH occupying a real spot. Rather than
    /// guess which convention a given game uses from the position label alone, every "<Name> to
    /// <pos> for <Name>." notice (pitching changes included) is parsed here, and buildLineup
    /// decides whether it affects the batting order by checking the *replaced* player's actual
    /// assigned slot — skipping only spot "10", the non-batting bookkeeping slot.
    private struct WPBLSubstitution {
        let incomingName: String
        let outgoingName: String
        let inning: Int
        let position: String
    }

    private struct WPBLPositionChange {
        let name: String
        let position: String
    }

    private static let pinchHitPattern = /^(.+) pinch hit for (.+)\.$/
    private static let pinchRanPattern = /^(.+) pinch ran for (.+)\.$/
    private static let positionForPattern = /^(.+) to ([a-z0-9]+) for (.+)\.$/
    private static let positionOnlyPattern = /^(.+) to ([a-z0-9]+)\.$/

    // The lowercase position abbreviations WPBL's narrative uses, verified against real
    // completed games. "p" is included deliberately — see WPBLSubstitution's doc comment.
    private static let battingPositions: Set<String> = ["1b", "2b", "3b", "ss", "lf", "cf", "rf", "c", "dh", "p"]

    private static func parsePinchHit(_ narrative: String) -> (incoming: String, outgoing: String)? {
        guard let match = narrative.wholeMatch(of: pinchHitPattern) else { return nil }
        return (String(match.1), String(match.2))
    }

    private static func parsePinchRun(_ narrative: String) -> (incoming: String, outgoing: String)? {
        guard let match = narrative.wholeMatch(of: pinchRanPattern) else { return nil }
        return (String(match.1), String(match.2))
    }

    private static func parsePositionSwap(_ narrative: String) -> (incoming: String, position: String, outgoing: String)? {
        guard let match = narrative.wholeMatch(of: positionForPattern), battingPositions.contains(String(match.2)) else { return nil }
        return (String(match.1), String(match.2), String(match.3))
    }

    private static func parsePositionOnly(_ narrative: String) -> (name: String, position: String)? {
        guard let match = narrative.wholeMatch(of: positionOnlyPattern), battingPositions.contains(String(match.2)) else { return nil }
        return (String(match.1), String(match.2))
    }

    private static func parseSubstitutions(from plays: [WPBLPlay]) -> [WPBLSubstitution] {
        plays.compactMap { play in
            if let hit = parsePinchHit(play.narrative) {
                return WPBLSubstitution(incomingName: hit.incoming, outgoingName: hit.outgoing, inning: play.inning, position: "ph")
            }
            if let ran = parsePinchRun(play.narrative) {
                return WPBLSubstitution(incomingName: ran.incoming, outgoingName: ran.outgoing, inning: play.inning, position: "pr")
            }
            if let swap = parsePositionSwap(play.narrative) {
                return WPBLSubstitution(incomingName: swap.incoming, outgoingName: swap.outgoing, inning: play.inning, position: swap.position)
            }
            return nil
        }
    }

    /// WPBL's play log occasionally carries a substitution notice that gets corrected/walked back
    /// moments later — observed in a real completed game as three consecutive notices in the same
    /// inning: "A pinch hit for B.", immediately followed by "B pinch hit for A." (the exact
    /// reverse), then "A pinch hit for C." (the real, final change). Neither half of an adjacent
    /// exact-reversal pair reflects what actually happened, so both are dropped; the entry-order
    /// insight this relies on — that a corrected notice is walked back by its very next neighbor,
    /// not by a distant later one — comes from that same observed case, not from a general API
    /// guarantee, so this deliberately only cancels *adjacent* reversals.
    private static func dedupeCanceledSubstitutions(_ subs: [WPBLSubstitution]) -> [WPBLSubstitution] {
        var result: [WPBLSubstitution] = []
        var i = 0
        while i < subs.count {
            if i + 1 < subs.count,
               subs[i].incomingName == subs[i + 1].outgoingName,
               subs[i].outgoingName == subs[i + 1].incomingName {
                i += 2
                continue
            }
            result.append(subs[i])
            i += 1
        }
        return result
    }

    private static func parsePositionChanges(from plays: [WPBLPlay]) -> [WPBLPositionChange] {
        plays.compactMap { play in
            guard parsePinchHit(play.narrative) == nil,
                  parsePinchRun(play.narrative) == nil,
                  parsePositionSwap(play.narrative) == nil,
                  let change = parsePositionOnly(play.narrative) else { return nil }
            return WPBLPositionChange(name: change.name, position: change.position)
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
                    pinchRunnerName: state.pinchRunnerName,
                    pitcherId: pitcherId,
                    pitcherName: play.pitcherName,
                    previousPitcherName: previousPitcherName,
                    inning: play.inning,
                    isTop: play.half == "top",
                    result: scorecardResult(for: play),
                    description: enrichedDescription(baseDescription: play.narrative, pinchRunnerName: state.pinchRunnerName),
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
        let baseDescription = state.reachHome
            ? "\(runnerName) started the inning on \(baseLabel) base and scored."
            : "\(runnerName) started the inning on \(baseLabel) base."
        let description = enrichedDescription(baseDescription: baseDescription, pinchRunnerName: state.pinchRunnerName)

        return AtBatEvent(
            atBatIndex: play.sequence,
            batterId: nameToId[runnerName] ?? runnerName,
            batterName: runnerName,
            pinchRunnerName: state.pinchRunnerName,
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
        var trackedName = runnerName
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

            // A pinch runner replaces this exact runner mid-inning — the substitution notice's
            // own base snapshot still shows the outgoing name, but every later snapshot (the
            // "next" one included) already reports the incoming name occupying the same base.
            // Without switching the tracked name here, the diff below sees the old name vanish
            // and misreads it as a pickoff/tag-out rather than a substitution.
            if let pinchRun = parsePinchRun(current.narrative), pinchRun.outgoing == trackedName {
                if state.pinchRunnerName == nil { state.pinchRunnerName = pinchRun.incoming }
                if let base = state.currentBase, base < 4 {
                    state.annotations.append(BaseAnnotation(kind: .pinchRunner, base: base, label: "PR"))
                }
                trackedName = pinchRun.incoming
            }

            let nextBases = (first: next.firstBase, second: next.secondBase, third: next.thirdBase)

            if nextBases.third == trackedName {
                state.advanceRunner(to: "3b")
            } else if nextBases.second == trackedName {
                state.advanceRunner(to: "2b")
            } else if nextBases.first == trackedName {
                state.advanceRunner(to: "1b")
            } else if scoredNames(in: current.narrative).contains(trackedName) {
                state.advanceRunner(to: "score")
                return
            } else if let explicitBase = explicitOutBase(for: trackedName, in: current.narrative) {
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

    private static func enrichedDescription(baseDescription: String, pinchRunnerName: String?) -> String {
        guard let pinchRunnerName, !pinchRunnerName.isEmpty else { return baseDescription }
        let note = "Pinch runner: \(pinchRunnerName)."
        return baseDescription.isEmpty ? note : "\(baseDescription) \(note)"
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
            // WPBL tags plenty of routine batted-ball outs with the generic event_type "out"
            // rather than "groundout"/"flyout"/etc. — the narrative text is the only place the
            // batted-ball type and fielding credits show up, so disambiguate from it the same
            // way ScorecardDataTransformer does for MLB's equivalent "field_out" catch-all.
            let lower = play.narrative.lowercased()
            if lower.contains("triple play") { return .triplePlay }
            if lower.contains("double play") { return .doublePlay(sequence: fieldingPosition(from: play.narrative) ?? "") }
            if lower.contains("force") { return .forceOut(sequence: fieldingPosition(from: play.narrative) ?? "") }
            if lower.contains("fly") { return .flyout(position: fieldingPosition(from: play.narrative) ?? "") }
            if lower.contains("line") { return .lineout(position: fieldingPosition(from: play.narrative) ?? "") }
            if lower.contains("pop") { return .popout(position: fieldingPosition(from: play.narrative) ?? "") }
            if lower.contains("foul") { return .flyout(position: fieldingPosition(from: play.narrative) ?? "") }
            if lower.contains("ground") { return .groundout(sequence: fieldingPosition(from: play.narrative) ?? "") }
            // No batted-ball keyword at all (e.g. "out at first 1b to p") — the fielding
            // sequence parsed from the narrative is still the useful signal, so render it the
            // same way a groundout's fielder sequence would be.
            if let sequence = fieldingPosition(from: play.narrative) { return .groundout(sequence: sequence) }
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
