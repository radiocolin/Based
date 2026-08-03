import Foundation

/// Thin client for stats.womensprobaseballleague.com/v1 — mirrors MLBAPIClient's shape.
/// The API is snake_case JSON; decoded here with .convertFromSnakeCase so WPBLAPIModels
/// can stay plain camelCase.
final class WPBLAPIClient: Sendable {
    static let shared = WPBLAPIClient()
    private let session: URLSession
    private let baseURL = URL(string: "https://stats.womensprobaseballleague.com")!

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    private func fetch<T: Decodable>(_ type: T.Type, path: String, query: [String: String] = [:]) async throws -> T {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw NSError(domain: "WPBLAPIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw NSError(domain: "WPBLAPIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        NSLog("[WPBL API] Fetching: %@", url.absoluteString)
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    func fetchGames(status: String? = nil, limit: Int? = nil, offset: Int? = nil) async throws -> [WPBLGame] {
        var query: [String: String] = [:]
        if let status { query["status"] = status }
        if let limit { query["limit"] = "\(limit)" }
        if let offset { query["offset"] = "\(offset)" }
        let response = try await fetch(WPBLGamesListResponse.self, path: "/v1/games", query: query)
        return response.games
    }

    func fetchBoxscore(gameID: String) async throws -> WPBLBoxscore {
        try await fetch(WPBLBoxscoreWrapper.self, path: "/v1/games/\(gameID)/boxscore").boxscore
    }

    func fetchTeams() async throws -> [WPBLTeam] {
        try await fetch(WPBLTeamsListResponse.self, path: "/v1/teams").teams
    }

    func fetchRoster(teamID: String) async throws -> [WPBLRosterPlayer] {
        try await fetch(WPBLPlayersListResponse.self, path: "/v1/teams/\(teamID)/players").players
    }

    func fetchPlayer(playerID: String) async throws -> WPBLRosterPlayer {
        try await fetch(WPBLRosterPlayer.self, path: "/v1/players/\(playerID)")
    }
}
