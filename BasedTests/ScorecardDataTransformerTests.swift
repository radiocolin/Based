import XCTest
@testable import Based

final class ScorecardDataTransformerTests: XCTestCase {

    // MARK: - Fixture-based regression: SEA @ MIL, 2026-08-18 (gamePk 823749)

    /// Top of the 5th: Brendan Donovan was still batting (0-1 count) when the Brewers challenged
    /// a tag play, the call was overturned, Victor Robles advanced to 3rd, and Brock Rodden was
    /// caught stealing 2nd for the inning's 3rd out — ending the half-inning with Donovan's own
    /// plate appearance still unresolved. MLB's feed still tags that "Runner Out" play's
    /// `matchup.batter` as Donovan (atBatIndex 34, eventType "other_out"), so it used to render as
    /// his own scorecard cell: an unrelated description plus a misleading "RUN" result (truncated
    /// from "Runner Out" — see testUnmappedResultEventRendersAsPlaceholderNotTruncatedText below).
    func testMidAtBatReviewPlayIsExcludedFromTheNextBattersScorecardCell() throws {
        let playByPlay = try loadFixture("mlb_823749_playByPlay", as: PlayByPlayResponse.self)
        let boxscore = try loadFixture("mlb_823749_boxscore", as: BoxscoreResponse.self)

        let scorecard = ScorecardDataTransformer.transformToScorecardData(playByPlay: playByPlay, boxscore: boxscore)

        let inning5Away = try XCTUnwrap(scorecard.innings.first(where: { $0.num == 5 })).away
        XCTAssertEqual(inning5Away.map(\.batterName), ["Cole Young", "Cal Raleigh", "Victor Robles", "Brock Rodden"])
        XCTAssertFalse(inning5Away.contains(where: { $0.batterName == "Brendan Donovan" }))
        XCTAssertFalse(scorecard.timeline.contains(where: { $0.description.contains("Brewers challenged") }))
    }

    // MARK: - shouldIncludePlayInScorecard: unit-level mirror of the same bug

    func testOtherOutNotInvolvingTheBatterIsExcluded() {
        let donovan = Player(id: 680977, fullName: "Brendan Donovan", link: nil)
        let robles = Player(id: 645302, fullName: "Victor Robles", link: nil)
        let rodden = Player(id: 801126, fullName: "Brock Rodden", link: nil)
        let play = Play(
            result: PlayResult(
                type: "atBat",
                event: "Runner Out",
                eventType: "other_out",
                description: "Brewers challenged (tag play), call on the field was overturned: Victor Robles out at . Victor Robles to 3rd. Brock Rodden caught stealing 2nd base, catcher William Contreras to shortstop Joey Ortiz.",
                rbi: 0, awayScore: 0, homeScore: 1
            ),
            about: PlayAbout(atBatIndex: 34, halfInning: "top", isTopInning: true, inning: 5, startTime: nil, endTime: nil, isComplete: true),
            count: PlayCount(balls: 0, strikes: 1, outs: 3),
            matchup: Matchup(batter: donovan, pitcher: nil, batterHotColdZones: nil),
            playEvents: nil,
            runners: [
                RunnerMovement(
                    movement: Movement(originBase: "2B", start: "2B", end: "3B", outBase: nil, isOut: false),
                    details: RunnerDetails(event: "Other Advance", eventType: "other_advance", runner: robles, isScoringEvent: false, rbi: false),
                    credits: nil
                ),
                RunnerMovement(
                    movement: Movement(originBase: "1B", start: "1B", end: nil, outBase: "2B", isOut: true),
                    details: RunnerDetails(event: "Caught Stealing 2B", eventType: "caught_stealing_2b", runner: rodden, isScoringEvent: false, rbi: false),
                    credits: nil
                )
            ]
        )

        XCTAssertFalse(ScorecardDataTransformer.shouldIncludePlayInScorecard(play, includeLive: true))
    }

    func testCaughtStealingNotInvolvingTheBatterIsStillExcluded() {
        // Pre-existing carve-out this bug's fix sits alongside — guards against a future edit
        // collapsing the caught_stealing/pickoff/other_out cases back into one over-eager check.
        let batter = Player(id: 1, fullName: "Batter Up", link: nil)
        let runner = Player(id: 2, fullName: "Some Runner", link: nil)
        let play = Play(
            result: PlayResult(type: "atBat", event: "Caught Stealing 2B", eventType: "caught_stealing", description: "Some Runner caught stealing 2nd base.", rbi: 0, awayScore: 0, homeScore: 0),
            about: PlayAbout(atBatIndex: 10, halfInning: "top", isTopInning: true, inning: 3, startTime: nil, endTime: nil, isComplete: true),
            count: nil,
            matchup: Matchup(batter: batter, pitcher: nil, batterHotColdZones: nil),
            playEvents: nil,
            runners: [
                RunnerMovement(
                    movement: Movement(originBase: "1B", start: "1B", end: nil, outBase: "2B", isOut: true),
                    details: RunnerDetails(event: "Caught Stealing 2B", eventType: "caught_stealing_2b", runner: runner, isScoringEvent: false, rbi: false),
                    credits: nil
                )
            ]
        )

        XCTAssertFalse(ScorecardDataTransformer.shouldIncludePlayInScorecard(play, includeLive: true))
    }

    func testCaughtStealingWhereTheBatterIsTheRunnerRetiredIsStillIncluded() {
        // Positive control: the exclusion only kicks in when the tagged batter wasn't actually
        // the runner put out, so a real "batter caught stealing" plate-appearance result must
        // still render.
        let batter = Player(id: 1, fullName: "Test Batter", link: nil)
        let play = Play(
            result: PlayResult(type: "atBat", event: "Caught Stealing 2B", eventType: "caught_stealing", description: "Test Batter caught stealing 2nd base.", rbi: 0, awayScore: 0, homeScore: 0),
            about: PlayAbout(atBatIndex: 11, halfInning: "top", isTopInning: true, inning: 3, startTime: nil, endTime: nil, isComplete: true),
            count: nil,
            matchup: Matchup(batter: batter, pitcher: nil, batterHotColdZones: nil),
            playEvents: nil,
            runners: [
                RunnerMovement(
                    movement: Movement(originBase: "1B", start: "1B", end: nil, outBase: "2B", isOut: true),
                    details: RunnerDetails(event: "Caught Stealing 2B", eventType: "caught_stealing_2b", runner: batter, isScoringEvent: false, rbi: false),
                    credits: nil
                )
            ]
        )

        XCTAssertTrue(ScorecardDataTransformer.shouldIncludePlayInScorecard(play, includeLive: true))
    }

    // MARK: - scorecardNotation fallback

    func testUnmappedResultEventRendersAsPlaceholderNotTruncatedText() {
        let play = Play(
            result: PlayResult(type: "atBat", event: "Runner Out", eventType: "other_out", description: "", rbi: 0, awayScore: 0, homeScore: 0),
            about: PlayAbout(atBatIndex: 0, halfInning: "top", isTopInning: true, inning: 1, startTime: nil, endTime: nil, isComplete: true),
            count: nil, matchup: nil, playEvents: nil, runners: nil
        )

        // Truncating "Runner Out" to its first 3 letters used to produce "RUN" — indistinguishable
        // from real scorecard notation. Anything genuinely unmapped must render as a placeholder
        // that can't be mistaken for a real abbreviation instead.
        XCTAssertEqual(ScorecardDataTransformer.scorecardNotation(for: play), .other(text: ScorecardDataTransformer.unmappedResultText))
    }

    func testMappedEventTypeStillReturnsRealNotation() {
        let play = Play(
            result: PlayResult(type: "atBat", event: "Double", eventType: "double", description: "", rbi: 0, awayScore: 0, homeScore: 0),
            about: PlayAbout(atBatIndex: 0, halfInning: "top", isTopInning: true, inning: 1, startTime: nil, endTime: nil, isComplete: true),
            count: nil, matchup: nil, playEvents: nil, runners: nil
        )

        XCTAssertEqual(ScorecardDataTransformer.scorecardNotation(for: play), .double)
    }

    /// A dash in the box doesn't explain itself the way "K" or "1B" does, so a play that hits the
    /// unmapped-result fallback should also get a plain-language note appended to its description —
    /// something a person using the app (not someone debugging it) can make sense of.
    func testUnmappedResultAppendsAPlainLanguageNoteToTheDescription() throws {
        let batter = Player(id: 1, fullName: "Test Batter", link: nil)
        let play = Play(
            result: PlayResult(type: "atBat", event: "Runner Out", eventType: "other_out", description: "Test Batter's play couldn't be resolved.", rbi: 0, awayScore: 0, homeScore: 0),
            about: PlayAbout(atBatIndex: 0, halfInning: "top", isTopInning: true, inning: 1, startTime: nil, endTime: nil, isComplete: true),
            count: nil,
            matchup: Matchup(batter: batter, pitcher: nil, batterHotColdZones: nil),
            playEvents: nil,
            runners: [
                RunnerMovement(
                    movement: Movement(originBase: "1B", start: "1B", end: nil, outBase: "2B", isOut: true),
                    details: RunnerDetails(event: "Runner Out", eventType: "other_out", runner: batter, isScoringEvent: false, rbi: false),
                    credits: nil
                )
            ]
        )
        let playByPlay = PlayByPlayResponse(allPlays: [play], currentPlay: nil)
        let boxscore = BoxscoreResponse(teams: nil, officials: nil, info: nil)

        let scorecard = ScorecardDataTransformer.transformToScorecardData(playByPlay: playByPlay, boxscore: boxscore)

        let event = try XCTUnwrap(scorecard.timeline.first)
        XCTAssertEqual(event.result, .other(text: ScorecardDataTransformer.unmappedResultText))
        XCTAssertEqual(
            event.description,
            "Test Batter's play couldn't be resolved. We couldn't match this play to one of our scorecard symbols, so the box just shows “\(ScorecardDataTransformer.unmappedResultText)”."
        )
    }

    // MARK: - Fixture loading

    private func loadFixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"), "Missing fixture \(name).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
}
