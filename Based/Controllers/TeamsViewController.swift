import UIKit
import TipKit

class TeamsViewController: UITableViewController {

    private var provider: LeagueProvider { LeagueRegistry.shared.provider(for: LeagueSelectionStore.shared.selectedLeague) }

    private var allTeams: [LeagueTeam] = []
    private var favoriteTeams: [LeagueTeam] = []
    private var otherTeams: [LeagueTeam] = []
    private var pencilColor: UIColor { AppColors.pencil }
    private var isLoading = false
    private var teamRecords: [String: (wins: Int, losses: Int, division: String?)] = [:]
    private var teamsTask: Task<Void, Never>?
    private var standingsTask: Task<Void, Never>?

    private let favoriteTeamTip = FavoriteTeamTip()
    private var tipObservationTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Teams"
        view.backgroundColor = AppColors.paper
        tableView.separatorColor = AppColors.grid
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TeamCell")

        NotificationCenter.default.addObserver(self, selector: #selector(favoritesChanged), name: FavoritesService.favoritesDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(leagueSelectionChanged), name: LeagueSelectionStore.selectionDidChangeNotification, object: nil)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: TeamsViewController, _) in
            self.setupNavigationBar()
            self.tableView.reloadData()
        }

        loadTeams()
        setupNavigationBar()
        loadStandings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
        applyFavoritesFilter()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observeTips()
    }

    private func observeTips() {
        guard tipObservationTask == nil else { return }
        tipObservationTask = Task { @MainActor in
            await observeTip(favoriteTeamTip) { [weak self] in
                self?.tableView.visibleCells.first ?? self?.tableView
            }
        }
    }

    private func observeTip(_ tip: any Tip, sourceItemProvider: @escaping () -> UIPopoverPresentationControllerSourceItem?) async {
        var presentationTask: Task<Void, Never>?
        
        for await shouldDisplay in tip.shouldDisplayUpdates {
            presentationTask?.cancel()
            if shouldDisplay {
                presentationTask = Task { @MainActor in
                    while true {
                        if Task.isCancelled { return }
                        if presentedViewController == nil, let sourceItem = sourceItemProvider() {
                            let popover = TipUIPopoverViewController(tip, sourceItem: sourceItem)
                            present(popover, animated: true)
                            return
                        }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
            } else {
                if presentedViewController is TipUIPopoverViewController {
                    dismiss(animated: true)
                }
                if case .invalidated = tip.status { break }
            }
        }
        presentationTask?.cancel()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            tipObservationTask?.cancel()
            tipObservationTask = nil
        }
    }

    @objc private func favoritesChanged() {
        applyFavoritesFilter()
    }

    @objc private func tintDidChange() {
        setupNavigationBar()
        tableView.reloadData()
    }

    @objc private func leagueSelectionChanged() {
        setupNavigationBar()
        teamRecords = [:]
        loadTeams()
        loadStandings()
    }

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = LeagueSwitcherBarButton.make()
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

    private func loadStandings() {
        standingsTask?.cancel()
        standingsTask = Task {
            guard let sections = try? await provider.fetchStandings() else { return }
            var map: [String: (wins: Int, losses: Int, division: String?)] = [:]
            for section in sections {
                let leagueShort = (section.title ?? "")
                    .replacingOccurrences(of: "American League", with: "AL")
                    .replacingOccurrences(of: "National League", with: "NL")
                var currentDivision: String?
                for row in section.rows {
                    switch row {
                    case .subHeader(let name):
                        currentDivision = leagueShort.isEmpty ? name : "\(leagueShort) \(name)"
                    case .team(let team):
                        map[team.teamID] = (team.wins, team.losses, currentDivision)
                    }
                }
            }
            guard !Task.isCancelled else { return }
            teamRecords = map
            tableView.reloadData()
        }
    }

    private func loadTeams() {
        teamsTask?.cancel()
        teamsTask = Task {
            guard let teams = try? await provider.fetchTeams() else { return }
            guard !Task.isCancelled else { return }
            allTeams = teams
            applyFavoritesFilter()
        }
    }

    private func applyFavoritesFilter() {
        let favoriteIds = FavoritesService.shared.getFavoriteTeamIds()
        func isFavorite(_ team: LeagueTeam) -> Bool {
            guard let id = Int(team.id) else { return false }
            return favoriteIds.contains(id)
        }

        favoriteTeams = allTeams.filter(isFavorite)
            .sorted { a, b in
                let ai = Int(a.id).flatMap { favoriteIds.firstIndex(of: $0) } ?? Int.max
                let bi = Int(b.id).flatMap { favoriteIds.firstIndex(of: $0) } ?? Int.max
                return ai < bi
            }
        otherTeams = allTeams.filter { !isFavorite($0) }

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

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard hasFavorites else { return nil }
        let title = section == 0 ? "Favorites" : "All Teams"
        let pc = pencilColor

        let header = UIView()
        header.backgroundColor = AppColors.paper

        let nameLabel = UILabel()
        nameLabel.text = title
        nameLabel.font = AppFont.ibmPlexCondensed(22, textStyle: .title2, compatibleWith: traitCollection)
        nameLabel.textColor = pc
        nameLabel.isAccessibilityElement = false

        let line = UIView()
        line.backgroundColor = pc.withAlphaComponent(0.15)

        header.addSubview(nameLabel)
        header.addSubview(line)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        line.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),

            line.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            line.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            line.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            line.heightAnchor.constraint(equalToConstant: 1),
            line.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -4)
        ])

        header.isAccessibilityElement = true
        header.accessibilityLabel = title
        header.accessibilityTraits = .header

        return header
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard hasFavorites else { return 0 }
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        hasFavorites ? 36 : 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TeamCell", for: indexPath)
        let team = teamEntry(for: indexPath)

        var config = cell.defaultContentConfiguration()
        config.text = team.name
        config.textProperties.font = AppFont.ibmPlexCondensedBold(18, textStyle: .body, compatibleWith: traitCollection)
        config.textProperties.color = TeamColorProvider.color(for: team.name)

        if let info = teamRecords[team.id] {
            let detailAttr = NSMutableAttributedString()
            let recordText = "\(info.wins)-\(info.losses)"
            let recordAttrs: [NSAttributedString.Key: Any] = [
                .font: AppFont.patrick(15, textStyle: .subheadline, compatibleWith: traitCollection),
                .foregroundColor: pencilColor
            ]
            detailAttr.append(NSAttributedString(string: recordText, attributes: recordAttrs))

            if let division = info.division, !division.isEmpty {
                let divAttrs: [NSAttributedString.Key: Any] = [
                    .font: AppFont.ibmPlexCondensed(12, textStyle: .caption1, compatibleWith: traitCollection),
                    .foregroundColor: pencilColor.withAlphaComponent(0.45)
                ]
                detailAttr.append(NSAttributedString(string: "  \(division)", attributes: divAttrs))
            }

            config.attributedText = nil
            config.secondaryAttributedText = detailAttr
        }

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
        guard let teamId = Int(team.id) else { return }

        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Teams", style: .plain, target: nil, action: nil)

        let scheduleVC = TeamScheduleViewController(teamId: teamId, teamName: team.name)
        navigationController?.pushViewController(scheduleVC, animated: true)
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let team = teamEntry(for: indexPath)
        guard let teamId = Int(team.id) else { return nil }
        let isFavorite = FavoritesService.shared.isFavorite(teamId: teamId)

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let favoriteAction = UIAction(
                title: isFavorite ? "Remove from Favorites" : "Add to Favorites",
                image: UIImage(systemName: isFavorite ? "star" : "star.fill")
            ) { _ in
                let feedback = UISelectionFeedbackGenerator()
                feedback.prepare()
                feedback.selectionChanged()
                FavoritesService.shared.toggleFavorite(teamId: teamId)
            }

            return UIMenu(title: team.name, children: [favoriteAction])
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayContextMenu configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred()
        favoriteTeamTip.invalidate(reason: .actionPerformed)
    }

    private func teamEntry(for indexPath: IndexPath) -> LeagueTeam {
        if hasFavorites {
            return indexPath.section == 0 ? favoriteTeams[indexPath.row] : otherTeams[indexPath.row]
        }
        return otherTeams[indexPath.row]
    }
}
