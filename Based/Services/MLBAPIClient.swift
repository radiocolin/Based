import Foundation

// MARK: - ETag Cache (stores both raw data and pre-decoded objects)

private actor ETagCache {
    private var storage: [String: (etag: String, data: Data, decoded: Any)] = [:]

    func etag(for endpoint: String) -> String? {
        storage[endpoint]?.etag
    }

    func cachedDecoded<T>(for endpoint: String) -> T? {
        storage[endpoint]?.decoded as? T
    }

    func store<T>(etag: String, data: Data, decoded: T, for endpoint: String) {
        storage[endpoint] = (etag, data, decoded)
    }
}

// MARK: - MLB API Client

final class MLBAPIClient: Sendable {
    static let shared = MLBAPIClient()
    private let session: URLSession
    private let baseURL = URL(string: "https://statsapi.mlb.com")!
    private let etagCache = ETagCache()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15   // 15s per request (don't hang the radio on bad coverage)
        config.timeoutIntervalForResource = 30  // 30s total for the resource
        config.waitsForConnectivity = false      // Fail fast rather than queue requests
        session = URLSession(configuration: config)
    }

    func fetch<T: Decodable>(_ type: T.Type, endpoint: String) async throws -> T {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            throw NSError(domain: "MLBAPIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        NSLog("[API] Fetching: %@", url.absoluteString)
        var request = URLRequest(url: url)
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        if let etag = await etagCache.etag(for: endpoint) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            // 304 Not Modified — return pre-decoded cached object (no JSON parsing needed)
            if httpResponse.statusCode == 304,
               let cached: T = await etagCache.cachedDecoded(for: endpoint) {
                NSLog("[API] 304 Not Modified: %@", endpoint)
                return cached
            }

            if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                await etagCache.store(etag: etag, data: data, decoded: decoded, for: endpoint)
                return decoded
            }
        }

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

    func fetchLiveFeed(gamePk: Int) async throws -> LiveFeedResponse {
        try await fetch(LiveFeedResponse.self, endpoint: "/api/v1.1/game/\(gamePk)/feed/live")
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
            endpoint: "/api/v1/people/\(id)?hydrate=stats(group=[hitting,pitching],type=[season,career])"
        )
        guard let player = response.people?.first else {
            throw NSError(domain: "MLBAPIClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "Player not found"])
        }
        return player
    }

    func fetchTeams() async throws -> [Team] {
        struct TeamsResponse: Decodable {
            let teams: [Team]
        }
        let response = try await fetch(TeamsResponse.self, endpoint: "/api/v1/teams?sportId=1")
        return response.teams
    }
}
