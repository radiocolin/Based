import Foundation

/// Persisted "what league am I looking at right now." Defaults to MLB. The nav-bar switcher
/// always lists every defined league (League.allCases) — no separate opt-in/add-a-league step
/// in Settings, since with just MLB + WPBL today a dedicated toggle for one extra league is
/// unnecessary ceremony. Revisit if the league count grows enough that listing all of them
/// unconditionally stops making sense.
final class LeagueSelectionStore: Sendable {
    static let shared = LeagueSelectionStore()

    static let selectionDidChangeNotification = Notification.Name("LeagueSelectionStore.selectionDidChange")

    private let defaults = UserDefaults.standard
    private let selectedLeagueKey = "based_selected_league"

    private init() {}

    var selectedLeague: League {
        get {
            guard let raw = defaults.string(forKey: selectedLeagueKey), let league = League(rawValue: raw) else {
                return .default
            }
            return league
        }
        set {
            defaults.set(newValue.rawValue, forKey: selectedLeagueKey)
            NotificationCenter.default.post(name: Self.selectionDidChangeNotification, object: nil)
        }
    }
}
