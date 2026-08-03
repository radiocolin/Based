import UIKit
import TipKit

class StandingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private enum StandingsMode: Int {
        case regularSeason = 0
        case wildcard = 1
    }

    private var provider: LeagueProvider { LeagueRegistry.shared.provider(for: LeagueSelectionStore.shared.selectedLeague) }

    private var currentMode: StandingsMode = .regularSeason
    private var sections: [StandingsSection] = []
    private var cachedSections: [StandingsMode: [StandingsSection]] = [:]
    private var loadTask: Task<Void, Never>?

    private let segmentedControl = UISegmentedControl(items: ["Division", "Wildcard"])
    private lazy var segmentedOverlay = PencilSegmentedOverlay(segmentedControl: segmentedControl)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var tableViewTopConstraint: NSLayoutConstraint!
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    private var pencilColor: UIColor { AppColors.pencil }

    private let standingsModeTip = StandingsModeTip()
    private var tipObservationTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Standings"
        view.backgroundColor = AppColors.paper

        setupSegmentedControl()
        setupTableView()
        setupLoadingViews()
        applyModeAvailability()

        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(leagueSelectionChanged), name: LeagueSelectionStore.selectionDidChangeNotification, object: nil)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: StandingsViewController, _) in
            self.setupNavigationBar()
            self.updateSegmentedControlStyle()
            self.tableView.reloadData()
        }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: StandingsViewController, _) in
            self.setupNavigationBar()
            self.tableView.reloadData()
        }

        setupNavigationBar()
        loadStandings()
        observeTips()
    }

    private func observeTips() {
        guard tipObservationTask == nil else { return }
        tipObservationTask = Task { @MainActor in
            await observeTip(standingsModeTip) { [weak self] in
                self?.segmentedControl
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
    }

    @objc private func tintDidChange() {
        setupNavigationBar()
        updateSegmentedControlStyle()
        segmentedOverlay.setNeedsLayout()
        tableView.reloadData()
    }

    @objc private func leagueSelectionChanged() {
        setupNavigationBar()
        applyModeAvailability()
        cachedSections = [:]
        loadStandings()
    }

    deinit {
        loadTask?.cancel()
        tipObservationTask?.cancel()
    }

    // MARK: - UI Setup

    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        
        // Strip native styling
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

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = AppColors.paper
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.register(StandingsTeamCell.self, forCellReuseIdentifier: StandingsTeamCell.reuseIdentifier)
        tableView.register(StandingsSubHeaderCell.self, forCellReuseIdentifier: StandingsSubHeaderCell.reuseIdentifier)

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableViewTopConstraint = tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8)
        NSLayoutConstraint.activate([
            tableViewTopConstraint,
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    /// Leagues without a wild-card race (WPBL) never show the Division/Wildcard toggle at all —
    /// not just an empty second tab. Bidirectional and idempotent so switching leagues back and
    /// forth (via the nav-bar switcher) restores the toggle correctly, not just hides it once.
    private func applyModeAvailability() {
        if provider.supportsWildcardStandings {
            guard segmentedControl.isHidden else { return }
            segmentedControl.isHidden = false
            segmentedOverlay.isHidden = false
            tableViewTopConstraint.isActive = false
            tableViewTopConstraint = tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8)
            tableViewTopConstraint.isActive = true
        } else {
            guard !segmentedControl.isHidden else { return }
            segmentedControl.isHidden = true
            segmentedOverlay.isHidden = true
            currentMode = .regularSeason
            segmentedControl.selectedSegmentIndex = 0
            tableViewTopConstraint.isActive = false
            tableViewTopConstraint = tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
            tableViewTopConstraint.isActive = true
        }
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

    // MARK: - Data Loading

    private func loadStandings() {
        loadTask?.cancel()

        if let cached = cachedSections[currentMode] {
            sections = cached
            tableView.reloadData()
            return
        }

        loadingIndicator.startAnimating()
        errorLabel.isHidden = true
        retryButton.isHidden = true
        tableView.isHidden = true

        let mode = currentMode
        loadTask = Task {
            do {
                let fetched = mode == .wildcard
                    ? try await provider.fetchWildcardStandings()
                    : try await provider.fetchStandings()
                guard !Task.isCancelled else { return }

                self.cachedSections[mode] = fetched
                self.sections = fetched

                self.loadingIndicator.stopAnimating()
                self.tableView.isHidden = false
                self.tableView.reloadData()

                if UIAccessibility.isVoiceOverRunning {
                    UIAccessibility.post(notification: .screenChanged, argument: self.tableView)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.loadingIndicator.stopAnimating()
                if self.sections.isEmpty {
                    self.errorLabel.text = "Couldn't load standings"
                    self.errorLabel.isHidden = false
                    self.retryButton.isHidden = false
                    self.tableView.isHidden = true

                    if UIAccessibility.isVoiceOverRunning {
                        UIAccessibility.post(notification: .screenChanged, argument: self.errorLabel)
                    }
                }
            }
        }
    }

    @objc private func modeChanged() {
        standingsModeTip.invalidate(reason: .actionPerformed)
        currentMode = StandingsMode(rawValue: segmentedControl.selectedSegmentIndex) ?? .regularSeason
        loadStandings()
    }

    @objc private func retryTapped() {
        loadStandings()
    }

    // MARK: - Table View

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = sections[section].title else { return nil }
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

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        sections[section].title == nil ? 0 : UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        sections[section].title == nil ? 0 : 36
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row {
        case .subHeader(let name):
            let cell = tableView.dequeueReusableCell(withIdentifier: StandingsSubHeaderCell.reuseIdentifier, for: indexPath) as! StandingsSubHeaderCell
            cell.configure(with: name)
            return cell
        case .team(let teamRow):
            let cell = tableView.dequeueReusableCell(withIdentifier: StandingsTeamCell.reuseIdentifier, for: indexPath) as! StandingsTeamCell
            cell.configure(with: teamRow)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]

        switch row {
        case .team(let teamRow):
            guard let teamId = Int(teamRow.teamID) else { return }
            navigationItem.backBarButtonItem = UIBarButtonItem(title: "Standings", style: .plain, target: nil, action: nil)
            let scheduleVC = TeamScheduleViewController(teamId: teamId, teamName: teamRow.teamName)
            navigationController?.pushViewController(scheduleVC, animated: true)
        case .subHeader:
            break
        }
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let row = sections[indexPath.section].rows[indexPath.row]
        guard case .team(let teamRow) = row else { return nil }

        let league = provider.league
        let isFavorite = FavoritesService.shared.isFavorite(teamID: teamRow.teamID, league: league)
        let teamName = teamRow.teamName

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let favoriteAction = UIAction(
                title: isFavorite ? "Remove from Favorites" : "Add to Favorites",
                image: UIImage(systemName: isFavorite ? "star" : "star.fill")
            ) { _ in
                let feedback = UISelectionFeedbackGenerator()
                feedback.prepare()
                feedback.selectionChanged()
                FavoritesService.shared.toggleFavorite(teamID: teamRow.teamID, league: league)
            }

            return UIMenu(title: teamName, children: [favoriteAction])
        }
    }

    func tableView(_ tableView: UITableView, willDisplayContextMenu configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred()
    }
}

// MARK: - StandingsSubHeaderCell

private class StandingsSubHeaderCell: UITableViewCell {
    static let reuseIdentifier = "StandingsSubHeaderCell"
    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = AppColors.paper
        selectionStyle = .none
        
        nameLabel.font = AppFont.ibmPlexCondensed(16, textStyle: .headline)
        nameLabel.textColor = AppColors.pencil.withAlphaComponent(0.6)
        nameLabel.adjustsFontForContentSizeCategory = true
        
        contentView.addSubview(nameLabel)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }

    func configure(with name: String) {
        nameLabel.text = name
        accessibilityLabel = name
        accessibilityTraits = .header
    }
}

// MARK: - StandingsTeamCell

private class StandingsTeamCell: UITableViewCell {
    static let reuseIdentifier = "StandingsTeamCell"

    private let rankLabel = UILabel()
    private let nameLabel = UILabel()
    private let recordLabel = UILabel()
    private let pctLabel = UILabel()
    private let detailLabel = UILabel()
    private let chevronView = UIImageView()
    private let linesLayer = CAShapeLayer()

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
    }

    private func setupUI() {
        backgroundColor = AppColors.paper
        contentView.layer.addSublayer(linesLayer)

        rankLabel.font = AppFont.ibmPlexCondensed(14, textStyle: .caption1)
        rankLabel.textAlignment = .center
        rankLabel.setContentHuggingPriority(.required, for: .horizontal)
        rankLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        nameLabel.font = AppFont.ibmPlexCondensedBold(18, textStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 1

        recordLabel.font = AppFont.patrick(22, textStyle: .title3)
        recordLabel.textAlignment = .right
        recordLabel.adjustsFontForContentSizeCategory = true
        recordLabel.setContentHuggingPriority(.required, for: .horizontal)
        recordLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        pctLabel.font = AppFont.patrick(15, textStyle: .subheadline)
        pctLabel.textAlignment = .right
        pctLabel.adjustsFontForContentSizeCategory = true

        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.numberOfLines = 1

        chevronView.contentMode = .center

        let rightStack = UIStackView(arrangedSubviews: [recordLabel, pctLabel])
        rightStack.axis = .vertical
        rightStack.alignment = .trailing
        rightStack.spacing = 0

        for v: UIView in [rankLabel, nameLabel, detailLabel, rightStack, chevronView] {
            contentView.addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        let pad: CGFloat = 16
        NSLayoutConstraint.activate([
            rankLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            rankLabel.firstBaselineAnchor.constraint(equalTo: nameLabel.firstBaselineAnchor),
            rankLabel.widthAnchor.constraint(equalToConstant: 20),

            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: rankLabel.trailingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -8),

            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -8),
            detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            rightStack.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -8),
            rightStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            chevronView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            chevronView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 10),
        ])
    }

    func configure(with row: StandingsTeamRow) {
        let pc = pencilColor
        configureBasicTeamInfo(row: row, pc: pc)
        configureDetailStats(row: row, pc: pc)
        configureAccessibilityInfo(row: row)
    }

    private func configureBasicTeamInfo(row: StandingsTeamRow, pc: UIColor) {
        rankLabel.text = row.rank
        rankLabel.textColor = pc.withAlphaComponent(0.4)

        nameLabel.text = nickname(for: row.teamName)
        nameLabel.textColor = TeamColorProvider.color(for: row.teamName)

        recordLabel.text = "\(row.wins)-\(row.losses)"
        recordLabel.textColor = pc

        pctLabel.text = row.winPercentage.isEmpty ? ".000" : row.winPercentage
        pctLabel.textColor = pc.withAlphaComponent(0.45)

        chevronView.image = UIImage.pencilStyledIcon(
            named: "chevron.forward",
            color: pc.withAlphaComponent(0.3),
            size: CGSize(width: 10, height: 10)
        )
    }

    private func configureDetailStats(row: StandingsTeamRow, pc: UIColor) {
        let detailAttr = NSMutableAttributedString()
        let labelFont = AppFont.ibmPlexCondensed(12, textStyle: .caption1)
        let statFont = AppFont.patrick(14, textStyle: .caption1)
        let labelColor = pc.withAlphaComponent(0.5)
        let statColor = pc

        func addStat(_ label: String, value: String) {
            if !detailAttr.string.isEmpty {
                detailAttr.append(NSAttributedString(string: "   ", attributes: [.font: labelFont]))
            }
            detailAttr.append(NSAttributedString(string: label, attributes: [.font: labelFont, .foregroundColor: labelColor]))
            detailAttr.append(NSAttributedString(string: " ", attributes: [.font: labelFont]))
            detailAttr.append(NSAttributedString(string: value, attributes: [.font: statFont, .foregroundColor: statColor]))
        }

        if let wcgb = row.wildCardGamesBack { addStat("WCGB", value: wcgb) }
        if let gb = row.gamesBack { addStat("GB", value: gb) }
        if let l10 = row.lastTen { addStat("L10", value: l10) }
        if let streak = row.streak { addStat("STRK", value: streak) }
        if let rd = row.runDifferential { addStat("RD", value: rd >= 0 ? "+\(rd)" : "\(rd)") }

        detailLabel.attributedText = detailAttr
        detailLabel.textColor = pc.withAlphaComponent(0.45)
        detailLabel.adjustsFontSizeToFitWidth = true
        detailLabel.minimumScaleFactor = 0.8
    }

    private func configureAccessibilityInfo(row: StandingsTeamRow) {
        let gbSpoken: String?
        if let wcgb = row.wildCardGamesBack {
            gbSpoken = wcgb == "-" ? "Wildcard leader" : "\(wcgb) games back"
        } else if let gb = row.gamesBack {
            gbSpoken = gb == "-" ? "Division leader" : "\(gb) games back"
        } else {
            gbSpoken = nil
        }

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = AccessibilitySupport.joined([
            "Ranked \(row.rank)",
            row.teamName,
            "\(row.wins) wins, \(row.losses) losses",
            row.winPercentage.isEmpty ? nil : "Winning percentage \(row.winPercentage)",
            gbSpoken,
            row.lastTen.map { "Last 10: \($0)" },
            row.streak.map { "Streak: \($0)" },
            row.runDifferential.map { "Run differential: \($0 >= 0 ? "+\($0)" : "\($0)")" },
        ])
        accessibilityHint = "Shows team schedule"
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
