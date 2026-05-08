import Foundation
import UIKit

class GameDetailViewModel: GameUpdateDelegate {
    
    // State
    private(set) var gamePk: Int
    private(set) var currentGames: [ScheduleGame]
    private(set) var currentSnapshot: LiveGameSnapshot?
    private(set) var currentLinescore: Linescore?
    private(set) var currentScorecard: ScorecardData?
    private(set) var currentGameData: GameData?
    private(set) var currentUmpires: [ScorecardUmpire] = []
    private(set) var currentGameInfo: [GameInfoItem] = []
    private(set) var currentPitchers: [ScorecardPitcher] = []
    private(set) var isGameLive = false
    
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
    
    private static let scheduleDateFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let scheduleDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init(gamePk: Int, games: [ScheduleGame]) {
        self.gamePk = gamePk
        self.currentGames = games
        
        // Derive initial live state from schedule data
        let game = games.first(where: { $0.gamePk == gamePk })
        let state = game?.status.detailedState.lowercased() ?? ""
        let code = game?.status.statusCode?.lowercased() ?? ""
        let isFinal = state == "final" || state == "game over" || state == "completed early" || code == "f" || code == "o"
        let isScheduled = state == "scheduled" || state == "pre-game" || state == "postponed" || code == "s" || code == "p"
        self.isGameLive = !isFinal && !isScheduled && !state.isEmpty
    }
    
    func startPolling() {
        let scheduledStartTime = currentGames
            .first(where: { $0.gamePk == gamePk })
            .flatMap { Self.scheduleStartDate(from: $0.gameDate) }
        GameService.shared.delegate = self
        GameService.shared.startPolling(gamePk: gamePk, scheduledStartTime: scheduledStartTime)
    }
    
    func stopPolling() {
        GameService.shared.stopPolling()
    }
    
    private static func scheduleStartDate(from value: String) -> Date? {
        if let date = scheduleDateFormatterWithFractional.date(from: value) {
            return date
        }
        return scheduleDateFormatter.date(from: value)
    }
    
    // MARK: - GameUpdateDelegate
    
    func didUpdateSnapshot(_ snapshot: LiveGameSnapshot) {
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
    
    func didUpdateGameStatus(_ status: String) {
        onStatusUpdate?(status)
    }
    
    private func updateInternalState(with scorecard: ScorecardData) {
        currentUmpires = scorecard.umpires
        currentGameInfo = scorecard.gameInfo
        // currentPitchers depends on which team is being viewed, handled in VC for now or passed as needed
    }
    
    func pitchers(forIsHome home: Bool) -> [ScorecardPitcher] {
        guard let scorecard = currentScorecard else { return [] }
        return home ? scorecard.pitchers.home : scorecard.pitchers.away
    }
}
