import Foundation

enum League: String, CaseIterable, Codable, Sendable {
    case mlb
    case wpbl

    var displayName: String {
        switch self {
        case .mlb: return "MLB"
        case .wpbl: return "WPBL"
        }
    }

    var fullName: String {
        switch self {
        case .mlb: return "Major League Baseball"
        case .wpbl: return "Women's Pro Baseball League"
        }
    }

    /// The league every fresh install starts on.
    static let `default`: League = .mlb
}
