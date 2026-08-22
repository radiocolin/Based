import XCTest
@testable import Based

final class ScorecardLayoutEngineTests: XCTestCase {

    // MARK: - Compact mode: extra-inning placed ("zombie") runner shouldn't spawn a stray column
    //
    // MLB's automatic extra-inning runner is usually the same batter who made the last out of the
    // previous half-inning. The transformer inserts a synthetic isRunnerOnly AtBatEvent for that
    // batter at the start of the new half-inning. In compact mode, columns are indexed by each
    // batter's running plate-appearance count (not by real inning number), so if that synthetic
    // event advanced the counter like a real PA, it claimed a column no other lineup slot had
    // reached yet — producing an orphan column and permanently shifting that batter's later
    // real at-bats out of alignment with the rest of the lineup.
    //
    // The fix folds the placed-runner event into the batter's most recent real at-bat instead,
    // as a `.placedRunner` annotation, rather than giving it its own compact column.

    private func makeBatter(id: String, slot: Int) -> ScorecardBatter {
        ScorecardBatter(
            id: id, fullName: "Player \(id)", abbreviation: "P\(id)", position: "OF",
            jerseyNumber: nil, battingOrderSlot: slot, inningEntered: nil, inningExited: nil
        )
    }

    private func makeEvent(batterId: String, inning: Int, isRunnerOnly: Bool, result: ScorecardResult = .flyout(position: "8")) -> AtBatEvent {
        AtBatEvent(
            atBatIndex: nil, batterId: batterId, batterName: batterId, pinchRunnerName: nil,
            pitcherId: "p", pitcherName: "Pitcher", previousPitcherName: nil,
            inning: inning, isTop: true, result: isRunnerOnly ? .runnerOnly : result,
            description: "", balls: 0, strikes: 0, outs: 0, rbi: 0,
            isRunnerOnly: isRunnerOnly, isPitchingChange: false,
            bases: BasesReached(
                first: false, second: isRunnerOnly, third: false, home: false,
                lineToFirst: nil, lineToSecond: nil, lineToThird: nil, lineToHome: nil,
                outAtFirst: nil, outAtSecond: nil, outAtThird: nil, outAtHome: nil, annotations: nil
            ),
            pitches: nil
        )
    }

    func testPlacedRunnerDoesNotClaimItsOwnCompactColumn() {
        let batterA = makeBatter(id: "A", slot: 1) // made last out of inning 9, placed as runner in inning 10
        let batterB = makeBatter(id: "B", slot: 2) // bats for real in inning 10

        // Innings 1-9: both batters get one real PA per inning, staying in lockstep.
        var homeEvents: [ScorecardInning] = (1...9).map { inning in
            ScorecardInning(
                num: inning, ordinal: "\(inning)",
                home: [makeEvent(batterId: "A", inning: inning, isRunnerOnly: false),
                       makeEvent(batterId: "B", inning: inning, isRunnerOnly: false)],
                away: [], homeRuns: 0, awayRuns: 0, homeScoringPlayerIds: [], awayScoringPlayerIds: []
            )
        }

        // Inning 10: A is placed as the automatic runner (no real PA), B bats for real.
        homeEvents.append(
            ScorecardInning(
                num: 10, ordinal: "10",
                home: [makeEvent(batterId: "A", inning: 10, isRunnerOnly: true),
                       makeEvent(batterId: "B", inning: 10, isRunnerOnly: false)],
                away: [], homeRuns: 0, awayRuns: 0, homeScoringPlayerIds: [], awayScoringPlayerIds: []
            )
        )

        let data = ScorecardData(
            teams: ScorecardTeams(home: Team(id: 1, name: "Home", link: nil), away: Team(id: 2, name: "Away", link: nil)),
            lineups: Lineups(home: [batterA, batterB], away: []),
            pitchers: ScorecardPitchers(home: [], away: []),
            innings: homeEvents,
            scheduledInnings: 9,
            timeline: [],
            liveCurrentAtBat: nil,
            advisories: [],
            umpires: [],
            gameInfo: [],
            gameDate: nil,
            currentInning: nil,
            isTopInning: nil,
            currentBatterId: nil
        )

        let engine = ScorecardLayoutEngine()
        let eventsBySlot = engine.compactPlateAppearancesBySlot(data: data, lineup: data.lineups.home, isHomeTeam: true)

        // A has 9 real PAs (innings 1-9); the placed-runner event in inning 10 shouldn't add a
        // 10th column of its own. B has a real PA in every inning through 10, so gets 10 columns.
        XCTAssertEqual(eventsBySlot[1]?.count, 9, "Placed-runner event should not add an extra column for batter A")
        XCTAssertEqual(eventsBySlot[2]?.count, 10)

        // A's last real column (their inning-9 at-bat) should carry a placedRunner annotation
        // marking them on base to start inning 10, instead of the event itself claiming a column.
        let lastRealIndex = 8
        let annotatedEvent = eventsBySlot[1]?[lastRealIndex]
        XCTAssertEqual(annotatedEvent?.isRunnerOnly, false)
        XCTAssertEqual(annotatedEvent?.inning, 9)
        XCTAssertEqual(annotatedEvent?.bases.annotations?.first?.kind, .placedRunner)

        let layout = engine.computeCompactColumnLayout(data: data, isHomeTeam: true)
        XCTAssertEqual(layout.columns.count, 10, "No orphan column should be created for the placed runner")
    }
}
