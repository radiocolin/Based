import UIKit

protocol TimelineViewDelegate: AnyObject {
    func didSelectTimelineAtBat(_ event: AtBatEvent)
    func didTapTimelineLiveAtBat()
    func didLongPressTimelineLiveAtBat()
    func didSelectTimelinePitcher(_ pitcher: ScorecardPitcher)
}

@MainActor
class TimelineView: UIView {
    weak var delegate: TimelineViewDelegate?
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var groups: [InningGroup] = []
    private var awayAccentColor: UIColor = AppColors.pencil
    private var homeAccentColor: UIColor = AppColors.pencil
    
    // Embedded live panel
    private let liveStateView = CurrentStateView()
    private var liveHeaderContainer: UIView?
    private var isLiveStateVisible = false
    
    // Footer data
    private var homePitchers: [ScorecardPitcher] = []
    private var awayPitchers: [ScorecardPitcher] = []
    private var homeTeamName: String = "Home"
    private var awayTeamName: String = "Away"
    private var umpires: [ScorecardUmpire] = []
    private var gameInfoItems: [GameInfoItem] = []
    private var weather: Weather?
    private var footerPitchersByID: [Int: ScorecardPitcher] = [:]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: TimelineView, _) in
            self.rebuildFooter()
            self.tableView.reloadData()
            if self.isLiveStateVisible {
                self.buildLiveHeader()
                self.tableView.tableHeaderView = self.liveHeaderContainer
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = AppColors.grid.withAlphaComponent(0.3)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TimelineCell.self, forCellReuseIdentifier: TimelineCell.identifier)
        tableView.estimatedRowHeight = 150
        tableView.rowHeight = UITableView.automaticDimension
        tableView.sectionHeaderTopPadding = 0
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(with timeline: [AtBatEvent], teams: ScorecardTeams? = nil) {
        if let teams {
            awayAccentColor = teams.away.name.map(TeamColorProvider.color(for:)) ?? AppColors.pencil
            homeAccentColor = teams.home.name.map(TeamColorProvider.color(for:)) ?? AppColors.pencil
        } else {
            awayAccentColor = TeamColorProvider.color(for: awayTeamName)
            homeAccentColor = TeamColorProvider.color(for: homeTeamName)
        }
        let newGroups = InningGroup.build(from: timeline)
        let oldGroups = groups

        guard oldGroups != newGroups else {
            groups = newGroups
            return
        }

        let sameSectionCount = oldGroups.count == newGroups.count
        let sameStructure = sameSectionCount && zip(oldGroups, newGroups).allSatisfy { oldGroup, newGroup in
            oldGroup.title == newGroup.title && oldGroup.events.count == newGroup.events.count
        }

        groups = newGroups

        guard sameStructure else {
            tableView.reloadData()
            return
        }

        var rowsToReload: [IndexPath] = []
        var sectionsToReload = IndexSet()

        for (sectionIndex, pair) in zip(oldGroups.indices, zip(oldGroups, newGroups)) {
            let (oldGroup, newGroup) = pair
            if oldGroup.title != newGroup.title {
                sectionsToReload.insert(sectionIndex)
                continue
            }

            for rowIndex in oldGroup.events.indices where oldGroup.events[rowIndex] != newGroup.events[rowIndex] {
                rowsToReload.append(IndexPath(row: rowIndex, section: sectionIndex))
            }
        }

        UIView.performWithoutAnimation {
            if !sectionsToReload.isEmpty {
                tableView.reloadSections(sectionsToReload, with: .none)
            }
            if !rowsToReload.isEmpty {
                tableView.reloadRows(at: rowsToReload, with: .none)
            }
        }
    }
    
    // MARK: - Embedded Live State
    
    func setLiveState(visible: Bool) {
        guard visible != isLiveStateVisible else { return }
        isLiveStateVisible = visible
        
        if visible {
            if liveHeaderContainer == nil {
                buildLiveHeader()
            }
            tableView.tableHeaderView = liveHeaderContainer
        } else {
            tableView.tableHeaderView = nil
        }
    }
    
    func configureLiveState(linescore: Linescore, pitches: [PitchEvent]?, gameData: GameData?, hasActiveAtBat: Bool = true) {
        liveStateView.configure(with: linescore, pitches: pitches, gameData: gameData, hasActiveAtBat: hasActiveAtBat)
    }
    
    private func buildLiveHeader() {
        let container = UIView()
        container.isAccessibilityElement = false
        
        // "CURRENT AT BAT" label
        let titleLabel = UILabel()
        titleLabel.text = "CURRENT AT BAT"
        titleLabel.font = AppFont.permanent(14, textStyle: .headline, compatibleWith: traitCollection)
        titleLabel.textColor = AppColors.pencil.withAlphaComponent(0.8)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isAccessibilityElement = false
        titleLabel.adjustsFontForContentSizeCategory = true
        container.addSubview(titleLabel)
        
        // Background band for the title
        let titleBg = UIView()
        titleBg.backgroundColor = AppColors.header.withAlphaComponent(0.95)
        titleBg.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleBg)
        container.sendSubviewToBack(titleBg)
        
        liveStateView.showsTopSeparator = false
        liveStateView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(liveStateView)
        
        // Wire up gestures
        liveStateView.tapAction = { [weak self] in
            self?.delegate?.didTapTimelineLiveAtBat()
        }
        liveStateView.longPressAction = { [weak self] in
            self?.delegate?.didLongPressTimelineLiveAtBat()
        }
        
        let separator = UIView()
        separator.backgroundColor = AppColors.grid.withAlphaComponent(0.4)
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)
        
        let bottomConstraint = separator.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        bottomConstraint.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            titleBg.topAnchor.constraint(equalTo: container.topAnchor),
            titleBg.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleBg.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            titleBg.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: titleBg.centerYAnchor),
            
            liveStateView.topAnchor.constraint(equalTo: titleBg.bottomAnchor),
            liveStateView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            liveStateView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            liveStateView.heightAnchor.constraint(equalToConstant: 160),
            
            separator.topAnchor.constraint(equalTo: liveStateView.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
            bottomConstraint
        ])
        
        // Size the header for UITableView
        let measurementWidth = tableView.bounds.width > 0 ? tableView.bounds.width : 375
        container.frame = CGRect(x: 0, y: 0, width: measurementWidth, height: 192.5)
        container.setNeedsLayout()
        container.layoutIfNeeded()
        
        liveHeaderContainer = container
    }
    
    // MARK: - Footer
    
    func configureFooter(pitchers: ScorecardPitchers, umpires: [ScorecardUmpire], gameInfo: [GameInfoItem], weather: Weather?, teams: ScorecardTeams) {
        self.awayPitchers = pitchers.away
        self.homePitchers = pitchers.home
        self.umpires = umpires
        self.gameInfoItems = gameInfo
        self.weather = weather
        self.awayTeamName = teams.away.name ?? "Away"
        self.homeTeamName = teams.home.name ?? "Home"
        self.footerPitchersByID = Dictionary(uniqueKeysWithValues: (pitchers.away + pitchers.home).map { ($0.id, $0) })
        rebuildFooter()
    }
    
    private func rebuildFooter() {
        let footer = UIView()
        // Use a reasonable width for measurement if the table view hasn't laid out yet.
        let measurementWidth = tableView.bounds.width > 0 ? tableView.bounds.width : 375
        footer.frame = CGRect(x: 0, y: 0, width: measurementWidth, height: 1000)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(stack)
        
        let trailingConstraint = stack.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16)
        trailingConstraint.priority = .defaultHigh // Allow flexibility if width is small
        
        let bottomConstraint = stack.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -24)
        bottomConstraint.priority = .defaultHigh // Allow flexible height during measurement
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: footer.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            trailingConstraint,
            bottomConstraint
        ])
        
        if let pitcherSection = GameFooterContent.makePitcherSection(
            groups: [
                FooterPitcherGroup(title: "\(awayTeamName.uppercased()) PITCHERS", pitchers: awayPitchers),
                FooterPitcherGroup(title: "\(homeTeamName.uppercased()) PITCHERS", pitchers: homePitchers)
            ],
            target: self,
            action: #selector(handlePitcherTap(_:))
        ) {
            stack.addArrangedSubview(pitcherSection)
        }
        
        // Umpires & Game Info side by side
        let infoRow = UIStackView()
        infoRow.axis = .horizontal
        infoRow.alignment = .top
        infoRow.distribution = .fill
        infoRow.spacing = 12
        
        if let umpireText = GameFooterContent.makeUmpireText(umpires) {
            let umpireLabel = UILabel()
            umpireLabel.numberOfLines = 0
            umpireLabel.attributedText = umpireText
            umpireLabel.accessibilityLabel = GameFooterContent.makeUmpireAccessibilityLabel(umpires)
            umpireLabel.adjustsFontForContentSizeCategory = true
            infoRow.addArrangedSubview(umpireLabel)
        }
        
        if let gameInfoText = GameFooterContent.makeGameInfoText(gameInfoItems: gameInfoItems, weather: weather) {
            let gameInfoView = UILabel()
            gameInfoView.numberOfLines = 0
            gameInfoView.attributedText = gameInfoText
            gameInfoView.accessibilityLabel = gameInfoText.string.replacingOccurrences(of: "\n", with: ", ")
            gameInfoView.adjustsFontForContentSizeCategory = true
            let widthConstraint = gameInfoView.widthAnchor.constraint(equalToConstant: 200)
            widthConstraint.priority = .defaultHigh // Allow it to shrink on small screens
            widthConstraint.isActive = true
            infoRow.addArrangedSubview(gameInfoView)
        }
        
        if !infoRow.arrangedSubviews.isEmpty {
            stack.addArrangedSubview(infoRow)
        }
        
        // If there is NO content, don't even set a footer.
        guard !stack.arrangedSubviews.isEmpty else {
            tableView.tableFooterView = nil
            return
        }
        
        // Size the footer
        footer.setNeedsLayout()
        footer.layoutIfNeeded()
        let size = stack.systemLayoutSizeFitting(
            CGSize(width: measurementWidth - 32, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        footer.frame = CGRect(x: 0, y: 0, width: measurementWidth, height: size.height + 44)
        
        tableView.tableFooterView = footer
    }
    
    @objc private func handlePitcherTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        guard let pitcher = footerPitchersByID[view.tag] else { return }
        delegate?.didSelectTimelinePitcher(pitcher)
    }
}

extension TimelineView: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return groups.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups[section].events.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TimelineCell.identifier, for: indexPath) as? TimelineCell else {
            return UITableViewCell()
        }
        let group = groups[indexPath.section]
        let accentColor = group.isTop ? awayAccentColor : homeAccentColor
        cell.configure(with: group.events[indexPath.row], accentColor: accentColor)
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        container.backgroundColor = AppColors.header.withAlphaComponent(0.95)
        container.isAccessibilityElement = true
        container.accessibilityTraits = .header
        container.accessibilityLabel = groups[section].title
        
        let label = UILabel()
        label.text = groups[section].title
        label.font = AppFont.permanent(14, textStyle: .headline, compatibleWith: traitCollection)
        label.textColor = AppColors.pencil.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isAccessibilityElement = false
        label.adjustsFontForContentSizeCategory = true
        container.addSubview(label)
        
        let line = UIView()
        line.backgroundColor = AppColors.grid.withAlphaComponent(0.4)
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
        return container
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 32
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.didSelectTimelineAtBat(groups[indexPath.section].events[indexPath.row])
    }
}
