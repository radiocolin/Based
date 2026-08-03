import UIKit

/// The nav-bar league switcher shared by Games/Teams/Standings — structurally absent (returns
/// nil) unless the user has added a second league in Settings, so a fresh MLB-only install shows
/// no new chrome anywhere. Selecting a league posts LeagueSelectionStore.selectionDidChangeNotification;
/// each screen observes that to reload and rebuild its own switcher button.
enum LeagueSwitcherBarButton {
    static func make() -> UIBarButtonItem? {
        let store = LeagueSelectionStore.shared
        guard store.activeLeagues.count > 1 else { return nil }
        let selected = store.selectedLeague
        let actions = store.activeLeagues.map { league in
            UIAction(title: league.displayName, state: league == selected ? .on : .off) { _ in
                store.selectedLeague = league
            }
        }
        return UIBarButtonItem(title: "\(selected.displayName) \u{25BE}", menu: UIMenu(title: "League", children: actions))
    }
}
