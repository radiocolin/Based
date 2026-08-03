import UIKit

/// A simpler, league-agnostic team detail screen (schedule + roster) for leagues beyond MLB.
/// MLB keeps using the richer TeamScheduleViewController (season stats, manager, streaks) —
/// LeagueGame/LeagueRosterPlayer don't carry the data those need, and retrofitting a full stats
/// box onto a 4-team league isn't warranted. This gives every non-MLB league at least schedule
/// and roster navigation, matching the "provider not modification" pattern the league layer
/// already follows elsewhere.
final class LeagueTeamDetailViewController: UIViewController {

    private struct MonthSection {
        let title: String
        let games: [LeagueGame]
    }

    private let teamID: String
    private let teamName: String
    private let league: League
    private let provider: LeagueProvider

    private let segmentedControl = UISegmentedControl(items: ["Schedule", "Roster"])
    private lazy var segmentedOverlay = PencilSegmentedOverlay(segmentedControl: segmentedControl)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let rosterTableView = UITableView(frame: .zero, style: .plain)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    private var scheduleSections: [MonthSection] = []
    private var nextGameIndexPath: IndexPath?
    private var roster: [LeagueRosterPlayer] = []
    private var loadTask: Task<Void, Never>?

    private var pencilColor: UIColor { AppColors.pencil }

    init(teamID: String, teamName: String, league: League) {
        self.teamID = teamID
        self.teamName = teamName
        self.league = league
        self.provider = LeagueRegistry.shared.provider(for: league)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = teamName
        view.backgroundColor = AppColors.paper

        setupSegmentedControl()
        setupTableViews()
        setupLoadingViews()

        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: LeagueTeamDetailViewController, _) in
            self.setupNavigationBar()
            self.tableView.reloadData()
        }

        setupNavigationBar()
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        loadSchedule()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
    }

    @objc private func tintDidChange() {
        setupNavigationBar()
        tableView.reloadData()
    }

    // MARK: - UI Setup

    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        let clear = UIImage()
        segmentedControl.setBackgroundImage(clear, for: .normal, barMetrics: .default)
        segmentedControl.setBackgroundImage(clear, for: .selected, barMetrics: .default)
        segmentedControl.setDividerImage(clear, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)

        let font = AppFont.patrick(18, textStyle: .body, compatibleWith: traitCollection)
        segmentedControl.setTitleTextAttributes([.font: font, .foregroundColor: pencilColor.withAlphaComponent(0.6)], for: .normal)
        segmentedControl.setTitleTextAttributes([.font: font, .foregroundColor: pencilColor], for: .selected)

        view.addSubview(segmentedControl)
        view.addSubview(segmentedOverlay)

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedOverlay.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            segmentedControl.heightAnchor.constraint(equalToConstant: 40),

            segmentedOverlay.topAnchor.constraint(equalTo: segmentedControl.topAnchor),
            segmentedOverlay.leadingAnchor.constraint(equalTo: segmentedControl.leadingAnchor),
            segmentedOverlay.trailingAnchor.constraint(equalTo: segmentedControl.trailingAnchor),
            segmentedOverlay.bottomAnchor.constraint(equalTo: segmentedControl.bottomAnchor)
        ])
    }

    private func setupTableViews() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = AppColors.paper
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.register(TeamGameCell.self, forCellReuseIdentifier: TeamGameCell.reuseIdentifier)

        rosterTableView.dataSource = self
        rosterTableView.delegate = self
        rosterTableView.backgroundColor = AppColors.paper
        rosterTableView.separatorStyle = .none
        rosterTableView.rowHeight = UITableView.automaticDimension
        rosterTableView.estimatedRowHeight = 60
        rosterTableView.register(RosterPlayerCell.self, forCellReuseIdentifier: RosterPlayerCell.reuseIdentifier)
        rosterTableView.isHidden = true

        for tv in [tableView, rosterTableView] {
            view.addSubview(tv)
            tv.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tv.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
                tv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }
    }

    private func setupLoadingViews() {
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = pencilColor
        loadingIndicator.accessibilityElementsHidden = true

        errorLabel.font = AppFont.ibmPlexCondensed(20, textStyle: .title3, compatibleWith: traitCollection)
        errorLabel.textColor = pencilColor.withAlphaComponent(0.5)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        retryButton.setTitle("Tap to retry", for: .normal)
        retryButton.titleLabel?.font = AppFont.ibmPlexCondensed(18, textStyle: .body, compatibleWith: traitCollection)
        retryButton.tintColor = pencilColor
        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        for v: UIView in [loadingIndicator, errorLabel, retryButton] {
            view.addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 8),
            retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func setupNavigationBar() {
        navigationItem.hidesBackButton = true
        let prevTitle = navigationController?.viewControllers.dropLast().last?.title
        navigationItem.leftBarButtonItem = BarAppearanceSupport.makePencilBackButton(
            title: prevTitle ?? "Back", traitCollection: traitCollection, target: self, action: #selector(backTapped)
        )

        let titleFont = BarAppearanceSupport.titleFont(for: traitCollection)
        let buttonFont = BarAppearanceSupport.buttonFont(for: traitCollection)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.paper
        let teamColor = TeamColorProvider.color(for: teamName)
        appearance.titleTextAttributes = [.font: titleFont, .foregroundColor: teamColor]
        appearance.largeTitleTextAttributes = [.font: titleFont, .foregroundColor: teamColor]
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

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Data Loading

    private func loadSchedule() {
        loadTask?.cancel()
        loadingIndicator.startAnimating()
        errorLabel.isHidden = true
        retryButton.isHidden = true

        loadTask = Task {
            do {
                let games = try await provider.fetchTeamSchedule(teamID: teamID)
                guard !Task.isCancelled else { return }
                self.scheduleSections = self.buildMonthSections(from: games.sorted { $0.startDate < $1.startDate })
                self.nextGameIndexPath = self.findNextGameIndexPath()
                self.loadingIndicator.stopAnimating()
                self.tableView.reloadData()
                self.scrollToNextGame(animated: false)
            } catch {
                guard !Task.isCancelled else { return }
                self.loadingIndicator.stopAnimating()
                if self.scheduleSections.isEmpty {
                    self.errorLabel.text = "Couldn't load schedule"
                    self.errorLabel.isHidden = false
                    self.retryButton.isHidden = false
                }
            }
        }
    }

    private func loadRoster() {
        loadingIndicator.startAnimating()
        Task {
            do {
                let players = try await provider.fetchRoster(teamID: teamID)
                self.roster = players.sorted { $0.fullName < $1.fullName }
                self.loadingIndicator.stopAnimating()
                self.rosterTableView.reloadData()
            } catch {
                self.loadingIndicator.stopAnimating()
                if self.roster.isEmpty {
                    self.errorLabel.text = "Couldn't load roster"
                    self.errorLabel.isHidden = false
                    self.retryButton.isHidden = false
                }
            }
        }
    }

    @objc private func modeChanged() {
        let isSchedule = segmentedControl.selectedSegmentIndex == 0
        tableView.isHidden = !isSchedule
        rosterTableView.isHidden = isSchedule
        errorLabel.isHidden = true
        retryButton.isHidden = true

        if !isSchedule && roster.isEmpty {
            loadRoster()
        }
    }

    @objc private func retryTapped() {
        if segmentedControl.selectedSegmentIndex == 0 {
            loadSchedule()
        } else {
            loadRoster()
        }
    }

    private func buildMonthSections(from games: [LeagueGame]) -> [MonthSection] {
        let cal = Calendar.current
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"

        var sectionMap: [(key: Int, title: String, games: [LeagueGame])] = []
        for game in games {
            let month = cal.component(.month, from: game.startDate)
            if let last = sectionMap.last, last.key == month {
                sectionMap[sectionMap.count - 1].games.append(game)
            } else {
                sectionMap.append((key: month, title: monthFormatter.string(from: game.startDate), games: [game]))
            }
        }
        return sectionMap.map { MonthSection(title: $0.title, games: $0.games) }
    }

    private func findNextGameIndexPath() -> IndexPath? {
        for (s, section) in scheduleSections.enumerated() {
            for (r, game) in section.games.enumerated() {
                if !game.status.isFinal {
                    return IndexPath(row: r, section: s)
                }
            }
        }
        return nil
    }

    private func scrollToNextGame(animated: Bool) {
        guard let ip = nextGameIndexPath else { return }
        let targetRow = max(0, ip.row - 2)
        let targetIP = IndexPath(row: targetRow, section: ip.section)
        tableView.scrollToRow(at: targetIP, at: .top, animated: animated)
    }
}

extension LeagueTeamDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        tableView === self.tableView ? scheduleSections.count : 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableView === self.tableView ? scheduleSections[section].games.count : roster.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        tableView === self.tableView ? scheduleSections[section].title : nil
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = AppFont.ibmPlexCondensedBold(16, textStyle: .headline, compatibleWith: tableView.traitCollection)
        header.textLabel?.textColor = pencilColor.withAlphaComponent(0.6)
        header.contentView.backgroundColor = AppColors.paper
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView === self.tableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: TeamGameCell.reuseIdentifier, for: indexPath) as! TeamGameCell
            let game = scheduleSections[indexPath.section].games[indexPath.row]
            let isNext = indexPath == nextGameIndexPath

            var isSeriesStart = indexPath.row == 0
            if indexPath.row > 0 {
                let prev = scheduleSections[indexPath.section].games[indexPath.row - 1]
                let prevOpponent = prev.homeTeamID == teamID ? prev.awayTeamID : prev.homeTeamID
                let curOpponent = game.homeTeamID == teamID ? game.awayTeamID : game.homeTeamID
                isSeriesStart = prevOpponent != curOpponent
            }

            cell.configure(with: game, teamID: teamID, isNextGame: isNext, isSeriesStart: isSeriesStart)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: RosterPlayerCell.reuseIdentifier, for: indexPath) as! RosterPlayerCell
            cell.configure(with: roster[indexPath.row])
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView === self.tableView {
            let game = scheduleSections[indexPath.section].games[indexPath.row]
            let detailVC = GameDetailViewController(game: game)
            detailVC.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(detailVC, animated: true)
        } else {
            let player = roster[indexPath.row]
            let playerVC = PlayerDetailViewController(playerId: player.id, fullName: player.fullName, position: player.position ?? "")
            present(playerVC, animated: true)
        }
    }
}
