import UIKit

class PlayerDetailViewController: UIViewController {

    // Data
    private let batter: ScorecardBatter
    private let gameStats: PlayerGameStats?
    private var playerInfo: PlayerInfo?

    // UI Elements
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let headerLabel = UILabel()
    private let bioLabel = UILabel()
    private let gameStatsContainer = UIView()
    private let seasonStatsContainer = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    // Graphics
    private let gameStatsLinesLayer = CAShapeLayer()
    private let seasonStatsLinesLayer = CAShapeLayer()

    // Constants
    private let paperColor = AppColors.paper
    private var pencilColor: UIColor { AppColors.pencil }
    private let headerFont = "PermanentMarker-Regular"
    private let bodyFont = "PatrickHand-Regular"

    init(batter: ScorecardBatter, gameStats: PlayerGameStats? = nil) {
        self.batter = batter
        self.gameStats = gameStats
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchPlayerInfo()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        drawPencilLines()
    }

    private func setupUI() {
        view.backgroundColor = paperColor

        // Scroll View
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Content Stack
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        // Header
        headerLabel.text = batter.fullName.uppercased()
        headerLabel.font = UIFont(name: headerFont, size: 28) ?? .systemFont(ofSize: 28, weight: .bold)
        headerLabel.textColor = pencilColor
        headerLabel.textAlignment = .center
        headerLabel.numberOfLines = 2
        headerLabel.adjustsFontSizeToFitWidth = true
        headerLabel.minimumScaleFactor = 0.7
        contentStack.addArrangedSubview(headerLabel)

        // Bio Label (placeholder until API data loads)
        bioLabel.text = batter.position
        bioLabel.font = UIFont(name: bodyFont, size: 16) ?? .systemFont(ofSize: 16)
        bioLabel.textColor = pencilColor.withAlphaComponent(0.7)
        bioLabel.textAlignment = .center
        bioLabel.numberOfLines = 0
        contentStack.addArrangedSubview(bioLabel)

        // Today's Game Stats
        let gameTitleLabel = createSectionTitle("TODAY'S GAME")
        contentStack.addArrangedSubview(gameTitleLabel)

        gameStatsContainer.translatesAutoresizingMaskIntoConstraints = false
        gameStatsContainer.layer.addSublayer(gameStatsLinesLayer)
        contentStack.addArrangedSubview(gameStatsContainer)
        setupGameStatsGrid()

        // Season Stats (with loading)
        let seasonTitleLabel = createSectionTitle("2026 SEASON")
        contentStack.addArrangedSubview(seasonTitleLabel)

        seasonStatsContainer.translatesAutoresizingMaskIntoConstraints = false
        seasonStatsContainer.layer.addSublayer(seasonStatsLinesLayer)
        contentStack.addArrangedSubview(seasonStatsContainer)

        // Loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = pencilColor
        loadingIndicator.startAnimating()
        seasonStatsContainer.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: seasonStatsContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: seasonStatsContainer.centerYAnchor),
            seasonStatsContainer.heightAnchor.constraint(equalToConstant: 80)
        ])
    }

    private func createSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont(name: headerFont, size: 14) ?? .systemFont(ofSize: 14, weight: .bold)
        label.textColor = pencilColor.withAlphaComponent(0.5)
        label.textAlignment = .center
        return label
    }

    private func setupGameStatsGrid() {
        let stats = gameStats ?? PlayerGameStats(atBats: 0, hits: 0, runs: 0, rbi: 0, walks: 0, strikeouts: 0)

        let statItems: [(label: String, value: String)] = [
            ("AB", "\(stats.atBats)"),
            ("H", "\(stats.hits)"),
            ("R", "\(stats.runs)"),
            ("RBI", "\(stats.rbi)"),
            ("BB", "\(stats.walks)"),
            ("K", "\(stats.strikeouts)")
        ]

        let stackView = createStatsRow(items: statItems)
        gameStatsContainer.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: gameStatsContainer.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: gameStatsContainer.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: gameStatsContainer.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: gameStatsContainer.bottomAnchor, constant: -12)
        ])
    }

    private func setupSeasonStatsGrid(with stats: BattingStats) {
        // Remove loading indicator
        loadingIndicator.stopAnimating()
        loadingIndicator.removeFromSuperview()

        // Remove height constraint
        seasonStatsContainer.constraints.forEach { constraint in
            if constraint.firstAttribute == .height {
                seasonStatsContainer.removeConstraint(constraint)
            }
        }

        let statItems: [(label: String, value: String)] = [
            ("AVG", stats.avg ?? "---"),
            ("HR", "\(stats.homeRuns ?? 0)"),
            ("RBI", "\(stats.rbi ?? 0)"),
            ("SB", "\(stats.stolenBases ?? 0)"),
            ("OPS", stats.ops ?? "---")
        ]

        let stackView = createStatsRow(items: statItems, fontSize: 28)
        seasonStatsContainer.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: seasonStatsContainer.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: seasonStatsContainer.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: seasonStatsContainer.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: seasonStatsContainer.bottomAnchor, constant: -12)
        ])

        view.setNeedsLayout()
    }

    private func createStatsRow(items: [(label: String, value: String)], fontSize: CGFloat = 32) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        for item in items {
            let itemStack = UIStackView()
            itemStack.axis = .vertical
            itemStack.alignment = .center
            itemStack.spacing = 2

            let valueLabel = UILabel()
            valueLabel.text = item.value
            valueLabel.font = UIFont(name: headerFont, size: fontSize) ?? .systemFont(ofSize: fontSize, weight: .bold)
            valueLabel.textColor = pencilColor
            valueLabel.textAlignment = .center

            let labelLabel = UILabel()
            labelLabel.text = item.label
            labelLabel.font = UIFont(name: bodyFont, size: 12) ?? .systemFont(ofSize: 12)
            labelLabel.textColor = pencilColor.withAlphaComponent(0.6)
            labelLabel.textAlignment = .center

            itemStack.addArrangedSubview(valueLabel)
            itemStack.addArrangedSubview(labelLabel)
            stackView.addArrangedSubview(itemStack)
        }

        return stackView
    }

    private func fetchPlayerInfo() {
        Task {
            do {
                let info = try await GameService.shared.fetchPlayerInfo(playerId: batter.id)
                self.playerInfo = info
                await MainActor.run {
                    updateWithPlayerInfo(info)
                }
            } catch {
                await MainActor.run {
                    showSeasonStatsError()
                }
            }
        }
    }

    private func updateWithPlayerInfo(_ info: PlayerInfo) {
        // Update bio
        var bioParts: [String] = []

        if let number = info.primaryNumber {
            bioParts.append("#\(number)")
        }
        if let position = info.primaryPosition?.name {
            bioParts.append(position)
        }
        if let team = info.currentTeam?.name {
            bioParts.append(team)
        }

        var bioLine2: [String] = []
        if let height = info.height {
            bioLine2.append(height)
        }
        if let weight = info.weight {
            bioLine2.append("\(weight) lbs")
        }
        if let batSide = info.batSide?.code, let throwSide = info.pitchHand?.code {
            bioLine2.append("B/T: \(batSide)/\(throwSide)")
        }

        var bioText = bioParts.joined(separator: " • ")
        if !bioLine2.isEmpty {
            bioText += "\n" + bioLine2.joined(separator: " • ")
        }
        bioLabel.text = bioText

        // Update season stats
        if let seasonStats = info.stats?.first(where: { $0.type?.displayName == "season" }),
           let split = seasonStats.splits?.first,
           let stats = split.stat {
            setupSeasonStatsGrid(with: stats)
        } else {
            showSeasonStatsError()
        }
    }

    private func showSeasonStatsError() {
        loadingIndicator.stopAnimating()

        let errorLabel = UILabel()
        errorLabel.text = "Stats unavailable"
        errorLabel.font = UIFont(name: bodyFont, size: 16) ?? .systemFont(ofSize: 16)
        errorLabel.textColor = pencilColor.withAlphaComponent(0.5)
        errorLabel.textAlignment = .center
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        seasonStatsContainer.addSubview(errorLabel)

        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: seasonStatsContainer.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: seasonStatsContainer.centerYAnchor)
        ])
    }

    private func drawPencilLines() {
        drawBoxLines(for: gameStatsContainer, layer: gameStatsLinesLayer, columns: 6)
        drawBoxLines(for: seasonStatsContainer, layer: seasonStatsLinesLayer, columns: 5)
    }

    private func drawBoxLines(for container: UIView, layer: CAShapeLayer, columns: Int) {
        let b = container.bounds
        guard b.width > 0, b.height > 0 else { return }

        let path = UIBezierPath()

        // Box
        path.append(UIBezierPath.pencilLine(from: .zero, to: CGPoint(x: b.width, y: 0)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: b.width, y: 0), to: CGPoint(x: b.width, y: b.height)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: b.width, y: b.height), to: CGPoint(x: 0, y: b.height)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: b.height), to: .zero))

        // Vertical dividers
        let colWidth = b.width / CGFloat(columns)
        for i in 1..<columns {
            let x = colWidth * CGFloat(i)
            path.append(UIBezierPath.pencilLine(from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: b.height)))
        }

        layer.path = path.cgPath
        layer.strokeColor = pencilColor.withAlphaComponent(0.3).cgColor
        layer.lineWidth = 1.0
        layer.fillColor = UIColor.clear.cgColor
        layer.lineCap = .round
        layer.lineJoin = .round
    }
}

// MARK: - Player Game Stats Model

struct PlayerGameStats {
    let atBats: Int
    let hits: Int
    let runs: Int
    let rbi: Int
    let walks: Int
    let strikeouts: Int
}
