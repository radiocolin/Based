import Foundation

/// Bio fields are optional throughout, both leagues render a row only when its value is present
/// (WPBL currently reports most of them blank; MLB has them all).
struct LeagueRosterPlayer: Identifiable, Hashable, Sendable {
    let id: String
    let league: League
    let teamID: String
    let fullName: String
    let position: String?
    let uniformNumber: String?
    let bats: String?
    let throwsHand: String?
    let heightDisplay: String?
    let weightDisplay: String?
    let hometown: String?
    let birthDate: Date?
}
