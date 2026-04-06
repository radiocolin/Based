import UIKit

protocol TimelineViewDelegate: AnyObject {
    func didSelectTimelineAtBat(_ event: AtBatEvent)
    func didTapTimelineLiveAtBat()
    func didLongPressTimelineLiveAtBat()
    func didSelectTimelinePitcher(_ pitcher: ScorecardPitcher)
}

struct InningGroup {
    let inning: Int
    let isTop: Bool
    let events: [AtBatEvent]
    
    var title: String {
        let side = isTop ? "TOP" : "BOTTOM"
        return "\(side) \(inning)"
    }
}

class TimelineView: UIView {
    weak var delegate: TimelineViewDelegate?
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var groups: [InningGroup] = []
    
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
    
    func configure(with timeline: [AtBatEvent]) {
        // Group by inning and half-inning
        var grouped: [InningGroup] = []
        var currentInning: Int?
        var currentIsTop: Bool?
        var currentEvents: [AtBatEvent] = []
        
        // Input timeline is already newest-to-oldest.
        // We iterate and group as long as inning/half-inning matches.
        for event in timeline {
            if event.inning != currentInning || event.isTop != currentIsTop {
                if let inn = currentInning, let top = currentIsTop {
                    grouped.append(InningGroup(inning: inn, isTop: top, events: currentEvents))
                }
                currentInning = event.inning
                currentIsTop = event.isTop
                currentEvents = [event]
            } else {
                currentEvents.append(event)
            }
        }
        
        if let inn = currentInning, let top = currentIsTop {
            grouped.append(InningGroup(inning: inn, isTop: top, events: currentEvents))
        }
        
        self.groups = grouped
        tableView.reloadData()
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
    
    func configureLiveState(linescore: Linescore, pitches: [PitchEvent]?, gameData: GameData?) {
        liveStateView.configure(with: linescore, pitches: pitches, gameData: gameData)
    }
    
    private func buildLiveHeader() {
        let container = UIView()
        
        // "CURRENT AT BAT" label
        let titleLabel = UILabel()
        titleLabel.text = "CURRENT AT BAT"
        titleLabel.font = UIFont(name: "PermanentMarker-Regular", size: 14) ?? .systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = AppColors.pencil.withAlphaComponent(0.8)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        // Background band for the title
        let titleBg = UIView()
        titleBg.backgroundColor = AppColors.header.withAlphaComponent(0.95)
        titleBg.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleBg)
        container.sendSubviewToBack(titleBg)
        
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
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // Size the header for UITableView
        container.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 192.5)
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
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: footer.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -24)
        ])
        
        // Pitchers
        if !awayPitchers.isEmpty || !homePitchers.isEmpty {
            stack.addArrangedSubview(buildPitcherSection())
        }
        
        // Umpires & Game Info side by side
        let infoRow = UIStackView()
        infoRow.axis = .horizontal
        infoRow.alignment = .top
        infoRow.distribution = .fill
        infoRow.spacing = 12
        
        if !umpires.isEmpty {
            infoRow.addArrangedSubview(buildUmpireLabel())
        }
        
        let hasGameInfo = !gameInfoItems.isEmpty || weather != nil
        if hasGameInfo {
            let gameInfoView = buildGameInfoLabel()
            gameInfoView.widthAnchor.constraint(equalToConstant: 200).isActive = true
            infoRow.addArrangedSubview(gameInfoView)
        }
        
        if !umpires.isEmpty || hasGameInfo {
            stack.addArrangedSubview(infoRow)
        }
        
        // Size the footer
        footer.setNeedsLayout()
        footer.layoutIfNeeded()
        let size = stack.systemLayoutSizeFitting(
            CGSize(width: tableView.bounds.width - 32, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        footer.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: size.height + 44)
        
        tableView.tableFooterView = footer
    }
    
    private func buildPitcherSection() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 2
        
        func addTeamPitchers(_ pitchers: [ScorecardPitcher], teamName: String) {
            guard !pitchers.isEmpty else { return }
            
            let titleLabel = UILabel()
            titleLabel.text = "\(teamName.uppercased()) PITCHERS"
            titleLabel.font = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
            titleLabel.textColor = AppColors.pencil
            container.addArrangedSubview(titleLabel)
            
            // Header Row
            let headerRow = UIStackView()
            headerRow.axis = .horizontal
            headerRow.spacing = 4
            
            let nameHeader = UILabel()
            nameHeader.text = "NAME"
            nameHeader.font = UIFont(name: "PatrickHand-Regular", size: 12) ?? .systemFont(ofSize: 12, weight: .bold)
            nameHeader.textColor = AppColors.pencil.withAlphaComponent(0.6)
            headerRow.addArrangedSubview(nameHeader)
            
            for label in ["IP", "H", "R", "ER", "BB", "K"] {
                let l = UILabel()
                l.text = label
                l.font = UIFont(name: "PatrickHand-Regular", size: 12) ?? .systemFont(ofSize: 12, weight: .bold)
                l.textColor = AppColors.pencil.withAlphaComponent(0.6)
                l.textAlignment = .center
                l.widthAnchor.constraint(equalToConstant: 30).isActive = true
                headerRow.addArrangedSubview(l)
            }
            container.addArrangedSubview(headerRow)
            
            for (idx, pitcher) in pitchers.enumerated() {
                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = 4
                row.backgroundColor = idx % 2 == 1 ? AppColors.alternateRow.withAlphaComponent(0.5) : .clear
                
                let nameLabel = UILabel()
                nameLabel.text = pitcher.fullName
                nameLabel.font = UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14)
                nameLabel.textColor = AppColors.pencil
                nameLabel.isUserInteractionEnabled = true
                nameLabel.tag = pitcher.id
                let tap = UITapGestureRecognizer(target: self, action: #selector(handlePitcherTap(_:)))
                nameLabel.addGestureRecognizer(tap)
                row.addArrangedSubview(nameLabel)
                
                for val in [pitcher.ip, "\(pitcher.h)", "\(pitcher.r)", "\(pitcher.er)", "\(pitcher.bb)", "\(pitcher.k)"] {
                    let l = UILabel()
                    l.text = val
                    l.font = UIFont(name: "PermanentMarker-Regular", size: 12) ?? .systemFont(ofSize: 12)
                    l.textColor = AppColors.pencil
                    l.textAlignment = .center
                    l.widthAnchor.constraint(equalToConstant: 30).isActive = true
                    row.addArrangedSubview(l)
                }
                
                container.addArrangedSubview(row)
            }
        }
        
        addTeamPitchers(awayPitchers, teamName: awayTeamName)
        if !awayPitchers.isEmpty && !homePitchers.isEmpty {
            let spacer = UIView()
            spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
            container.addArrangedSubview(spacer)
        }
        addTeamPitchers(homePitchers, teamName: homeTeamName)
        
        return container
    }

    @objc private func handlePitcherTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        guard let pitcher = footerPitchersByID[view.tag] else { return }
        delegate?.didSelectTimelinePitcher(pitcher)
    }
    
    private func buildUmpireLabel() -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        
        let umpireStrings = umpires.map { "\($0.type): \($0.fullName)" }
        
        let attributedText = NSMutableAttributedString(string: "UMPIRES\n", attributes: [
            .font: UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: AppColors.pencil
        ])
        attributedText.append(NSAttributedString(string: umpireStrings.joined(separator: "\n"), attributes: [
            .font: UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14),
            .foregroundColor: AppColors.pencil.withAlphaComponent(0.7)
        ]))
        
        label.attributedText = attributedText
        return label
    }
    
    private func buildGameInfoLabel() -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        
        let displayLabels = ["First pitch", "T", "Att", "Venue"]
        let infoItems = gameInfoItems.filter { item in
            displayLabels.contains(item.label) && item.value != nil
        }
        let dateItem = gameInfoItems.first { $0.value == nil && !$0.label.isEmpty }
        
        guard !infoItems.isEmpty || dateItem != nil || weather != nil else {
            return label
        }
        
        let labelMap = ["First pitch": "First Pitch", "T": "Duration", "Att": "Attendance"]
        
        let attributedText = NSMutableAttributedString(string: "GAME INFO\n", attributes: [
            .font: UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: AppColors.pencil
        ])
        
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14),
            .foregroundColor: AppColors.pencil.withAlphaComponent(0.7)
        ]
        
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "PermanentMarker-Regular", size: 12) ?? .systemFont(ofSize: 12),
            .foregroundColor: AppColors.pencil.withAlphaComponent(0.7)
        ]
        
        for item in infoItems {
            let displayLabel = labelMap[item.label] ?? item.label
            let value = (item.value ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "."))
            attributedText.append(NSAttributedString(string: "\(displayLabel): ", attributes: labelAttrs))
            attributedText.append(NSAttributedString(string: "\(value)\n", attributes: valueAttrs))
        }
        
        // Weather
        if let weather = weather {
            var weatherParts: [String] = []
            if let temp = weather.temp { weatherParts.append("\(temp)°F") }
            if let condition = weather.condition { weatherParts.append(condition) }
            if !weatherParts.isEmpty {
                attributedText.append(NSAttributedString(string: "Weather: ", attributes: labelAttrs))
                attributedText.append(NSAttributedString(string: "\(weatherParts.joined(separator: ", "))\n", attributes: valueAttrs))
            }
            if let wind = weather.wind {
                attributedText.append(NSAttributedString(string: "Wind: ", attributes: labelAttrs))
                attributedText.append(NSAttributedString(string: "\(wind)\n", attributes: valueAttrs))
            }
        }
        
        if let dateItem = dateItem {
            attributedText.append(NSAttributedString(string: dateItem.label, attributes: valueAttrs))
        }
        
        label.attributedText = attributedText
        return label
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
        let teamName = group.isTop ? awayTeamName : homeTeamName
        cell.configure(with: group.events[indexPath.row], accentColor: TeamColorProvider.color(for: teamName))
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        container.backgroundColor = AppColors.header.withAlphaComponent(0.95)
        
        let label = UILabel()
        label.text = groups[section].title
        label.font = UIFont(name: "PermanentMarker-Regular", size: 14) ?? .systemFont(ofSize: 14, weight: .bold)
        label.textColor = AppColors.pencil.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
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
