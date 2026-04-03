import Foundation

// MARK: - API Errors

enum APIError: Error, LocalizedError {
    case noConnection
    case timeout
    case serverError(statusCode: Int)
    case decodingError(String)
    case invalidURL
    case maxRetriesExceeded
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noConnection: return "No network connection"
        case .timeout: return "Request timed out"
        case .serverError(let code): return "Server error (\(code))"
        case .decodingError(let message): return "Failed to decode: \(message)"
        case .invalidURL: return "Invalid URL"
        case .maxRetriesExceeded: return "Failed after multiple attempts"
        case .cancelled: return "Request cancelled"
        }
    }
}

// MARK: - API Client Configuration

struct APIClientConfig: Sendable {
    let baseURL: URL
    let maxRetries: Int
    let retryBaseDelay: TimeInterval
    let retryMaxDelay: TimeInterval
    let requestTimeout: TimeInterval
    let cacheTTL: TimeInterval
    let allowStaleOnError: Bool

    static let `default` = APIClientConfig(
        baseURL: URL(string: "https://statsapi.mlb.com")!,
        maxRetries: 3,
        retryBaseDelay: 1.0,
        retryMaxDelay: 30.0,
        requestTimeout: 15.0,
        cacheTTL: 60.0,
        allowStaleOnError: true
    )

    static let liveGame = APIClientConfig(
        baseURL: URL(string: "https://statsapi.mlb.com")!,
        maxRetries: 5,
        retryBaseDelay: 0.5,
        retryMaxDelay: 10.0,
        requestTimeout: 10.0,
        cacheTTL: 30.0,
        allowStaleOnError: true
    )

    static let schedule = APIClientConfig(
        baseURL: URL(string: "https://statsapi.mlb.com")!,
        maxRetries: 3,
        retryBaseDelay: 1.0,
        retryMaxDelay: 15.0,
        requestTimeout: 15.0,
        cacheTTL: 120.0,
        allowStaleOnError: true
    )

    static let staticData = APIClientConfig(
        baseURL: URL(string: "https://statsapi.mlb.com")!,
        maxRetries: 3,
        retryBaseDelay: 2.0,
        retryMaxDelay: 60.0,
        requestTimeout: 30.0,
        cacheTTL: 3600.0,
        allowStaleOnError: true
    )
}

// MARK: - Cached Response

struct CachedResponse: Sendable {
    let data: Data
    let timestamp: Date
    let ttl: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }

    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
}