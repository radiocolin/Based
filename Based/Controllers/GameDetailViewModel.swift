import Foundation
import UIKit

class GameDetailViewModel {

    // State
    private(set) var gameID: String
    private(set) var awayTeamID: String
    private(set) var homeTeamID: String
    private(set) var initialAwayTeamName: String
    private(set) var initialHomeTeamName: String
    private(set) var currentSnapshot: LiveGameSnapshot?
    private(set) var currentLinescore: Linescore?
    private(set) var currentScorecard: ScorecardData?
    private(set) var currentGameData: GameData?
    private(set) var currentUmpires: [ScorecardUmpire] = []
    private(set) var currentGameInfo: [GameInfoItem] = []
    var currentPitchers: [ScorecardPitcher] = []
    private(set) var isGameLive: Bool

    var isTimelineMode: Bool = UserDefaults.standard.bool(forKey: "preferTimelineMode") {
        didSet {
            UserDefaults.standard.set(isTimelineMode, forKey: "preferTimelineMode")
        }
    }

    var lastActiveAtBatKey: String?

    // Callbacks to ViewController
    var onSnapshotUpdate: ((LiveGameSnapshot, Bool) -> Void)?
    var onScorecardUpdate: ((ScorecardData) -> Void)?
    var onStatusUpdate: ((String) -> Void)?

    private let dataSource: GameDetailDataSource

    init(gameID: String, awayTeamID: String, homeTeamID: String, awayTeamName: String, homeTeamName: String, isInitiallyLive: Bool, dataSource: GameDetailDataSource) {
        self.gameID = gameID
        self.awayTeamID = awayTeamID
        self.homeTeamID = homeTeamID
        self.initialAwayTeamName = awayTeamName
        self.initialHomeTeamName = homeTeamName
        self.isGameLive = isInitiallyLive
        self.dataSource = dataSource
    }

    func startPolling() {
        dataSource.start(
            onSnapshot: { [weak self] snapshot in self?.handleSnapshot(snapshot) },
            onStatus: { [weak self] status in self?.onStatusUpdate?(status) }
        )
    }

    func stopPolling() {
        dataSource.stop()
    }

    private func handleSnapshot(_ snapshot: LiveGameSnapshot) {
        currentSnapshot = snapshot
        currentLinescore = snapshot.linescore
        currentGameData = snapshot.gameData

        let wasLive = isGameLive
        isGameLive = snapshot.isGameLive

        if let scorecard = snapshot.scorecard {
            if scorecard != currentScorecard {
                currentScorecard = scorecard
                updateInternalState(with: scorecard)
                onScorecardUpdate?(scorecard)
            }
        }

        onSnapshotUpdate?(snapshot, wasLive)
    }

    private func updateInternalState(with scorecard: ScorecardData) {
        currentUmpires = scorecard.umpires
        currentGameInfo = scorecard.gameInfo
        currentPitchers = []
    }

    func pitchers(forIsHome home: Bool) -> [ScorecardPitcher] {
        guard let scorecard = currentScorecard else { return [] }
        return home ? scorecard.pitchers.home : scorecard.pitchers.away
    }
}
