import Foundation

/// Wraps GameService.shared exactly as GameDetailViewController/GameDetailViewModel use it today.
/// Not wired into GameDetailViewController until M4 — GameDetailViewModel keeps setting itself as
/// GameService's delegate directly until then, so this type is inert (built, unused) through M2/M3.
final class MLBGameDataSource: GameDetailDataSource, GameUpdateDelegate {
    private let gamePk: Int
    private var onSnapshot: ((LiveGameSnapshot) -> Void)?
    private var onStatus: ((String) -> Void)?

    init(gamePk: Int) {
        self.gamePk = gamePk
    }

    func start(onSnapshot: @escaping (LiveGameSnapshot) -> Void, onStatus: @escaping (String) -> Void) {
        self.onSnapshot = onSnapshot
        self.onStatus = onStatus
        GameService.shared.delegate = self
        GameService.shared.startPolling(gamePk: gamePk)
    }

    func stop() {
        GameService.shared.stopPolling()
        onSnapshot = nil
        onStatus = nil
    }

    func fetchPlayerInfo(playerID: String) async throws -> PlayerInfo {
        guard let id = Int(playerID) else {
            throw NSError(domain: "MLBGameDataSource", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid player id: \(playerID)"])
        }
        return try await GameService.shared.fetchPlayerInfo(playerId: id)
    }

    func didUpdateSnapshot(_ snapshot: LiveGameSnapshot) {
        onSnapshot?(snapshot)
    }

    func didUpdateGameStatus(_ status: String) {
        onStatus?(status)
    }
}
