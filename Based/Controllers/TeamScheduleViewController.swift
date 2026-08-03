import UIKit

class TeamScheduleViewController: UIViewController {

    private let teamId: Int
    private let teamName: String
    private let scheduleDataSource: ScheduleDataSource
    private let rosterDataSource: RosterDataSource
    private var loadTask: Task<Void, Never>?

    private let statsContainer = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let rosterTableView = UITableView(frame: .zero, style: .plain)
    private let segmentedControl = UISegmentedControl(items: ["Schedule", "Roster"])
    private lazy var segmentedOverlay = PencilSegmentedOverlay(segmentedControl: segmentedControl)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    // Stats labels
    private let recordLabel = UILabel()
    private let winBar = UIView()
    private let lossBar = UIView()
    private var winBarWidth: NSLayoutConstraint!
    private let statsRow1 = UIStackView()
    private let statsRow2 = UIStackView()
    private let managerLabel = UILabel()

    private var pencilColor: UIColor { AppColors.pencil }

    init(teamId: Int, teamName: String) {
        self.teamId = teamId
        self.teamName = teamName
        self.scheduleDataSource = ScheduleDataSource(teamId: teamId, teamName: teamName)
        self.rosterDataSource = RosterDataSource()
        super.init(nibName: nil, bundle: nil)
        
        setupDataSourceCallbacks()
    }

    private func setupDataSourceCallbacks() {
        scheduleDataSource.onGameSelected = { [weak self] game in
            let detailVC = GameDetailViewController(game: MLBLeagueProvider.makeLeagueGame(game))
            detailVC.hidesBottomBarWhenPushed = true
            self?.navigationController?.pushViewController(detailVC, animated: true)
        }
        
        rosterDataSource.onPlayerSelected = { [weak self] player in
            guard let playerId = player.person?.id, let fullName = player.person?.fullName else { return }
            let playerVC = PlayerDetailViewController(playerId: String(playerId), fullName: fullName, position: player.position?.name ?? "")
            self?.present(playerVC, animated: true)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = nickname(for: teamName)
        view.backgroundColor = AppColors.paper

        setupSegmentedControl()
        setupStatsView()
        setupTableView()
        setupRosterTableView()
        setupLoadingViews()

        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: TeamScheduleViewController, _) in
            self.setupNavigationBar()
            self.updateStatsColors()
            self.tableView.reloadData()
        }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: TeamScheduleViewController, _) in
            self.setupNavigationBar()
            self.updateStatsColors()
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
        updateStatsColors()
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
        
        updateSegmentedControlStyle()

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

    private func updateSegmentedControlStyle() {
        let font = AppFont.patrick(18, textStyle: .body, compatibleWith: traitCollection)
        let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: pencilColor.withAlphaComponent(0.6)]
        let selectedAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: pencilColor]
        segmentedControl.setTitleTextAttributes(normalAttrs, for: .normal)
        segmentedControl.setTitleTextAttributes(selectedAttrs, for: .selected)
    }

    private func setupStatsView() {
        let pc = pencilColor
        statsContainer.backgroundColor = AppColors.paper
        statsContainer.isHidden = true

        recordLabel.numberOfLines = 1

        // W/L bar with labels
        let barRow = UIView()

        let winLabel = UILabel()
        winLabel.text = "W"
        winLabel.font = AppFont.ibmPlexCondensed(11, textStyle: .caption2)
        winLabel.textColor = pc.withAlphaComponent(0.4)

        let lossLabel = UILabel()
        lossLabel.text = "L"
        lossLabel.font = AppFont.ibmPlexCondensed(11, textStyle: .caption2)
        lossLabel.textColor = pc.withAlphaComponent(0.4)
        lossLabel.textAlignment = .right

        let barContainer = UIView()
        barContainer.layer.cornerRadius = 3
        barContainer.clipsToBounds = true
        barContainer.backgroundColor = pc.withAlphaComponent(0.08)

        winBar.backgroundColor = .systemGreen.withAlphaComponent(0.6)
        winBar.layer.cornerRadius = 3
        lossBar.backgroundColor = .systemRed.withAlphaComponent(0.4)

        barContainer.addSubview(winBar)
        barContainer.addSubview(lossBar)
        winBar.translatesAutoresizingMaskIntoConstraints = false
        lossBar.translatesAutoresizingMaskIntoConstraints = false
        winBarWidth = winBar.widthAnchor.constraint(equalTo: barContainer.widthAnchor, multiplier: 0.5)
        NSLayoutConstraint.activate([
            winBar.leadingAnchor.constraint(equalTo: barContainer.leadingAnchor),
            winBar.topAnchor.constraint(equalTo: barContainer.topAnchor),
            winBar.bottomAnchor.constraint(equalTo: barContainer.bottomAnchor),
            winBarWidth,
            lossBar.trailingAnchor.constraint(equalTo: barContainer.trailingAnchor),
            lossBar.topAnchor.constraint(equalTo: barContainer.topAnchor),
            lossBar.bottomAnchor.constraint(equalTo: barContainer.bottomAnchor),
            lossBar.leadingAnchor.constraint(equalTo: winBar.trailingAnchor, constant: 2),
        ])

        for v: UIView in [winLabel, barContainer, lossLabel] {
            barRow.addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            winLabel.leadingAnchor.constraint(equalTo: barRow.leadingAnchor),
            winLabel.centerYAnchor.constraint(equalTo: barRow.centerYAnchor),

            barContainer.leadingAnchor.constraint(equalTo: winLabel.trailingAnchor, constant: 4),
            barContainer.trailingAnchor.constraint(equalTo: lossLabel.leadingAnchor, constant: -4),
            barContainer.topAnchor.constraint(equalTo: barRow.topAnchor),
            barContainer.bottomAnchor.constraint(equalTo: barRow.bottomAnchor),
            barContainer.heightAnchor.constraint(equalToConstant: 6),

            lossLabel.trailingAnchor.constraint(equalTo: barRow.trailingAnchor),
            lossLabel.centerYAnchor.constraint(equalTo: barRow.centerYAnchor),
        ])

        // Stats rows
        for row in [statsRow1, statsRow2] {
            row.axis = .horizontal
            row.distribution = .fillEqually
        }

        managerLabel.numberOfLines = 1
        managerLabel.textAlignment = .right
        managerLabel.isHidden = true

        let divider = UIView()
        divider.backgroundColor = pc.withAlphaComponent(0.1)
        divider.tag = 100

        for v: UIView in [recordLabel, managerLabel, barRow, statsRow1, statsRow2, divider] {
            statsContainer.addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        let pad: CGFloat = 16
        NSLayoutConstraint.activate([
            recordLabel.topAnchor.constraint(equalTo: statsContainer.topAnchor, constant: 8),
            recordLabel.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor, constant: pad),

            managerLabel.lastBaselineAnchor.constraint(equalTo: recordLabel.lastBaselineAnchor),
            managerLabel.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor, constant: -pad),
            managerLabel.leadingAnchor.constraint(greaterThanOrEqualTo: recordLabel.trailingAnchor, constant: 8),

            barRow.topAnchor.constraint(equalTo: recordLabel.bottomAnchor, constant: 8),
            barRow.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor, constant: pad),
            barRow.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor, constant: -pad),

            statsRow1.topAnchor.constraint(equalTo: barRow.bottomAnchor, constant: 12),
            statsRow1.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor, constant: pad),
            statsRow1.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor, constant: -pad),

            statsRow2.topAnchor.constraint(equalTo: statsRow1.bottomAnchor, constant: 8),
            statsRow2.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor, constant: pad),
            statsRow2.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor, constant: -pad),

            divider.topAnchor.constraint(equalTo: statsRow2.bottomAnchor, constant: 12),
            divider.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),
            divider.bottomAnchor.constraint(equalTo: statsContainer.bottomAnchor),
        ])

        view.addSubview(statsContainer)
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statsContainer.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            statsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupTableView() {
        tableView.dataSource = scheduleDataSource
        tableView.delegate = scheduleDataSource
        tableView.backgroundColor = AppColors.paper
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.register(TeamGameCell.self, forCellReuseIdentifier: TeamGameCell.reuseIdentifier)

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: statsContainer.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupRosterTableView() {
        rosterTableView.dataSource = rosterDataSource
        rosterTableView.delegate = rosterDataSource
        rosterTableView.backgroundColor = AppColors.paper
        rosterTableView.separatorStyle = .none
        rosterTableView.rowHeight = UITableView.automaticDimension
        rosterTableView.estimatedRowHeight = 60
        rosterTableView.register(RosterPlayerCell.self, forCellReuseIdentifier: RosterPlayerCell.reuseIdentifier)
        rosterTableView.isHidden = true

        view.addSubview(rosterTableView)
        rosterTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rosterTableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            rosterTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rosterTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rosterTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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

        let season = Calendar.current.component(.year, from: Date())

        loadTask = Task {
            do {
                async let scheduleFetch = MLBAPIClient.shared.fetchTeamSchedule(teamId: teamId, season: season)
                async let managerFetch = MLBAPIClient.shared.fetchManagerName(teamId: teamId)

                let fetched = try await scheduleFetch
                let managerName = try? await managerFetch
                guard !Task.isCancelled else { return }

                self.scheduleDataSource.update(with: fetched)
                self.loadingIndicator.stopAnimating()
                self.populateStats(from: fetched)
                self.populateManager(managerName)
                self.statsContainer.isHidden = false
                self.tableView.reloadData()
                self.scrollToNextGame(animated: false)
            } catch {
                guard !Task.isCancelled else { return }
                self.loadingIndicator.stopAnimating()
                if self.scheduleDataSource.sections.isEmpty {
                    self.errorLabel.text = "Couldn't load schedule"
                    self.errorLabel.isHidden = false
                    self.retryButton.isHidden = false
                }
            }
        }
    }

    @objc private func modeChanged() {
        let isSchedule = segmentedControl.selectedSegmentIndex == 0
        tableView.isHidden = !isSchedule
        statsContainer.isHidden = !isSchedule
        rosterTableView.isHidden = isSchedule
        
        if !isSchedule && rosterDataSource.rosterSections.isEmpty {
            loadRoster()
        }
    }

    private func loadRoster() {
        loadingIndicator.startAnimating()
        Task {
            do {
                let entries = try await MLBAPIClient.shared.fetchTeamRoster(teamId: teamId)
                self.rosterDataSource.update(with: entries)
                self.loadingIndicator.stopAnimating()
                self.rosterTableView.reloadData()
            } catch {
                self.loadingIndicator.stopAnimating()
            }
        }
    }

    private func buildRosterSections(from entries: [RosterEntry]) -> [RosterDataSource.RosterSection] {
        var pitchers: [RosterEntry] = []
        var catchers: [RosterEntry] = []
        var infielders: [RosterEntry] = []
        var outfielders: [RosterEntry] = []
        var dhs: [RosterEntry] = []
        
        for entry in entries {
            let type = entry.position?.type?.lowercased() ?? ""
            if type == "pitcher" { pitchers.append(entry) }
            else if type == "catcher" { catchers.append(entry) }
            else if type == "infielder" { infielders.append(entry) }
            else if type == "outfielder" { outfielders.append(entry) }
            else { dhs.append(entry) }
        }
        
        var result: [RosterDataSource.RosterSection] = []
        if !pitchers.isEmpty { result.append(RosterDataSource.RosterSection(title: "Pitchers", players: pitchers)) }
        if !catchers.isEmpty { result.append(RosterDataSource.RosterSection(title: "Catchers", players: catchers)) }
        if !infielders.isEmpty { result.append(RosterDataSource.RosterSection(title: "Infielders", players: infielders)) }
        if !outfielders.isEmpty { result.append(RosterDataSource.RosterSection(title: "Outfielders", players: outfielders)) }
        if !dhs.isEmpty { result.append(RosterDataSource.RosterSection(title: "Designated Hitters", players: dhs)) }
        return result
    }

    @objc private func retryTapped() {
        if segmentedControl.selectedSegmentIndex == 0 {
            loadSchedule()
        } else {
            loadRoster()
        }
    }

    private func scrollToNextGame(animated: Bool) {
        guard let ip = scheduleDataSource.nextGameIndexPath else { return }
        let targetRow = max(0, ip.row - 2)
        let targetIP = IndexPath(row: targetRow, section: ip.section)
        tableView.scrollToRow(at: targetIP, at: .top, animated: animated)
    }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        if scheduleDataSource.nextGameIndexPath != nil {
            scrollToNextGame(animated: true)
            return false
        }
        return true
    }

    // MARK: - Stats

    private struct TeamSeasonStats {
        let wins: Int
        let losses: Int
        let homeWins: Int
        let homeLosses: Int
        let awayWins: Int
        let awayLosses: Int
        let runsFor: Int
        let runsAgainst: Int
        let oneRunWins: Int
        let oneRunLosses: Int
        let currentStreak: Int
        let streakType: Character
        let bestWinStreak: Int
        let worstLossStreak: Int
        let last10Wins: Int
    }

    private func calculateSeasonStats(from games: [ScheduleGame]) -> TeamSeasonStats {
        let completed = games.filter { scheduleDataSource.gamePhase($0) == .completed }

        var wins = 0, losses = 0, homeW = 0, homeL = 0, awayW = 0, awayL = 0
        var runsFor = 0, runsAgainst = 0
        var oneRunW = 0, oneRunL = 0
        var streak = 0
        var streakType: Character = "W"
        var bestStreak = 0, worstStreak = 0
        var curWinStreak = 0, curLoseStreak = 0

        for game in completed {
            let isHome = game.teams.home.team.id == teamId
            let ts = isHome ? (game.teams.home.score ?? 0) : (game.teams.away.score ?? 0)
            let os = isHome ? (game.teams.away.score ?? 0) : (game.teams.home.score ?? 0)
            let won = ts > os

            runsFor += ts
            runsAgainst += os

            if won { wins += 1 } else { losses += 1 }
            if isHome {
                if won { homeW += 1 } else { homeL += 1 }
            } else {
                if won { awayW += 1 } else { awayL += 1 }
            }

            if Swift.abs(Int(ts) - Int(os)) == 1 {
                if won { oneRunW += 1 } else { oneRunL += 1 }
            }

            if won {
                curWinStreak += 1
                curLoseStreak = 0
                bestStreak = max(bestStreak, curWinStreak)
            } else {
                curLoseStreak += 1
                curWinStreak = 0
                worstStreak = max(worstStreak, curLoseStreak)
            }

            let current: Character = won ? "W" : "L"
            if current == streakType {
                streak += 1
            } else {
                streakType = current
                streak = 1
            }
        }

        // Last 10
        let last10 = completed.suffix(10)
        let last10W = last10.filter { game in
            let isHome = game.teams.home.team.id == teamId
            let ts = isHome ? (game.teams.home.score ?? 0) : (game.teams.away.score ?? 0)
            let os = isHome ? (game.teams.away.score ?? 0) : (game.teams.home.score ?? 0)
            return ts > os
        }.count

        return TeamSeasonStats(
            wins: wins,
            losses: losses,
            homeWins: homeW,
            homeLosses: homeL,
            awayWins: awayW,
            awayLosses: awayL,
            runsFor: runsFor,
            runsAgainst: runsAgainst,
            oneRunWins: oneRunW,
            oneRunLosses: oneRunL,
            currentStreak: streak,
            streakType: streakType,
            bestWinStreak: bestStreak,
            worstLossStreak: worstStreak,
            last10Wins: last10W
        )
    }

    private func populateStats(from games: [ScheduleGame]) {
        let stats = calculateSeasonStats(from: games)

        let total = stats.wins + stats.losses
        let pct = total > 0 ? String(format: ".%03d", stats.wins * 1000 / total) : ".000"
        let rd = stats.runsFor - stats.runsAgainst
        let rdStr = rd >= 0 ? "+\(rd)" : "\(rd)"

        let pc = pencilColor
        let teamColor = TeamColorProvider.color(for: teamName)

        // Record label
        let a = NSMutableAttributedString(
            string: "\(stats.wins)-\(stats.losses)",
            attributes: [.font: AppFont.permanent(38, textStyle: .largeTitle), .foregroundColor: teamColor]
        )
        a.append(NSAttributedString(
            string: "  \(pct)",
            attributes: [.font: AppFont.patrick(24, textStyle: .title2), .foregroundColor: pc.withAlphaComponent(0.45)]
        ))
        recordLabel.attributedText = a

        // Win/loss bar
        winBar.backgroundColor = teamColor.withAlphaComponent(0.7)
        lossBar.backgroundColor = pc.withAlphaComponent(0.15)
        if total > 0 {
            winBarWidth.isActive = false
            winBarWidth = winBar.widthAnchor.constraint(
                equalTo: winBar.superview!.widthAnchor,
                multiplier: CGFloat(stats.wins) / CGFloat(total)
            )
            winBarWidth.isActive = true
        }

        // Row 1: Home, Away, Streak, L10
        let row1Items: [(String, String)] = [
            ("HOME", "\(stats.homeWins)-\(stats.homeLosses)"),
            ("AWAY", "\(stats.awayWins)-\(stats.awayLosses)"),
            ("STRK", "\(stats.streakType)\(stats.currentStreak)"),
            ("L10", "\(stats.last10Wins)-\(10 - stats.last10Wins)"),
        ]

        // Row 2: Run diff, 1-Run, Best W, Worst L
        let row2Items: [(String, String)] = [
            ("RUN DIFF", rdStr),
            ("1-RUN", "\(stats.oneRunWins)-\(stats.oneRunLosses)"),
            ("BEST W", "\(stats.bestWinStreak)"),
            ("WORST L", "\(stats.worstLossStreak)"),
        ]

        // VoiceOver: record label reads as one element
        recordLabel.isAccessibilityElement = true
        recordLabel.accessibilityLabel = "\(stats.wins) wins, \(stats.losses) losses, \(pct)"

        // VoiceOver labels for stat columns are set in populateStatsRow
        let streakSpoken = stats.streakType == "W" ? "winning \(stats.currentStreak)" : "losing \(stats.currentStreak)"
        let row1Labels = [
            "Home: \(stats.homeWins) and \(stats.homeLosses)",
            "Away: \(stats.awayWins) and \(stats.awayLosses)",
            "Streak: \(streakSpoken)",
            "Last 10: \(stats.last10Wins) and \(10 - stats.last10Wins)",
        ]
        let row2Labels = [
            "Run differential: \(rdStr)",
            "One run games: \(stats.oneRunWins) and \(stats.oneRunLosses)",
            "Best win streak: \(stats.bestWinStreak)",
            "Worst loss streak: \(stats.worstLossStreak)",
        ]
        populateStatsRow(statsRow1, items: row1Items, accessibilityLabels: row1Labels)
        populateStatsRow(statsRow2, items: row2Items, accessibilityLabels: row2Labels)
    }

    private func populateManager(_ name: String?) {
        guard let name, !name.isEmpty else {
            managerLabel.isHidden = true
            return
        }
        let pc = pencilColor
        let attr = NSMutableAttributedString(
            string: "MGR  ",
            attributes: [.font: AppFont.ibmPlexCondensed(11, textStyle: .caption2), .foregroundColor: pc.withAlphaComponent(0.4)]
        )
        attr.append(NSAttributedString(
            string: name,
            attributes: [.font: AppFont.patrick(16, textStyle: .body), .foregroundColor: pc]
        ))
        managerLabel.attributedText = attr
        managerLabel.isHidden = false
        managerLabel.accessibilityLabel = "Manager: \(name)"
    }

    private func populateStatsRow(_ stack: UIStackView, items: [(String, String)], accessibilityLabels: [String]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let pc = pencilColor

        for (i, (label, value)) in items.enumerated() {
            let col = UIStackView()
            col.axis = .vertical
            col.alignment = .center
            col.spacing = 0
            col.isAccessibilityElement = true
            if i < accessibilityLabels.count {
                col.accessibilityLabel = accessibilityLabels[i]
            }

            let valueLabel = UILabel()
            valueLabel.text = value
            valueLabel.font = AppFont.patrick(20, textStyle: .title3)
            valueLabel.textColor = pc

            let titleLabel = UILabel()
            titleLabel.text = label
            titleLabel.font = AppFont.ibmPlexCondensed(13, textStyle: .caption1)
            titleLabel.textColor = pc.withAlphaComponent(0.4)

            col.addArrangedSubview(valueLabel)
            col.addArrangedSubview(titleLabel)
            stack.addArrangedSubview(col)
        }
    }

    private func updateStatsColors() {
        let pc = pencilColor
        updateSegmentedControlStyle()
        segmentedOverlay.setNeedsLayout()
        statsContainer.viewWithTag(100)?.backgroundColor = pc.withAlphaComponent(0.1)
        // Just reload stats from sections data
        let allGames = scheduleDataSource.sections.flatMap { $0.games }
        if !allGames.isEmpty {
            populateStats(from: allGames)
        }
    }

    private func nickname(for teamName: String) -> String {
        let parts = teamName.split(separator: " ")
        if parts.count >= 2 {
            let last = String(parts.last!)
            if ["Blue", "White", "Red"].contains(String(parts[parts.count - 2])) && parts.count >= 3 {
                return "\(parts[parts.count - 2]) \(last)"
            }
            return last
        }
        return teamName
    }
}
