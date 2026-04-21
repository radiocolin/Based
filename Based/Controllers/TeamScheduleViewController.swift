import UIKit

class TeamScheduleViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let teamId: Int
    private let teamName: String
    private var sections: [MonthSection] = []
    private var nextGameIndexPath: IndexPath?
    private var loadTask: Task<Void, Never>?

    private let statsContainer = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
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

    private var pencilColor: UIColor { AppColors.pencil }

    private struct MonthSection {
        let title: String
        let games: [ScheduleGame]
    }

    init(teamId: Int, teamName: String) {
        self.teamId = teamId
        self.teamName = teamName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = nickname(for: teamName)
        view.backgroundColor = AppColors.paper

        setupStatsView()
        setupTableView()
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

    private func setupStatsView() {
        let pc = pencilColor
        statsContainer.backgroundColor = AppColors.paper
        statsContainer.isHidden = true

        recordLabel.numberOfLines = 1

        // W/L bar with labels
        let barRow = UIView()

        let winLabel = UILabel()
        winLabel.text = "W"
        winLabel.font = AppFont.patrick(11, textStyle: .caption2)
        winLabel.textColor = .systemGreen

        let lossLabel = UILabel()
        lossLabel.text = "L"
        lossLabel.font = AppFont.patrick(11, textStyle: .caption2)
        lossLabel.textColor = .systemRed
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

        let divider = UIView()
        divider.backgroundColor = pc.withAlphaComponent(0.1)
        divider.tag = 100

        for v: UIView in [recordLabel, barRow, statsRow1, statsRow2, divider] {
            statsContainer.addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        let pad: CGFloat = 16
        NSLayoutConstraint.activate([
            recordLabel.topAnchor.constraint(equalTo: statsContainer.topAnchor, constant: 8),
            recordLabel.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor, constant: pad),
            recordLabel.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor, constant: -pad),

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
            statsContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            statsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
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

    private func setupLoadingViews() {
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = pencilColor
        loadingIndicator.accessibilityElementsHidden = true

        errorLabel.font = AppFont.patrick(20, textStyle: .title3, compatibleWith: traitCollection)
        errorLabel.textColor = pencilColor.withAlphaComponent(0.5)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        retryButton.setTitle("Tap to retry", for: .normal)
        retryButton.titleLabel?.font = AppFont.patrick(18, textStyle: .body, compatibleWith: traitCollection)
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
                let fetched = try await MLBAPIClient.shared.fetchTeamSchedule(teamId: teamId, season: season)
                guard !Task.isCancelled else { return }

                let sorted = fetched.sorted { scheduleDate(from: $0.gameDate) < scheduleDate(from: $1.gameDate) }
                self.sections = buildMonthSections(from: sorted)
                self.nextGameIndexPath = findNextGameIndexPath()
                self.loadingIndicator.stopAnimating()
                self.populateStats(from: sorted)
                self.statsContainer.isHidden = false
                self.tableView.reloadData()
                self.scrollToNextGame(animated: false)
            } catch {
                guard !Task.isCancelled else { return }
                self.loadingIndicator.stopAnimating()
                if self.sections.isEmpty {
                    self.errorLabel.text = "Couldn't load schedule"
                    self.errorLabel.isHidden = false
                    self.retryButton.isHidden = false
                }
            }
        }
    }

    @objc private func retryTapped() {
        loadSchedule()
    }

    private func scrollToNextGame(animated: Bool) {
        guard let ip = nextGameIndexPath else { return }
        let targetRow = max(0, ip.row - 2)
        let targetIP = IndexPath(row: targetRow, section: ip.section)
        tableView.scrollToRow(at: targetIP, at: .top, animated: animated)
    }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        if nextGameIndexPath != nil {
            scrollToNextGame(animated: true)
            return false
        }
        return true
    }

    // MARK: - Stats

    private func populateStats(from games: [ScheduleGame]) {
        let completed = games.filter { gamePhase($0) == .completed }

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

            if abs(ts - os) == 1 {
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

        let total = wins + losses
        let pct = total > 0 ? String(format: ".%03d", wins * 1000 / total) : ".000"
        let rd = runsFor - runsAgainst
        let rdStr = rd >= 0 ? "+\(rd)" : "\(rd)"

        let pc = pencilColor
        let teamColor = TeamColorProvider.color(for: teamName)

        // Record label
        let a = NSMutableAttributedString(
            string: "\(wins)-\(losses)",
            attributes: [.font: AppFont.permanent(38, textStyle: .largeTitle), .foregroundColor: pc]
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
                multiplier: CGFloat(wins) / CGFloat(total)
            )
            winBarWidth.isActive = true
        }

        // Row 1: Home, Away, Streak, L10
        let row1Items: [(String, String)] = [
            ("Home", "\(homeW)-\(homeL)"),
            ("Away", "\(awayW)-\(awayL)"),
            ("Strk", "\(streakType)\(streak)"),
            ("L10", "\(last10W)-\(10 - last10W)"),
        ]

        // Row 2: Run diff, 1-Run, Best W, Worst L
        let row2Items: [(String, String)] = [
            ("Run Diff", rdStr),
            ("1-Run", "\(oneRunW)-\(oneRunL)"),
            ("Best W", "\(bestStreak)"),
            ("Worst L", "\(worstStreak)"),
        ]

        // VoiceOver: record label reads as one element
        recordLabel.isAccessibilityElement = true
        recordLabel.accessibilityLabel = "\(wins) wins, \(losses) losses, \(pct)"

        // VoiceOver labels for stat columns are set in populateStatsRow
        let streakSpoken = streakType == "W" ? "winning \(streak)" : "losing \(streak)"
        let row1Labels = [
            "Home: \(homeW) and \(homeL)",
            "Away: \(awayW) and \(awayL)",
            "Streak: \(streakSpoken)",
            "Last 10: \(last10W) and \(10 - last10W)",
        ]
        let row2Labels = [
            "Run differential: \(rdStr)",
            "One run games: \(oneRunW) and \(oneRunL)",
            "Best win streak: \(bestStreak)",
            "Worst loss streak: \(worstStreak)",
        ]
        populateStatsRow(statsRow1, items: row1Items, accessibilityLabels: row1Labels)
        populateStatsRow(statsRow2, items: row2Items, accessibilityLabels: row2Labels)
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
            titleLabel.font = AppFont.patrick(13, textStyle: .caption1)
            titleLabel.textColor = pc.withAlphaComponent(0.4)

            col.addArrangedSubview(valueLabel)
            col.addArrangedSubview(titleLabel)
            stack.addArrangedSubview(col)
        }
    }

    private func updateStatsColors() {
        let pc = pencilColor
        statsContainer.viewWithTag(100)?.backgroundColor = pc.withAlphaComponent(0.1)
        // Just reload stats from sections data
        let allGames = sections.flatMap { $0.games }
        if !allGames.isEmpty {
            populateStats(from: allGames)
        }
    }

    // MARK: - Month Grouping

    private func buildMonthSections(from games: [ScheduleGame]) -> [MonthSection] {
        let cal = Calendar.current
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"

        var sectionMap: [(key: Int, title: String, games: [ScheduleGame])] = []
        for game in games {
            let date = scheduleDate(from: game.gameDate)
            let month = cal.component(.month, from: date)
            if let last = sectionMap.last, last.key == month {
                sectionMap[sectionMap.count - 1].games.append(game)
            } else {
                let title = monthFormatter.string(from: date)
                sectionMap.append((key: month, title: title, games: [game]))
            }
        }
        return sectionMap.map { MonthSection(title: $0.title, games: $0.games) }
    }

    // MARK: - Helpers

    private func scheduleDate(from isoDate: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoDate) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: isoDate) ?? .distantFuture
    }

    private func findNextGameIndexPath() -> IndexPath? {
        for (s, section) in sections.enumerated() {
            for (r, game) in section.games.enumerated() {
                let phase = gamePhase(game)
                if phase == .future || phase == .live {
                    return IndexPath(row: r, section: s)
                }
            }
        }
        return nil
    }

    func gamePhase(_ game: ScheduleGame) -> GamePhase {
        let state = game.status.detailedState.lowercased()
        let code = game.status.statusCode?.lowercased() ?? ""

        if state == "final" || state == "game over" || state == "completed early" || code == "f" || code == "o" {
            return .completed
        }
        if state == "in progress" || state.hasPrefix("top ") || state.hasPrefix("bottom ") ||
            state.hasPrefix("middle ") || state.hasPrefix("mid ") || state.hasPrefix("end ") {
            return .live
        }
        if state.contains("delay") || state.contains("suspend") || state.contains("postpon") {
            return .delayed
        }
        return .future
    }

    enum GamePhase {
        case completed, live, delayed, future
    }

    private func abbreviation(for teamName: String) -> String {
        let map: [String: String] = ["Arizona Diamondbacks": "ARI", "Atlanta Braves": "ATL", "Baltimore Orioles": "BAL", "Boston Red Sox": "BOS", "Chicago Cubs": "CHC", "Chicago White Sox": "CWS", "Cincinnati Reds": "CIN", "Cleveland Guardians": "CLE", "Colorado Rockies": "COL", "Detroit Tigers": "DET", "Houston Astros": "HOU", "Kansas City Royals": "KC", "Los Angeles Angels": "LAA", "Los Angeles Dodgers": "LAD", "Miami Marlins": "MIA", "Milwaukee Brewers": "MIL", "Minnesota Twins": "MIN", "New York Mets": "NYM", "New York Yankees": "NYY", "Oakland Athletics": "OAK", "Philadelphia Phillies": "PHI", "Pittsburgh Pirates": "PIT", "San Diego Padres": "SD", "San Francisco Giants": "SF", "Seattle Mariners": "SEA", "St. Louis Cardinals": "STL", "Tampa Bay Rays": "TB", "Texas Rangers": "TEX", "Toronto Blue Jays": "TOR", "Washington Nationals": "WSH"]
        return map[teamName] ?? String(teamName.prefix(3)).uppercased()
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

    // MARK: - Table View

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].games.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = AppFont.permanent(16, textStyle: .headline, compatibleWith: traitCollection)
        header.textLabel?.textColor = pencilColor.withAlphaComponent(0.6)
        header.contentView.backgroundColor = AppColors.paper
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TeamGameCell.reuseIdentifier, for: indexPath) as! TeamGameCell
        let game = sections[indexPath.section].games[indexPath.row]
        let isNext = indexPath == nextGameIndexPath

        var isSeriesStart = indexPath.row == 0
        if indexPath.row > 0 {
            let prev = sections[indexPath.section].games[indexPath.row - 1]
            let prevOpponent = prev.teams.home.team.id == teamId ? prev.teams.away.team.id : prev.teams.home.team.id
            let curOpponent = game.teams.home.team.id == teamId ? game.teams.away.team.id : game.teams.home.team.id
            isSeriesStart = prevOpponent != curOpponent
        }

        cell.configure(with: game, teamId: teamId, phase: gamePhase(game), isNextGame: isNext, isSeriesStart: isSeriesStart)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let game = sections[indexPath.section].games[indexPath.row]

        let detailVC = GameDetailViewController(gamePk: game.gamePk, games: [game])
        detailVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - TeamGameCell

private class TeamGameCell: UITableViewCell {
    static let reuseIdentifier = "TeamGameCell"

    private let opponentLabel = UILabel()
    private let detailLabel = UILabel()
    private let rightLabel = UILabel()
    private let statusBadge = UILabel()
    private let chevronView = UIImageView()
    private let linesLayer = CAShapeLayer()
    private let seriesDivider = UIView()
    private var topConstraint: NSLayoutConstraint!

    private var pencilColor: UIColor { AppColors.pencil }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        backgroundColor = AppColors.paper
        opponentLabel.alpha = 1.0
        detailLabel.alpha = 1.0
    }

    private func setupUI() {
        backgroundColor = AppColors.paper
        contentView.layer.addSublayer(linesLayer)

        opponentLabel.font = AppFont.permanent(20, textStyle: .body)
        opponentLabel.adjustsFontForContentSizeCategory = true
        opponentLabel.numberOfLines = 0

        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.numberOfLines = 0

        rightLabel.font = AppFont.patrick(22, textStyle: .title3)
        rightLabel.textAlignment = .right
        rightLabel.adjustsFontForContentSizeCategory = true
        rightLabel.numberOfLines = 0
        rightLabel.setContentHuggingPriority(.required, for: .horizontal)
        rightLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        statusBadge.font = AppFont.patrick(12, textStyle: .caption1)
        statusBadge.textAlignment = .center
        statusBadge.adjustsFontForContentSizeCategory = true
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)
        statusBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        chevronView.image = UIImage.pencilStyledIcon(
            named: "chevron.forward",
            color: pencilColor.withAlphaComponent(0.5),
            size: CGSize(width: 10, height: 10)
        )
        chevronView.contentMode = .center

        seriesDivider.isHidden = true

        for v: UIView in [seriesDivider, opponentLabel, detailLabel, rightLabel, statusBadge, chevronView] {
            contentView.addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        let pad: CGFloat = 16
        topConstraint = opponentLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10)
        NSLayoutConstraint.activate([
            seriesDivider.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            seriesDivider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            seriesDivider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            seriesDivider.heightAnchor.constraint(equalToConstant: 1),

            // Status badge on the left
            statusBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            statusBadge.topAnchor.constraint(equalTo: opponentLabel.topAnchor),

            // Top line: opponent
            topConstraint,
            opponentLabel.leadingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: 6),
            opponentLabel.trailingAnchor.constraint(lessThanOrEqualTo: rightLabel.leadingAnchor, constant: -8),

            // Right side: score/time aligned to the two-line block
            rightLabel.topAnchor.constraint(greaterThanOrEqualTo: opponentLabel.topAnchor),
            rightLabel.bottomAnchor.constraint(lessThanOrEqualTo: detailLabel.bottomAnchor),
            {
                let c = rightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
                c.priority = .defaultHigh
                return c
            }(),
            rightLabel.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -8),

            // Chevron
            chevronView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            chevronView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 10),

            // Bottom line: detail
            detailLabel.topAnchor.constraint(equalTo: opponentLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: opponentLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: rightLabel.leadingAnchor, constant: -8),
            detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    func configure(with game: ScheduleGame, teamId: Int, phase: TeamScheduleViewController.GamePhase, isNextGame: Bool, isSeriesStart: Bool) {
        if isSeriesStart {
            topConstraint.constant = 20
            seriesDivider.isHidden = false
            seriesDivider.backgroundColor = pencilColor.withAlphaComponent(0.1)
        } else {
            topConstraint.constant = 10
            seriesDivider.isHidden = true
        }

        let isHome = game.teams.home.team.id == teamId
        let opponent = isHome ? game.teams.away.team.name ?? "TBD" : game.teams.home.team.name ?? "TBD"
        let prefix = isHome ? "vs" : "@"

        let gameDate = parseDate(game.gameDate)

        opponentLabel.text = "\(prefix) \(abbreviation(for: opponent))"
        opponentLabel.textColor = TeamColorProvider.color(for: opponent)

        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        let dateStr = df.string(from: gameDate)
        let detailFont = AppFont.patrick(15, textStyle: .subheadline)
        let detail = NSMutableAttributedString(
            string: dateStr,
            attributes: [.font: detailFont, .foregroundColor: pencilColor.withAlphaComponent(0.6)]
        )
        if let venue = game.venue?.name {
            detail.append(NSAttributedString(
                string: " · \(venue)",
                attributes: [.font: detailFont, .foregroundColor: pencilColor.withAlphaComponent(0.35)]
            ))
        }
        detailLabel.attributedText = detail

        backgroundColor = isNextGame ? AppColors.selected : AppColors.paper

        let pc = pencilColor
        let tf = DateFormatter()
        tf.dateFormat = "h:mm a"

        switch phase {
        case .completed:
            let teamScore: Int
            let opponentScore: Int
            if isHome {
                teamScore = game.teams.home.score ?? 0
                opponentScore = game.teams.away.score ?? 0
            } else {
                teamScore = game.teams.away.score ?? 0
                opponentScore = game.teams.home.score ?? 0
            }
            let won = teamScore > opponentScore
            let wl = won ? "W" : (teamScore < opponentScore ? "L" : "T")
            var scoreText: String
            if let currentInning = game.linescore?.currentInning,
               currentInning > (game.linescore?.scheduledInnings ?? 9) {
                scoreText = "\(wl)/\(currentInning) \(teamScore)-\(opponentScore)"
            } else {
                scoreText = "\(wl) \(teamScore)-\(opponentScore)"
            }
            rightLabel.text = scoreText
            rightLabel.textColor = won ? .systemGreen : .systemRed
            opponentLabel.alpha = 0.7
            detailLabel.alpha = 0.7
            statusBadge.text = ""

        case .live:
            let teamScore: Int
            let opponentScore: Int
            if isHome {
                teamScore = game.teams.home.score ?? 0
                opponentScore = game.teams.away.score ?? 0
            } else {
                teamScore = game.teams.away.score ?? 0
                opponentScore = game.teams.home.score ?? 0
            }
            rightLabel.text = "\(teamScore)-\(opponentScore)"
            rightLabel.textColor = pc
            statusBadge.text = "LIVE"
            statusBadge.textColor = .systemRed
            opponentLabel.alpha = 1.0
            detailLabel.alpha = 1.0

        case .delayed:
            rightLabel.text = tf.string(from: gameDate)
            rightLabel.textColor = pc.withAlphaComponent(0.5)
            statusBadge.text = "PPD"
            statusBadge.textColor = pc.withAlphaComponent(0.5)
            opponentLabel.alpha = 0.7
            detailLabel.alpha = 0.7

        case .future:
            rightLabel.text = tf.string(from: gameDate)
            rightLabel.textColor = pc.withAlphaComponent(0.5)
            if isNextGame {
                statusBadge.text = "NEXT"
                statusBadge.textColor = .systemRed
            } else {
                statusBadge.text = ""
            }
            opponentLabel.alpha = 1.0
            detailLabel.alpha = 1.0
        }

        isAccessibilityElement = true
        accessibilityTraits = .button
        let spokenOpponent = "\(prefix) \(opponent)"
        accessibilityLabel = AccessibilitySupport.joined([
            statusBadge.text,
            spokenOpponent,
            detailLabel.attributedText?.string,
            rightLabel.text,
        ])
    }

    private func parseDate(_ isoDate: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoDate) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: isoDate) ?? .distantFuture
    }

    private func abbreviation(for teamName: String) -> String {
        let map: [String: String] = ["Arizona Diamondbacks": "ARI", "Atlanta Braves": "ATL", "Baltimore Orioles": "BAL", "Boston Red Sox": "BOS", "Chicago Cubs": "CHC", "Chicago White Sox": "CWS", "Cincinnati Reds": "CIN", "Cleveland Guardians": "CLE", "Colorado Rockies": "COL", "Detroit Tigers": "DET", "Houston Astros": "HOU", "Kansas City Royals": "KC", "Los Angeles Angels": "LAA", "Los Angeles Dodgers": "LAD", "Miami Marlins": "MIA", "Milwaukee Brewers": "MIL", "Minnesota Twins": "MIN", "New York Mets": "NYM", "New York Yankees": "NYY", "Oakland Athletics": "OAK", "Philadelphia Phillies": "PHI", "Pittsburgh Pirates": "PIT", "San Diego Padres": "SD", "San Francisco Giants": "SF", "Seattle Mariners": "SEA", "St. Louis Cardinals": "STL", "Tampa Bay Rays": "TB", "Texas Rangers": "TEX", "Toronto Blue Jays": "TOR", "Washington Nationals": "WSH"]
        return map[teamName] ?? String(teamName.prefix(3)).uppercased()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = contentView.bounds
        let path = UIBezierPath()
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 16, y: b.maxY), to: CGPoint(x: b.maxX - 16, y: b.maxY), jitter: 0.3))
        linesLayer.path = path.cgPath
        linesLayer.strokeColor = pencilColor.withAlphaComponent(0.15).cgColor
        linesLayer.lineWidth = 0.5
        linesLayer.fillColor = UIColor.clear.cgColor
    }
}
