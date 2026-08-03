import Foundation

/// Persisted "what league am I looking at right now" + "which leagues has this user added."
/// A fresh install has exactly one league (MLB), so the league switcher UI stays structurally
/// absent until a second one is added. No single league is permanently pinned — any league can
/// be removed as long as it isn't the one currently selected and isn't the last one remaining
/// (you can always deselect MLB once you've switched your current view to something else, but
/// at least one league must always be active and selected).
final class LeagueSelectionStore: Sendable {
    static let shared = LeagueSelectionStore()

    static let selectionDidChangeNotification = Notification.Name("LeagueSelectionStore.selectionDidChange")

    private let defaults = UserDefaults.standard
    private let selectedLeagueKey = "based_selected_league"
    private let activeLeaguesKey = "based_active_leagues"

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
            if !activeLeagues.contains(newValue) {
                addLeague(newValue)
            }
            NotificationCenter.default.post(name: Self.selectionDidChangeNotification, object: nil)
        }
    }

    var activeLeagues: [League] {
        get {
            let stored = (defaults.stringArray(forKey: activeLeaguesKey) ?? []).compactMap(League.init(rawValue:))
            return stored.isEmpty ? [League.default] : stored
        }
        set {
            let leagues = newValue.isEmpty ? [League.default] : newValue
            defaults.set(leagues.map(\.rawValue), forKey: activeLeaguesKey)
            NotificationCenter.default.post(name: Self.selectionDidChangeNotification, object: nil)
            if !leagues.contains(selectedLeague) {
                selectedLeague = leagues[0]
            }
        }
    }

    func addLeague(_ league: League) {
        guard !activeLeagues.contains(league) else { return }
        activeLeagues += [league]
    }

    /// No-op if this is the currently selected league (switch away first) or the only remaining
    /// active league.
    func removeLeague(_ league: League) {
        guard league != selectedLeague, activeLeagues.count > 1 else { return }
        activeLeagues = activeLeagues.filter { $0 != league }
    }
}
