import Foundation

/// The seam that lets `GameDetailViewController` serve any league: MLB wraps today's
/// `GameService.shared` polling exactly as before, WPBL polls its single boxscore endpoint.
protocol GameDetailDataSource: AnyObject {
    func start(onSnapshot: @escaping (LiveGameSnapshot) -> Void, onStatus: @escaping (String) -> Void)
    func stop()
    func fetchPlayerInfo(playerID: String) async throws -> PlayerInfo
}
