import UIKit

class ScheduleDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    
    struct MonthSection {
        let title: String
        let games: [ScheduleGame]
    }
    
    private(set) var sections: [MonthSection] = []
    private(set) var nextGameIndexPath: IndexPath?
    private let teamId: Int
    private let teamName: String
    
    var onGameSelected: ((ScheduleGame) -> Void)?
    
    private var pencilColor: UIColor { AppColors.pencil }
    
    init(teamId: Int, teamName: String) {
        self.teamId = teamId
        self.teamName = teamName
        super.init()
    }
    
    func update(with games: [ScheduleGame]) {
        let sorted = games.sorted { scheduleDate(from: $0.gameDate) < scheduleDate(from: $1.gameDate) }
        self.sections = buildMonthSections(from: sorted)
        self.nextGameIndexPath = findNextGameIndexPath()
    }
    
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
    
    private func scheduleDate(from isoDate: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoDate) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: isoDate) ?? .distantFuture
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
    
    // MARK: - Table View Data Source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].games.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
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
    
    // MARK: - Table View Delegate
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = AppFont.ibmPlexCondensedBold(16, textStyle: .headline, compatibleWith: tableView.traitCollection)
        header.textLabel?.textColor = pencilColor.withAlphaComponent(0.6)
        header.contentView.backgroundColor = AppColors.paper
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let game = sections[indexPath.section].games[indexPath.row]
        onGameSelected?(game)
    }
}

// MARK: - TeamGameCell

class TeamGameCell: UITableViewCell {
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

        opponentLabel.font = AppFont.ibmPlexCondensedBold(20, textStyle: .body)
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

        statusBadge.font = AppFont.ibmPlexCondensed(12, textStyle: .caption1)
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
        let gutter: CGFloat = 40
        topConstraint = opponentLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10)
        NSLayoutConstraint.activate([
            seriesDivider.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            seriesDivider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            seriesDivider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            seriesDivider.heightAnchor.constraint(equalToConstant: 1),

            statusBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            statusBadge.trailingAnchor.constraint(equalTo: opponentLabel.leadingAnchor, constant: -4),
            statusBadge.widthAnchor.constraint(equalToConstant: gutter),
            statusBadge.centerYAnchor.constraint(equalTo: opponentLabel.centerYAnchor),

            topConstraint,
            opponentLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad + gutter + 4),
            opponentLabel.trailingAnchor.constraint(lessThanOrEqualTo: rightLabel.leadingAnchor, constant: -8),
            
            rightLabel.topAnchor.constraint(greaterThanOrEqualTo: opponentLabel.topAnchor),
            rightLabel.bottomAnchor.constraint(lessThanOrEqualTo: detailLabel.bottomAnchor),
            {
                let c = rightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
                c.priority = .defaultHigh
                return c
            }(),
            rightLabel.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -8),

            chevronView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            chevronView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 10),

            detailLabel.topAnchor.constraint(equalTo: opponentLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: opponentLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: rightLabel.leadingAnchor, constant: -8),
            detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    func configure(with game: ScheduleGame, teamId: Int, phase: ScheduleDataSource.GamePhase, isNextGame: Bool, isSeriesStart: Bool) {
        configureHeader(isSeriesStart: isSeriesStart)

        let isHome = game.teams.home.team.id == teamId
        let opponent = isHome ? game.teams.away.team.name ?? "TBD" : game.teams.home.team.name ?? "TBD"
        let prefix = isHome ? "vs" : "@"
        let gameDate = parseDate(game.gameDate)

        configureOpponent(opponent, prefix: prefix)
        configureDetail(game: game, phase: phase, gameDate: gameDate)

        backgroundColor = isNextGame ? AppColors.selected : AppColors.paper

        let pc = pencilColor
        configureStatus(phase: phase, gameDate: gameDate, isHome: isHome, isNextGame: isNextGame, game: game, pc: pc)
        configureAccessibility(prefix: prefix, opponent: opponent, isNextGame: isNextGame, game: game)
    }

    private func configureHeader(isSeriesStart: Bool) {
        if isSeriesStart {
            topConstraint.constant = 20
            seriesDivider.isHidden = false
            seriesDivider.backgroundColor = pencilColor.withAlphaComponent(0.1)
        } else {
            topConstraint.constant = 10
            seriesDivider.isHidden = true
        }
    }

    private func configureOpponent(_ opponent: String, prefix: String) {
        opponentLabel.text = "\(prefix) \(abbreviation(for: opponent))"
        opponentLabel.textColor = TeamColorProvider.color(for: opponent)
    }

    private func configureDetail(game: ScheduleGame, phase: ScheduleDataSource.GamePhase, gameDate: Date) {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        let dateStr = df.string(from: gameDate)
        let detailFont = AppFont.ibmPlexCondensed(15, textStyle: .subheadline)
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

        if phase == .delayed {
            detail.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: detail.length))
        }

        if phase == .delayed, let resDate = game.rescheduleDate {
            let rd = parseDate(resDate)
            let rdf = DateFormatter()
            rdf.dateFormat = "MMM d"
            detail.append(NSAttributedString(
                string: " · Resched: \(rdf.string(from: rd))",
                attributes: [.font: detailFont, .foregroundColor: UIColor.systemOrange.withAlphaComponent(0.8)]
            ))
        } else if let fromDate = game.rescheduledFromDate {
            let rd = parseDate(fromDate)
            let rdf = DateFormatter()
            rdf.dateFormat = "MMM d"
            detail.append(NSAttributedString(
                string: " · From: \(rdf.string(from: rd))",
                attributes: [.font: detailFont, .foregroundColor: pencilColor.withAlphaComponent(0.35)]
            ))
        }
        detailLabel.attributedText = detail
    }

    private func configureStatus(phase: ScheduleDataSource.GamePhase, gameDate: Date, isHome: Bool, isNextGame: Bool, game: ScheduleGame, pc: UIColor) {
        switch phase {
        case .completed:
            configureCompletedStatus(game: game, isHome: isHome)
        case .live:
            configureLiveStatus(game: game, isHome: isHome, pc: pc)
        case .delayed:
            configureDelayedStatus(gameDate: gameDate, pc: pc)
        case .future:
            configureFutureStatus(gameDate: gameDate, isNextGame: isNextGame, pc: pc)
        }
    }

    private func configureCompletedStatus(game: ScheduleGame, isHome: Bool) {
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
    }

    private func configureLiveStatus(game: ScheduleGame, isHome: Bool, pc: UIColor) {
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
    }

    private func configureDelayedStatus(gameDate: Date, pc: UIColor) {
        let tf = DateFormatter()
        tf.dateFormat = "h:mm a"
        let timeStr = tf.string(from: gameDate)
        rightLabel.attributedText = NSAttributedString(
            string: timeStr,
            attributes: [
                .font: AppFont.patrick(22, textStyle: .title3),
                .foregroundColor: pc.withAlphaComponent(0.3),
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        statusBadge.text = "PPD"
        statusBadge.textColor = pc.withAlphaComponent(0.5)
        opponentLabel.alpha = 0.7
        detailLabel.alpha = 0.7
    }

    private func configureFutureStatus(gameDate: Date, isNextGame: Bool, pc: UIColor) {
        let tf = DateFormatter()
        tf.dateFormat = "h:mm a"
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

    private func configureAccessibility(prefix: String, opponent: String, isNextGame: Bool, game: ScheduleGame) {
        isAccessibilityElement = true
        accessibilityTraits = .button
        let spokenOpponent = "\(prefix) \(opponent)"
        var statusPrefix = ""
        if statusBadge.text == "NEXT" { statusPrefix = "Next game," }
        else if statusBadge.text == "PPD" { statusPrefix = "Postponed," }
        else if statusBadge.text == "LIVE" { statusPrefix = "Live now," }

        var detailVO = detailLabel.attributedText?.string ?? ""
        detailVO = detailVO.replacingOccurrences(of: " · ", with: ", ")
        detailVO = detailVO.replacingOccurrences(of: "Resched:", with: "rescheduled to")
        detailVO = detailVO.replacingOccurrences(of: "From:", with: "originally scheduled for")

        accessibilityLabel = AccessibilitySupport.joined([
            statusPrefix,
            spokenOpponent,
            rightLabel.text,
            detailVO
        ])
    }
    
    private func parseDate(_ isoDate: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoDate) { return date }
        
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        if let date = fallback.date(from: isoDate) { return date }
        
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd"
        if let date = simple.date(from: isoDate) { return date }
        
        return .distantFuture
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
