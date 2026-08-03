import Foundation

final class LeagueRegistry: Sendable {
    static let shared = LeagueRegistry()

    private let providers: [League: LeagueProvider]

    private init() {
        providers = [
            .mlb: MLBLeagueProvider(),
            .wpbl: WPBLLeagueProvider()
        ]
    }

    func provider(for league: League) -> LeagueProvider {
        guard let provider = providers[league] else {
            fatalError("No LeagueProvider registered for \(league.rawValue)")
        }
        return provider
    }
}
