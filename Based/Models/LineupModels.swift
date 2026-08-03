import Foundation

// MARK: - Lineup Models

struct Lineups: Codable, Sendable, Equatable {
    let home: [ScorecardBatter]
    let away: [ScorecardBatter]
}

struct ScorecardBatter: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let fullName: String
    let abbreviation: String
    let position: String
    let jerseyNumber: String?
    let battingOrderSlot: Int?
    let inningEntered: Int?
    let inningExited: Int?
}
