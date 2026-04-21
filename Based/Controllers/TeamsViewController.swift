import UIKit

class TeamsViewController: UITableViewController {

    private struct TeamEntry {
        let id: Int
        let name: String
    }

    private var favoriteTeams: [TeamEntry] = []
    private var otherTeams: [TeamEntry] = []
    private var pencilColor: UIColor { AppColors.pencil }
    private var isLoading = false

    private static let allTeams: [TeamEntry] = [
        TeamEntry(id: 109, name: "Arizona Diamondbacks"),
        TeamEntry(id: 144, name: "Atlanta Braves"),
        TeamEntry(id: 110, name: "Baltimore Orioles"),
        TeamEntry(id: 111, name: "Boston Red Sox"),
        TeamEntry(id: 112, name: "Chicago Cubs"),
        TeamEntry(id: 145, name: "Chicago White Sox"),
        TeamEntry(id: 113, name: "Cincinnati Reds"),
        TeamEntry(id: 114, name: "Cleveland Guardians"),
        TeamEntry(id: 115, name: "Colorado Rockies"),
        TeamEntry(id: 116, name: "Detroit Tigers"),
        TeamEntry(id: 117, name: "Houston Astros"),
        TeamEntry(id: 118, name: "Kansas City Royals"),
        TeamEntry(id: 108, name: "Los Angeles Angels"),
        TeamEntry(id: 119, name: "Los Angeles Dodgers"),
        TeamEntry(id: 146, name: "Miami Marlins"),
        TeamEntry(id: 158, name: "Milwaukee Brewers"),
        TeamEntry(id: 142, name: "Minnesota Twins"),
        TeamEntry(id: 121, name: "New York Mets"),
        TeamEntry(id: 147, name: "New York Yankees"),
        TeamEntry(id: 133, name: "Oakland Athletics"),
        TeamEntry(id: 143, name: "Philadelphia Phillies"),
        TeamEntry(id: 134, name: "Pittsburgh Pirates"),
        TeamEntry(id: 135, name: "San Diego Padres"),
        TeamEntry(id: 137, name: "San Francisco Giants"),
        TeamEntry(id: 136, name: "Seattle Mariners"),
        TeamEntry(id: 138, name: "St. Louis Cardinals"),
        TeamEntry(id: 139, name: "Tampa Bay Rays"),
        TeamEntry(id: 140, name: "Texas Rangers"),
        TeamEntry(id: 141, name: "Toronto Blue Jays"),
        TeamEntry(id: 120, name: "Washington Nationals"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Teams"
        view.backgroundColor = AppColors.paper
        tableView.separatorColor = AppColors.grid
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TeamCell")

        NotificationCenter.default.addObserver(self, selector: #selector(favoritesChanged), name: FavoritesService.favoritesDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: TeamsViewController, _) in
            self.setupNavigationBar()
            self.tableView.reloadData()
        }

        reloadTeams()
        setupNavigationBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
        reloadTeams()
    }

    @objc private func favoritesChanged() {
        reloadTeams()
    }

    @objc private func tintDidChange() {
        setupNavigationBar()
        tableView.reloadData()
    }

    private func setupNavigationBar() {
        let titleFont = BarAppearanceSupport.titleFont(for: traitCollection)
        let buttonFont = BarAppearanceSupport.buttonFont(for: traitCollection)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.paper
        appearance.titleTextAttributes = [.font: titleFont, .foregroundColor: pencilColor]
        appearance.largeTitleTextAttributes = [.font: titleFont, .foregroundColor: pencilColor]
        appearance.shadowColor = .clear
        BarAppearanceSupport.applyPlainBarButtonAppearance(appearance.buttonAppearance, font: buttonFont, color: pencilColor)
        BarAppearanceSupport.applyPlainBarButtonAppearance(appearance.backButtonAppearance, font: buttonFont, color: pencilColor)

        if let navigationBar = navigationController?.navigationBar {
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
            navigationBar.tintColor = pencilColor
        }
    }

    private func reloadTeams() {
        let favoriteIds = FavoritesService.shared.getFavoriteTeamIds()
        let all = Self.allTeams

        favoriteTeams = all.filter { favoriteIds.contains($0.id) }
            .sorted { a, b in
                let ai = favoriteIds.firstIndex(of: a.id) ?? Int.max
                let bi = favoriteIds.firstIndex(of: b.id) ?? Int.max
                return ai < bi
            }
        otherTeams = all.filter { !favoriteIds.contains($0.id) }

        tableView.reloadData()
    }

    // MARK: - Table View

    private var hasFavorites: Bool { !favoriteTeams.isEmpty }

    override func numberOfSections(in tableView: UITableView) -> Int {
        hasFavorites ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if hasFavorites {
            return section == 0 ? favoriteTeams.count : otherTeams.count
        }
        return otherTeams.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if hasFavorites {
            return section == 0 ? "Favorites" : "All Teams"
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = AppFont.permanent(16, textStyle: .headline, compatibleWith: traitCollection)
        header.textLabel?.textColor = pencilColor.withAlphaComponent(0.6)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TeamCell", for: indexPath)
        let team = teamEntry(for: indexPath)

        var config = cell.defaultContentConfiguration()
        config.text = team.name
        config.textProperties.font = AppFont.patrick(20, textStyle: .body, compatibleWith: traitCollection)
        config.textProperties.color = TeamColorProvider.color(for: team.name)
        cell.contentConfiguration = config
        cell.backgroundColor = AppColors.paper
        cell.accessoryType = .none
        let chevronSize = CGSize(width: 12, height: 12)
        let chevronImage = UIImage.pencilStyledIcon(named: "chevron.forward", color: pencilColor.withAlphaComponent(0.3), size: chevronSize)
        let chevronImageView = UIImageView(image: chevronImage)
        chevronImageView.contentMode = .center
        cell.accessoryView = chevronImageView
        cell.accessibilityTraits = .button
        cell.accessibilityLabel = team.name
        cell.accessibilityHint = "Shows team schedule"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let team = teamEntry(for: indexPath)

        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Teams", style: .plain, target: nil, action: nil)

        let scheduleVC = TeamScheduleViewController(teamId: team.id, teamName: team.name)
        navigationController?.pushViewController(scheduleVC, animated: true)
    }

    private func teamEntry(for indexPath: IndexPath) -> TeamEntry {
        if hasFavorites {
            return indexPath.section == 0 ? favoriteTeams[indexPath.row] : otherTeams[indexPath.row]
        }
        return otherTeams[indexPath.row]
    }
}
