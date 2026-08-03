import UIKit

/// The nav-bar league switcher shared by Games/Teams/Standings — always lists every defined
/// league (League.allCases), no opt-in step. See LeagueSelectionStore.
enum LeagueSwitcherBarButton {
    static func make() -> UIBarButtonItem? {
        guard League.allCases.count > 1 else { return nil }
        let store = LeagueSelectionStore.shared
        let selected = store.selectedLeague
        let actions = League.allCases.map { league in
            UIAction(title: league.displayName, state: league == selected ? .on : .off) { _ in
                store.selectedLeague = league
            }
        }
        return UIBarButtonItem(title: "\(selected.displayName) \u{25BE}", menu: UIMenu(title: "League", children: actions))
    }
}
