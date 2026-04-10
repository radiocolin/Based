import UIKit

// MARK: - Delegate Protocol

protocol GamePickerViewDelegate: AnyObject {
    func gamePickerView(_ picker: GamePickerView, didSelectGame game: ScheduleGame)
    func gamePickerView(_ picker: GamePickerView, didChangeDate date: Date)
}

// MARK: - GamePickerView

class GamePickerView: UIView {

    weak var delegate: GamePickerViewDelegate?

    // Date Navigation
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let dateLabel = UILabel()

    // Game Cards
    private var collectionView: UICollectionView!
    private let noGamesLabel = UILabel()

    // State
    private var games: [ScheduleGame] = []
    private var selectedGamePk: Int?
    private(set) var currentDate: Date = Date()

    // Graphics
    private let borderLayer = CAShapeLayer()

    // Constants
    private let paperColor = AppColors.paper
    private var pencilColor: UIColor { AppColors.pencil }
    private let headerFont = "PermanentMarker-Regular"
    private let bodyFont = "PatrickHand-Regular"

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: GamePickerView, _) in
            self.dateLabel.textColor = self.pencilColor
            self.noGamesLabel.textColor = self.pencilColor.withAlphaComponent(0.5)
            self.collectionView.reloadData()
            self.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = paperColor
        layer.addSublayer(borderLayer)

        // Date Row
        let iconSize = CGSize(width: 28, height: 28)
        let prevImg = UIImage.pencilStyledIcon(named: "arrow.left", color: pencilColor, size: iconSize)
        prevButton.setImage(prevImg, for: .normal)
        prevButton.setTitle(nil, for: .normal)
        prevButton.tintColor = pencilColor
        prevButton.accessibilityLabel = "Previous date"
        prevButton.accessibilityHint = "Double tap to show the previous date."
        prevButton.addTarget(self, action: #selector(prevDate), for: .touchUpInside)

        let nextImg = UIImage.pencilStyledIcon(named: "arrow.right", color: pencilColor, size: iconSize)
        nextButton.setImage(nextImg, for: .normal)
        nextButton.setTitle(nil, for: .normal)
        nextButton.tintColor = pencilColor
        nextButton.accessibilityLabel = "Next date"
        nextButton.accessibilityHint = "Double tap to show the next date."
        nextButton.addTarget(self, action: #selector(nextDate), for: .touchUpInside)

        dateLabel.font = UIFont(name: headerFont, size: 18) ?? .boldSystemFont(ofSize: 18)
        dateLabel.textColor = pencilColor
        dateLabel.textAlignment = .center
        dateLabel.isAccessibilityElement = true

        // Collection View
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        layout.itemSize = CGSize(width: 100, height: 78)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.isAccessibilityElement = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GameCardCell.self, forCellWithReuseIdentifier: GameCardCell.reuseIdentifier)

        // No Games Label
        noGamesLabel.text = "No games scheduled"
        noGamesLabel.font = UIFont(name: bodyFont, size: 16) ?? .systemFont(ofSize: 16)
        noGamesLabel.textColor = pencilColor.withAlphaComponent(0.5)
        noGamesLabel.textAlignment = .center
        noGamesLabel.isHidden = true
        noGamesLabel.accessibilityLabel = "No games scheduled"

        // Add subviews
        for v in [prevButton, dateLabel, nextButton, collectionView!, noGamesLabel] {
            addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            // Date Row
            prevButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            prevButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            prevButton.widthAnchor.constraint(equalToConstant: 28),
            prevButton.heightAnchor.constraint(equalToConstant: 28),

            nextButton.topAnchor.constraint(equalTo: prevButton.topAnchor),
            nextButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            nextButton.widthAnchor.constraint(equalToConstant: 28),
            nextButton.heightAnchor.constraint(equalToConstant: 28),

            dateLabel.centerYAnchor.constraint(equalTo: prevButton.centerYAnchor),
            dateLabel.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor),

            // Collection View
            collectionView.topAnchor.constraint(equalTo: prevButton.bottomAnchor, constant: 6),
            collectionView.leadingAnchor.constraint(equalTo: window?.leadingAnchor ?? leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: window?.trailingAnchor ?? trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            // No Games Label
            noGamesLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            noGamesLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
        ])

        setDate(Date())
    }

    // MARK: - Public

    func configure(with games: [ScheduleGame], selectedGamePk: Int?) {
        self.games = games
        self.selectedGamePk = selectedGamePk
        noGamesLabel.isHidden = !games.isEmpty
        collectionView.isHidden = games.isEmpty
        collectionView.reloadData()

        // Scroll to selected game
        if let pk = selectedGamePk,
           let index = games.firstIndex(where: { $0.gamePk == pk }) {
            collectionView.scrollToItem(
                at: IndexPath(item: index, section: 0),
                at: .centeredHorizontally,
                animated: false
            )
        }
    }

    func setDate(_ date: Date) {
        currentDate = date
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        dateLabel.text = formatter.string(from: date)
        dateLabel.accessibilityLabel = "Date, \(formatter.string(from: date))"

        // Disable next if today or future
        nextButton.isEnabled = !Calendar.current.isDateInToday(date)
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.3
        nextButton.accessibilityHint = nextButton.isEnabled ? "Double tap to show the next date." : "No later dates are available."
    }

    // MARK: - Actions

    @objc private func prevDate() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) else { return }
        setDate(newDate)
        delegate?.gamePickerView(self, didChangeDate: newDate)
    }

    @objc private func nextDate() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) else { return }
        if newDate > Date() { return }
        setDate(newDate)
        delegate?.gamePickerView(self, didChangeDate: newDate)
    }

    // MARK: - Drawing

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = bounds
        let path = UIBezierPath()
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: b.maxY), to: CGPoint(x: b.maxX, y: b.maxY)))
        borderLayer.path = path.cgPath
        borderLayer.strokeColor = pencilColor.withAlphaComponent(0.3).cgColor
        borderLayer.lineWidth = 0.75
        borderLayer.fillColor = UIColor.clear.cgColor
    }
}

// MARK: - UICollectionView DataSource & Delegate

extension GamePickerView: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return games.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GameCardCell.reuseIdentifier, for: indexPath) as! GameCardCell
        let game = games[indexPath.item]
        cell.configure(with: game, isSelected: game.gamePk == selectedGamePk)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let game = games[indexPath.item]
        selectedGamePk = game.gamePk
        collectionView.reloadData()
        delegate?.gamePickerView(self, didSelectGame: game)
    }
}

// MARK: - GameCardCell

class GameCardCell: UICollectionViewCell {

    static let reuseIdentifier = "GameCardCell"

    private let awayLabel = UILabel()
    private let homeLabel = UILabel()
    private let awayScoreLabel = UILabel()
    private let homeScoreLabel = UILabel()
    private let statusLabel = UILabel()
    private let venueLabel = UILabel()
    private let atLabel = UILabel()
    
    private let linesLayer = CAShapeLayer()

    private let paperColor = AppColors.paper
    private var selectedColor: UIColor { AppColors.selected }
    private var pencilColor: UIColor { AppColors.pencil }
    private let headerFont = "PermanentMarker-Regular"
    private let bodyFont = "PatrickHand-Regular"

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        accessibilityLabel = nil
        accessibilityHint = nil
    }

    private func setupUI() {
        contentView.backgroundColor = paperColor
        contentView.layer.cornerRadius = 8
        contentView.layer.addSublayer(linesLayer)
        isAccessibilityElement = true
        accessibilityTraits = .button

        awayLabel.font = UIFont(name: headerFont, size: 18) ?? .boldSystemFont(ofSize: 18)
        homeLabel.font = UIFont(name: headerFont, size: 18) ?? .boldSystemFont(ofSize: 18)

        awayScoreLabel.font = UIFont(name: bodyFont, size: 22) ?? .systemFont(ofSize: 22)
        awayScoreLabel.textColor = pencilColor
        awayScoreLabel.textAlignment = .right

        homeScoreLabel.font = UIFont(name: bodyFont, size: 22) ?? .systemFont(ofSize: 22)
        homeScoreLabel.textColor = pencilColor
        homeScoreLabel.textAlignment = .right

        atLabel.text = "@"
        atLabel.font = UIFont(name: "PermanentMarker-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
        atLabel.textColor = pencilColor.withAlphaComponent(0.3)
        atLabel.textAlignment = .center

        statusLabel.font = UIFont(name: bodyFont, size: 13) ?? .systemFont(ofSize: 13)
        statusLabel.textColor = pencilColor.withAlphaComponent(0.7)
        statusLabel.textAlignment = .center
        
        venueLabel.font = UIFont(name: bodyFont, size: 11) ?? .systemFont(ofSize: 11)
        venueLabel.textColor = pencilColor.withAlphaComponent(0.5)
        venueLabel.textAlignment = .center

        for v in [awayLabel, homeLabel, awayScoreLabel, homeScoreLabel, atLabel, statusLabel, venueLabel] {
            contentView.addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
            v.isAccessibilityElement = false
        }

        let pad: CGFloat = 10
        NSLayoutConstraint.activate([
            // Away team row
            awayLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: pad),
            awayLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            awayLabel.trailingAnchor.constraint(lessThanOrEqualTo: awayScoreLabel.leadingAnchor, constant: -4),

            awayScoreLabel.centerYAnchor.constraint(equalTo: awayLabel.centerYAnchor),
            awayScoreLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            awayScoreLabel.widthAnchor.constraint(equalToConstant: 30),

            // @ separator
            atLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -8),
            atLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // Home team row
            homeLabel.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -2),
            homeLabel.leadingAnchor.constraint(equalTo: awayLabel.leadingAnchor),
            homeLabel.trailingAnchor.constraint(lessThanOrEqualTo: homeScoreLabel.leadingAnchor, constant: -4),

            homeScoreLabel.centerYAnchor.constraint(equalTo: homeLabel.centerYAnchor),
            homeScoreLabel.trailingAnchor.constraint(equalTo: awayScoreLabel.trailingAnchor),
            homeScoreLabel.widthAnchor.constraint(equalToConstant: 30),

            // Status
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            {
                let c = statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad)
                c.priority = UILayoutPriority(999)
                return c
            }(),
            statusLabel.bottomAnchor.constraint(equalTo: venueLabel.topAnchor, constant: -2),
            
            // Venue
            venueLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            {
                let c = venueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad)
                c.priority = UILayoutPriority(999)
                return c
            }(),
            venueLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
        ])
    }

    func configure(with game: ScheduleGame, isSelected: Bool) {
        let awayName = game.teams.away.team.name ?? "AWAY"
        let homeName = game.teams.home.team.name ?? "HOME"

        awayLabel.text = abbreviation(for: awayName)
        homeLabel.text = abbreviation(for: homeName)
        
        awayLabel.textColor = TeamColorProvider.color(for: awayName)
        homeLabel.textColor = TeamColorProvider.color(for: homeName)

        // Scores
        if let s = game.teams.away.score {
            awayScoreLabel.text = "\(s)"
        } else {
            awayScoreLabel.text = ""
        }
        if let s = game.teams.home.score {
            homeScoreLabel.text = "\(s)"
        } else {
            homeScoreLabel.text = ""
        }

        // Refresh pencil-colored elements
        let pc = pencilColor
        awayScoreLabel.textColor = pc
        homeScoreLabel.textColor = pc
        atLabel.textColor = pc.withAlphaComponent(0.3)
        statusLabel.textColor = pc.withAlphaComponent(0.7)
        venueLabel.textColor = pc.withAlphaComponent(0.5)

        // Status & Venue
        statusLabel.text = formatStatus(game)
        venueLabel.text = game.venue?.name ?? ""

        // Selection state
        contentView.backgroundColor = isSelected ? selectedColor : paperColor
        contentView.layer.borderWidth = isSelected ? 1.5 : 0
        contentView.layer.borderColor = isSelected ? pc.withAlphaComponent(0.4).cgColor : UIColor.clear.cgColor
        accessibilityLabel = AccessibilitySupport.gameCardDescription(game)
        accessibilityHint = isSelected ? "Currently selected game." : "Double tap to open or select this game."

        setNeedsLayout()
    }

    private func abbreviation(for teamName: String) -> String {
        let map: [String: String] = ["Arizona Diamondbacks": "ARI", "Atlanta Braves": "ATL", "Baltimore Orioles": "BAL", "Boston Red Sox": "BOS", "Chicago Cubs": "CHC", "Chicago White Sox": "CWS", "Cincinnati Reds": "CIN", "Cleveland Guardians": "CLE", "Colorado Rockies": "COL", "Detroit Tigers": "DET", "Houston Astros": "HOU", "Kansas City Royals": "KC", "Los Angeles Angels": "LAA", "Los Angeles Dodgers": "LAD", "Miami Marlins": "MIA", "Milwaukee Brewers": "MIL", "Minnesota Twins": "MIN", "New York Mets": "NYM", "New York Yankees": "NYY", "Oakland Athletics": "OAK", "Philadelphia Phillies": "PHI", "Pittsburgh Pirates": "PIT", "San Diego Padres": "SD", "San Francisco Giants": "SF", "Seattle Mariners": "SEA", "St. Louis Cardinals": "STL", "Tampa Bay Rays": "TB", "Texas Rangers": "TEX", "Toronto Blue Jays": "TOR", "Washington Nationals": "WSH"]
        return map[teamName] ?? String(teamName.prefix(3)).uppercased()
    }

    private func formatStatus(_ game: ScheduleGame) -> String {
        let state = game.status.detailedState
        switch state {
        case "Final": return "FINAL"
        case "In Progress": return "LIVE"
        case "Scheduled", "Pre-Game": return formatGameTime(game.gameDate)
        default: return state.uppercased()
        }
    }

    private func formatGameTime(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoDate) else {
            let basic = ISO8601DateFormatter()
            guard let date = basic.date(from: isoDate) else { return "" }
            return formatTime(date)
        }
        return formatTime(date)
    }

    private func formatTime(_ date: Date) -> String {
        let tf = DateFormatter()
        tf.dateFormat = "h:mm a"
        return tf.string(from: date)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = contentView.bounds
        let path = UIBezierPath()
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: 0), to: CGPoint(x: b.width, y: 0), jitter: 0.4))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: b.width, y: 0), to: CGPoint(x: b.width, y: b.height), jitter: 0.4))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: b.width, y: b.height), to: CGPoint(x: 0, y: b.height), jitter: 0.4))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: b.height), to: CGPoint(x: 0, y: 0), jitter: 0.4))
        linesLayer.path = path.cgPath
        linesLayer.strokeColor = pencilColor.withAlphaComponent(0.3).cgColor
        linesLayer.lineWidth = 0.75
        linesLayer.fillColor = UIColor.clear.cgColor
    }
}
