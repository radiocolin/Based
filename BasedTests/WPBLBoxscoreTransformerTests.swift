import XCTest
@testable import Based

final class WPBLBoxscoreTransformerTests: XCTestCase {

    // MARK: - explicitOutBase
    // WPBL.md: the narrative explicitly names the retired runner and the base they were thrown
    // out at (e.g. "Ticara Geldenhuis out at second 2b to ss") — verified against two fixture
    // games, every "<name> out at <base>" occurrence names the base actually retired at.

    func testExplicitOutBaseParsesEachBaseWord() {
        XCTAssertEqual(
            WPBLBoxscoreTransformer.explicitOutBase(for: "Ticara Geldenhuis", in: "Ticara Geldenhuis out at second 2b to ss"),
            "2b"
        )
        XCTAssertEqual(
            WPBLBoxscoreTransformer.explicitOutBase(for: "Runner Name", in: "Runner Name out at first 1b to p"),
            "1b"
        )
        XCTAssertEqual(
            WPBLBoxscoreTransformer.explicitOutBase(for: "Runner Name", in: "Runner Name out at third 5-4-5"),
            "3b"
        )
        XCTAssertEqual(
            WPBLBoxscoreTransformer.explicitOutBase(for: "Runner Name", in: "Runner Name out at home 2 to 5"),
            "home"
        )
    }

    func testExplicitOutBaseReturnsNilWhenTheNarrativeIsAboutSomeoneElse() {
        XCTAssertNil(WPBLBoxscoreTransformer.explicitOutBase(for: "Someone Else", in: "Ticara Geldenhuis out at second 2b to ss"))
    }

    // MARK: - narrativeIndicatesReachedOnError
    // WPBL tags "reached first on an error" with the same generic event_type ("unknown") it uses
    // for pure substitution notices, so this is detected from narrative text. A fielder's-choice
    // play can *also* mention "on an error" (an extra base taken on a throwing error) without the
    // batter's own reach being the error — FC notation takes priority in that case.

    func testReachedOnErrorIsDetected() {
        XCTAssertTrue(WPBLBoxscoreTransformer.narrativeIndicatesReachedOnError("Runner Name reached first on an error by third baseman."))
    }

    func testFieldersChoiceTakesPriorityOverReachedOnErrorWording() {
        XCTAssertFalse(
            WPBLBoxscoreTransformer.narrativeIndicatesReachedOnError(
                "Runner Name reached on a fielder's choice, advances to second on an error."
            )
        )
    }

    // MARK: - scorecardResult fallback

    func testUnmappedEventTypeRendersAsPlaceholderNotTruncatedText() {
        let play = makePlay(narrative: "Batter Name did something WPBL hasn't documented yet.", eventType: "some_new_event_wpbl_hasnt_documented_yet")

        // The MLB-side equivalent of this fallback used to truncate the raw string to 3 letters
        // and could coincidentally spell real notation (see ScorecardDataTransformerTests). WPBL's
        // fallback shares the same risk, so it gets the same dash placeholder instead.
        XCTAssertEqual(WPBLBoxscoreTransformer.scorecardResult(for: play), .other(text: WPBLBoxscoreTransformer.unmappedResultText))
    }

    func testMappedEventTypeStillReturnsRealNotation() {
        let play = makePlay(narrative: "Batter Name doubles.", eventType: "double")
        XCTAssertEqual(WPBLBoxscoreTransformer.scorecardResult(for: play), .double)
    }

    /// A dash in the box doesn't explain itself the way "K" or "1B" does, so a play that hits the
    /// unmapped-result fallback should also get a plain-language note appended to its description —
    /// something a person using the app (not someone debugging it) can make sense of.
    func testUnmappedResultAppendsAPlainLanguageNoteToTheDescription() throws {
        let play = makePlay(
            narrative: "Test Batter did something new that WPBL hasn't documented yet.",
            eventType: "some_new_event_wpbl_hasnt_documented_yet",
            batterName: "Test Batter"
        )
        let boxscore = WPBLBoxscore(
            gameId: "g1",
            provider: "presto",
            gameStatus: "Final",
            sourceUpdatedAt: "",
            fetchedAt: "",
            status: WPBLLiveStatus(
                complete: true, inning: 1, half: "top", battingTeamId: "t1",
                outs: 0, balls: 0, strikes: 0, batterName: "", pitcherName: "",
                firstBase: "", secondBase: "", thirdBase: "",
                basesOccupied: nil, basesLoaded: false, awayRuns: 0, homeRuns: 0
            ),
            teams: [],
            plays: [play]
        )

        let scorecard = WPBLBoxscoreTransformer.transformToScorecardData(boxscore)

        let event = try XCTUnwrap(scorecard.timeline.first)
        XCTAssertEqual(event.result, .other(text: WPBLBoxscoreTransformer.unmappedResultText))
        XCTAssertEqual(
            event.description,
            "Test Batter did something new that WPBL hasn't documented yet. We couldn't match this play to one of our scorecard symbols, so the box just shows “\(WPBLBoxscoreTransformer.unmappedResultText)”."
        )
    }

    // MARK: - Helpers

    private func makePlay(narrative: String, eventType: String, batterName: String = "Batter Name") -> WPBLPlay {
        WPBLPlay(
            inning: 1,
            half: "top",
            teamId: "t1",
            sequence: 1,
            batterName: batterName,
            pitcherName: "Pitcher Name",
            outs: 0,
            firstBase: "",
            secondBase: "",
            thirdBase: "",
            basesOccupied: nil,
            basesLoaded: false,
            narrative: narrative,
            eventType: eventType,
            isHit: false,
            isScoringPlay: false,
            runsScored: 0,
            pitchSequence: "",
            pitchEvents: nil,
            fouls: 0,
            balls: 0,
            strikes: 0
        )
    }
}
