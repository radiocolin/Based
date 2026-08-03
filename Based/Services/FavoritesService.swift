import Foundation

final class FavoritesService: Sendable {
    static let shared = FavoritesService()
    static let favoritesDidChangeNotification = Notification.Name("FavoritesServiceFavoritesDidChange")
    private let favoritesKey = "based_favorite_team_ids"
    private let autoEnterKey = "based_auto_enter_team_ids"
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - MLB (Int-keyed) — this key predates multi-league support and is left exactly as-is,
    // so there's nothing to migrate: existing MLB favorites just keep working unchanged.

    func isFavorite(teamId: Int) -> Bool {
        let favorites = defaults.array(forKey: favoritesKey) as? [Int] ?? []
        return favorites.contains(teamId)
    }

    func toggleFavorite(teamId: Int) {
        var favorites = defaults.array(forKey: favoritesKey) as? [Int] ?? []
        var autoEnters = defaults.array(forKey: autoEnterKey) as? [Int] ?? []

        if let index = favorites.firstIndex(of: teamId) {
            favorites.remove(at: index)
            if let autoIndex = autoEnters.firstIndex(of: teamId) {
                autoEnters.remove(at: autoIndex)
            }
        } else {
            favorites.append(teamId)
        }

        defaults.set(favorites, forKey: favoritesKey)
        defaults.set(autoEnters, forKey: autoEnterKey)
        NotificationCenter.default.post(name: Self.favoritesDidChangeNotification, object: nil)
    }

    func getFavoriteTeamIds() -> [Int] {
        defaults.array(forKey: favoritesKey) as? [Int] ?? []
    }

    func setFavoriteTeamIds(_ ids: [Int]) {
        defaults.set(ids, forKey: favoritesKey)
        NotificationCenter.default.post(name: Self.favoritesDidChangeNotification, object: nil)
    }

    func isAutoEnterEnabled(for teamId: Int) -> Bool {
        let autoEnters = defaults.array(forKey: autoEnterKey) as? [Int] ?? []
        return autoEnters.contains(teamId)
    }

    func setAutoEnterEnabled(_ enabled: Bool, for teamId: Int) {
        var autoEnters = defaults.array(forKey: autoEnterKey) as? [Int] ?? []
        if enabled {
            if !autoEnters.contains(teamId) {
                autoEnters.append(teamId)
            }
        } else {
            if let index = autoEnters.firstIndex(of: teamId) {
                autoEnters.remove(at: index)
            }
        }
        defaults.set(autoEnters, forKey: autoEnterKey)
        NotificationCenter.default.post(name: Self.favoritesDidChangeNotification, object: nil)
    }

    // MARK: - League-scoped (String-keyed) — WPBL and any future non-MLB league. Storage is
    // namespaced per league so a WPBL team id can never collide with an MLB one; MLB calls here
    // just forward to the Int-keyed API above rather than duplicating storage.

    private func favoritesKey(for league: League) -> String { "based_favorite_team_ids.\(league.rawValue)" }
    private func autoEnterKey(for league: League) -> String { "based_auto_enter_team_ids.\(league.rawValue)" }

    func isFavorite(teamID: String, league: League) -> Bool {
        if league == .mlb, let intID = Int(teamID) { return isFavorite(teamId: intID) }
        let favorites = defaults.stringArray(forKey: favoritesKey(for: league)) ?? []
        return favorites.contains(teamID)
    }

    func toggleFavorite(teamID: String, league: League) {
        if league == .mlb, let intID = Int(teamID) {
            toggleFavorite(teamId: intID)
            return
        }
        var favorites = defaults.stringArray(forKey: favoritesKey(for: league)) ?? []
        var autoEnters = defaults.stringArray(forKey: autoEnterKey(for: league)) ?? []

        if let index = favorites.firstIndex(of: teamID) {
            favorites.remove(at: index)
            if let autoIndex = autoEnters.firstIndex(of: teamID) {
                autoEnters.remove(at: autoIndex)
            }
        } else {
            favorites.append(teamID)
        }

        defaults.set(favorites, forKey: favoritesKey(for: league))
        defaults.set(autoEnters, forKey: autoEnterKey(for: league))
        NotificationCenter.default.post(name: Self.favoritesDidChangeNotification, object: nil)
    }

    func getFavoriteTeamIDs(for league: League) -> [String] {
        if league == .mlb { return getFavoriteTeamIds().map(String.init) }
        return defaults.stringArray(forKey: favoritesKey(for: league)) ?? []
    }

    func isAutoEnterEnabled(teamID: String, league: League) -> Bool {
        if league == .mlb, let intID = Int(teamID) { return isAutoEnterEnabled(for: intID) }
        let autoEnters = defaults.stringArray(forKey: autoEnterKey(for: league)) ?? []
        return autoEnters.contains(teamID)
    }

    func setAutoEnterEnabled(_ enabled: Bool, teamID: String, league: League) {
        if league == .mlb, let intID = Int(teamID) {
            setAutoEnterEnabled(enabled, for: intID)
            return
        }
        var autoEnters = defaults.stringArray(forKey: autoEnterKey(for: league)) ?? []
        if enabled {
            if !autoEnters.contains(teamID) {
                autoEnters.append(teamID)
            }
        } else if let index = autoEnters.firstIndex(of: teamID) {
            autoEnters.remove(at: index)
        }
        defaults.set(autoEnters, forKey: autoEnterKey(for: league))
        NotificationCenter.default.post(name: Self.favoritesDidChangeNotification, object: nil)
    }
}
