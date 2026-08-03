import Foundation

/// Persisted "what league am I looking at right now" + "which leagues has this user added."
/// MLB is always in `activeLeagues` and can't be removed — a fresh install has exactly one
/// league, so the league switcher UI stays structurally absent until a second one is added.
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
            NotificationCenter.default.post(name: Self.selectionDidChangeNotification, object: nil)
        }
    }

    var activeLeagues: [League] {
        get {
            let stored = (defaults.stringArray(forKey: activeLeaguesKey) ?? []).compactMap(League.init(rawValue:))
            var leagues = stored.isEmpty ? [League.default] : stored
            if !leagues.contains(.default) {
                leagues.insert(.default, at: 0)
            }
            return leagues
        }
        set {
            var leagues = newValue
            if !leagues.contains(.default) {
                leagues.insert(.default, at: 0)
            }
            defaults.set(leagues.map(\.rawValue), forKey: activeLeaguesKey)
            if !leagues.contains(selectedLeague) {
                selectedLeague = .default
            }
            NotificationCenter.default.post(name: Self.selectionDidChangeNotification, object: nil)
        }
    }

    func addLeague(_ league: League) {
        guard !activeLeagues.contains(league) else { return }
        activeLeagues += [league]
    }

    func removeLeague(_ league: League) {
        guard league != .default else { return }
        activeLeagues = activeLeagues.filter { $0 != league }
    }
}
