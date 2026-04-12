import Foundation

final class FavoritesService: Sendable {
    static let shared = FavoritesService()
    static let favoritesDidChangeNotification = Notification.Name("FavoritesServiceFavoritesDidChange")
    private let favoritesKey = "based_favorite_team_ids"
    private let autoEnterKey = "based_auto_enter_team_ids"
    private let defaults = UserDefaults.standard
    
    private init() {}
    
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
}
