import Foundation

final class FavoritesService: Sendable {
    static let shared = FavoritesService()
    static let favoritesDidChangeNotification = Notification.Name("FavoritesServiceFavoritesDidChange")
    private let favoritesKey = "based_favorite_team_ids"
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    func isFavorite(teamId: Int) -> Bool {
        let favorites = defaults.array(forKey: favoritesKey) as? [Int] ?? []
        return favorites.contains(teamId)
    }
    
    func toggleFavorite(teamId: Int) {
        var favorites = defaults.array(forKey: favoritesKey) as? [Int] ?? []
        if let index = favorites.firstIndex(of: teamId) {
            favorites.remove(at: index)
        } else {
            favorites.append(teamId)
        }
        defaults.set(favorites, forKey: favoritesKey)
        NotificationCenter.default.post(name: Self.favoritesDidChangeNotification, object: nil)
    }

    func getFavoriteTeamIds() -> [Int] {
        defaults.array(forKey: favoritesKey) as? [Int] ?? []
    }
}
