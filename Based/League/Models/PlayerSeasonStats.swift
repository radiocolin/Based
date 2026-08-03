import Foundation

/// Sparse stat-abbreviation -> display-value maps (e.g. "AVG" -> ".312"), deliberately not a rigid
/// struct with one field per stat: MLB and WPBL don't expose the same stat vocabulary, and WPBL's
/// own API already uses this sparse-keys pattern (a field is just absent when not applicable).
struct PlayerSeasonStats: Sendable {
    let playerID: String
    let league: League
    let battingLine: [String: String]?
    let pitchingLine: [String: String]?
    let asOf: Date?
}
