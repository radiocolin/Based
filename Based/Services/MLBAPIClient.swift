import Foundation

// MARK: - MLB API Client

final class MLBAPIClient: Sendable {
    static let shared = MLBAPIClient()
    private let session = URLSession.shared
    private let baseURL = URL(string: "https://statsapi.mlb.com")!

    private init() {}

    func fetch<T: Decodable>(_ type: T.Type, endpoint: String) async throws -> T {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            throw NSError(domain: "MLBAPIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        NSLog("[API] Fetching: %@", url.absoluteString)
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Convenience Methods

extension MLBAPIClient {
    func fetchLinescore(gamePk: Int) async throws -> Linescore {
        try await fetch(Linescore.self, endpoint: "/api/v1/game/\(gamePk)/linescore")
    }

    func fetchPlayByPlay(gamePk: Int) async throws -> PlayByPlayResponse {
        try await fetch(PlayByPlayResponse.self, endpoint: "/api/v1/game/\(gamePk)/playByPlay")
    }

    func fetchBoxscore(gamePk: Int) async throws -> BoxscoreResponse {
        try await fetch(BoxscoreResponse.self, endpoint: "/api/v1/game/\(gamePk)/boxscore")
    }

    func fetchSchedule(date: Date) async throws -> [ScheduleGame] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        let response = try await fetch(
            ScheduleResponse.self, 
            endpoint: "/api/v1/schedule?date=\(dateString)&sportId=1&hydrate=team"
        )
        return response.dates.first?.games ?? []
    }

    func fetchPlayer(id: Int) async throws -> PlayerInfo {
        let response = try await fetch(
            PlayerInfoResponse.self,
            endpoint: "/api/v1/people/\(id)?hydrate=stats(group=[batting],type=[season,career])"
        )
        guard let player = response.people?.first else {
            throw NSError(domain: "MLBAPIClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "Player not found"])
        }
        return player
    }
}
