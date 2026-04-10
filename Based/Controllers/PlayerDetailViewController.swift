import UIKit

class PlayerDetailViewController: UIViewController {

    enum Subject {
        case batter(ScorecardBatter, PlayerGameStats?)
        case pitcher(ScorecardPitcher)
    }

    private let subject: Subject
    private var playerInfo: PlayerInfo?
    private var gameGridMetrics = GridMetrics(columns: 6, rows: 1)
    private var seasonGridMetrics = GridMetrics(columns: 5, rows: 1)
    private var seasonTitleText = "SEASON"

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let headerLabel = UILabel()
    private let bioLabel = UILabel()
    private let gameTitleLabel = UILabel()
    private let seasonTitleLabel = UILabel()
    private let gameStatsContainer = UIView()
    private let seasonStatsContainer = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private let gameStatsLinesLayer = CAShapeLayer()
    private let seasonStatsLinesLayer = CAShapeLayer()
    private weak var gameStatsContentView: UIView?
    private weak var seasonStatsContentView: UIView?

    private let paperColor = AppColors.paper
    private var pencilColor: UIColor { AppColors.pencil }
    private let headerFont = "PermanentMarker-Regular"
    private let bodyFont = "PatrickHand-Regular"

    private struct GridMetrics {
        let columns: Int
        let rows: Int
    }

    init(batter: ScorecardBatter, gameStats: PlayerGameStats? = nil) {
        self.subject = .batter(batter, gameStats)
        super.init(nibName: nil, bundle: nil)
    }

    init(pitcher: ScorecardPitcher) {
        self.subject = .pitcher(pitcher)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchPlayerInfo()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: PlayerDetailViewController, _) in
            self.view.setNeedsLayout()
        }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: PlayerDetailViewController, _) in
            self.applyTypography()
            self.view.setNeedsLayout()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        drawPencilLines()
    }



    private var playerID: Int {
        switch subject {
        case let .batter(batter, _):
            return batter.id
        case let .pitcher(pitcher):
            return pitcher.id
        }
    }

    private var playerName: String {
        switch subject {
        case let .batter(batter, _):
            return batter.fullName
        case let .pitcher(pitcher):
            return pitcher.fullName
        }
    }

    private var fallbackBioText: String {
        switch subject {
        case let .batter(batter, _):
            return AccessibilitySupport.positionDescription(batter.position)
        case .pitcher:
            return "Pitcher"
        }
    }

    private var gameStatsItems: [(label: String, value: String)] {
        switch subject {
        case let .batter(_, stats):
            let stats = stats ?? PlayerGameStats(atBats: 0, hits: 0, runs: 0, rbi: 0, walks: 0, strikeouts: 0)
            return [
                ("AB", "\(stats.atBats)"),
                ("H", "\(stats.hits)"),
                ("R", "\(stats.runs)"),
                ("RBI", "\(stats.rbi)"),
                ("BB", "\(stats.walks)"),
                ("K", "\(stats.strikeouts)")
            ]
        case let .pitcher(pitcher):
            return [
                ("IP", pitcher.ip),
                ("H", "\(pitcher.h)"),
                ("R", "\(pitcher.r)"),
                ("ER", "\(pitcher.er)"),
                ("BB", "\(pitcher.bb)"),
                ("K", "\(pitcher.k)")
            ]
        }
    }

    private func setupUI() {
        view.backgroundColor = paperColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

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

        headerLabel.text = playerName
        headerLabel.font = AppFont.permanent(28, textStyle: .largeTitle, compatibleWith: traitCollection)
        headerLabel.textColor = pencilColor
        headerLabel.textAlignment = .center
        headerLabel.numberOfLines = 2
        headerLabel.adjustsFontForContentSizeCategory = true
        headerLabel.accessibilityTraits = .header
        contentStack.addArrangedSubview(headerLabel)

        bioLabel.text = fallbackBioText
        bioLabel.font = AppFont.patrick(16, textStyle: .body, compatibleWith: traitCollection)
        bioLabel.textColor = pencilColor.withAlphaComponent(0.7)
        bioLabel.textAlignment = .center
        bioLabel.numberOfLines = 0
        bioLabel.adjustsFontForContentSizeCategory = true
        contentStack.addArrangedSubview(bioLabel)

        gameTitleLabel.text = "Today's Game"
        contentStack.addArrangedSubview(createSectionTitleLabel(from: gameTitleLabel))

        gameStatsContainer.translatesAutoresizingMaskIntoConstraints = false
        gameStatsContainer.layer.addSublayer(gameStatsLinesLayer)
        contentStack.addArrangedSubview(gameStatsContainer)
        setupGameStatsGrid()

        seasonTitleLabel.text = seasonTitleText
        contentStack.addArrangedSubview(createSectionTitleLabel(from: seasonTitleLabel))

        seasonStatsContainer.translatesAutoresizingMaskIntoConstraints = false
        seasonStatsContainer.layer.addSublayer(seasonStatsLinesLayer)
        contentStack.addArrangedSubview(seasonStatsContainer)

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

    private func createSectionTitleLabel(from label: UILabel) -> UILabel {
        label.font = AppFont.patrick(16, textStyle: .headline, compatibleWith: traitCollection)
        label.textColor = pencilColor.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.accessibilityTraits = .header
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func setupGameStatsGrid() {
        gameStatsContentView?.removeFromSuperview()

        let stackView = createStatsRow(items: gameStatsItems)
        gameStatsContainer.addSubview(stackView)
        gameStatsContentView = stackView

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: gameStatsContainer.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: gameStatsContainer.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: gameStatsContainer.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: gameStatsContainer.bottomAnchor, constant: -12)
        ])
    }

    private func setupSeasonStatsGrid(items: [(label: String, value: String)], columns: Int, title: String) {
        loadingIndicator.stopAnimating()
        loadingIndicator.removeFromSuperview()
        seasonStatsContentView?.removeFromSuperview()

        seasonGridMetrics = gridMetrics(for: items.count, preferredColumns: columns)
        seasonTitleText = title
        seasonTitleLabel.text = title

        seasonStatsContainer.constraints.forEach { constraint in
            if constraint.firstAttribute == .height {
                seasonStatsContainer.removeConstraint(constraint)
            }
        }

        let stackView = createStatsRow(items: items, fontSize: 28, preferredColumns: columns)
        seasonStatsContainer.addSubview(stackView)
        seasonStatsContentView = stackView

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: seasonStatsContainer.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: seasonStatsContainer.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: seasonStatsContainer.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: seasonStatsContainer.bottomAnchor, constant: -12)
        ])

        view.setNeedsLayout()
    }

    private func createStatsRow(items: [(label: String, value: String)], fontSize: CGFloat = 32, preferredColumns: Int? = nil) -> UIStackView {
        let metrics = gridMetrics(for: items.count, preferredColumns: preferredColumns ?? items.count)
        let rootStack = UIStackView()
        rootStack.axis = .vertical
        rootStack.distribution = .fillEqually
        rootStack.spacing = 0
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        let columns = max(metrics.columns, 1)
        let rows = max(metrics.rows, 1)

        for rowIndex in 0..<rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 0

            for columnIndex in 0..<columns {
                let itemIndex = rowIndex * columns + columnIndex
                if itemIndex < items.count {
                    rowStack.addArrangedSubview(makeStatItemView(items[itemIndex], fontSize: fontSize))
                } else {
                    let spacer = UIView()
                    rowStack.addArrangedSubview(spacer)
                }
            }

            rootStack.addArrangedSubview(rowStack)
        }

        if fontSize >= 32 {
            gameGridMetrics = metrics
        } else {
            seasonGridMetrics = metrics
        }

        return rootStack
    }

    private func makeStatItemView(_ item: (label: String, value: String), fontSize: CGFloat) -> UIView {
        let container = UIView()
        container.isAccessibilityElement = true
        container.accessibilityLabel = "\(AccessibilitySupport.statName(for: item.label)), \(item.value)"

        let itemStack = UIStackView()
        itemStack.axis = .vertical
        itemStack.alignment = .fill
        itemStack.distribution = .fill
        itemStack.spacing = 2
        itemStack.layoutMargins = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        itemStack.isLayoutMarginsRelativeArrangement = true
        itemStack.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = item.value
        valueLabel.font = AppFont.permanent(fontSize, textStyle: fontSize >= 32 ? .title2 : .title3, compatibleWith: traitCollection)
        valueLabel.textColor = pencilColor
        valueLabel.textAlignment = .center
        valueLabel.isAccessibilityElement = false
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.numberOfLines = 0
        valueLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        valueLabel.setContentHuggingPriority(.required, for: .vertical)

        let labelLabel = UILabel()
        labelLabel.text = item.label
        labelLabel.font = AppFont.patrick(16, textStyle: .caption1, compatibleWith: traitCollection)
        labelLabel.textColor = pencilColor.withAlphaComponent(0.7)
        labelLabel.textAlignment = .center
        labelLabel.isAccessibilityElement = false
        labelLabel.adjustsFontForContentSizeCategory = true
        labelLabel.numberOfLines = 0
        labelLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        itemStack.addArrangedSubview(valueLabel)
        itemStack.addArrangedSubview(labelLabel)
        container.addSubview(itemStack)

        NSLayoutConstraint.activate([
            itemStack.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor),
            itemStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            itemStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            itemStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
            itemStack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func gridMetrics(for itemCount: Int, preferredColumns: Int) -> GridMetrics {
        let isAccessibility = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let maxColumns: Int
        if isAccessibility {
            maxColumns = itemCount >= 6 ? 3 : 2
        } else if traitCollection.preferredContentSizeCategory == .extraExtraExtraLarge {
            maxColumns = min(preferredColumns, itemCount >= 6 ? 4 : 3)
        } else {
            maxColumns = preferredColumns
        }
        let columns = max(1, min(preferredColumns, maxColumns))
        let rows = Int(ceil(Double(itemCount) / Double(columns)))
        return GridMetrics(columns: columns, rows: rows)
    }

    private func fetchPlayerInfo() {
        Task {
            do {
                let info = try await GameService.shared.fetchPlayerInfo(playerId: playerID)
                self.playerInfo = info
                await MainActor.run {
                    self.updateWithPlayerInfo(info)
                }
            } catch {
                await MainActor.run {
                    self.showSeasonStatsError()
                }
            }
        }
    }

    private func updateWithPlayerInfo(_ info: PlayerInfo) {
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
            bioText += (bioText.isEmpty ? "" : "\n") + bioLine2.joined(separator: " • ")
        }
        bioLabel.text = bioText.isEmpty ? fallbackBioText : bioText
        bioLabel.accessibilityLabel = AccessibilitySupport.playerBioDescription(
            number: info.primaryNumber,
            position: info.primaryPosition?.abbreviation ?? info.primaryPosition?.name,
            team: info.currentTeam?.name,
            height: info.height,
            weight: info.weight,
            batSide: info.batSide?.code,
            throwSide: info.pitchHand?.code
        )

        switch subject {
        case .batter:
            guard let split = info.stats?
                .filter({ $0.type?.displayName == "season" })
                .compactMap({ $0.splits?.first(where: { $0.stat?.avg != nil || $0.stat?.ops != nil || $0.stat?.rbi != nil }) })
                .first,
                  let stats = split.stat else {
                showSeasonStatsError()
                return
            }
            let season = split.season.map { "\($0) season" } ?? "Season"
            setupSeasonStatsGrid(
                items: [
                    ("AVG", stats.avg ?? "---"),
                    ("HR", "\(stats.homeRuns ?? 0)"),
                    ("RBI", "\(stats.rbi ?? 0)"),
                    ("SB", "\(stats.stolenBases ?? 0)"),
                    ("OPS", stats.ops ?? "---")
                ],
                columns: 5,
                title: season
            )
        case .pitcher:
            guard let split = info.stats?
                .filter({ $0.type?.displayName == "season" })
                .compactMap({ $0.splits?.first(where: { $0.stat?.era != nil || $0.stat?.inningsPitched != nil || $0.stat?.wins != nil }) })
                .first,
                  let stats = split.stat else {
                showSeasonStatsError()
                return
            }
            let season = split.season.map { "\($0) season" } ?? "Season"
            setupSeasonStatsGrid(
                items: [
                    ("ERA", stats.era ?? "---"),
                    ("IP", stats.inningsPitched ?? "0.0"),
                    ("W", "\(stats.wins ?? 0)"),
                    ("L", "\(stats.losses ?? 0)"),
                    ("K", "\(stats.strikeOuts ?? 0)")
                ],
                columns: 5,
                title: season
            )
        }
    }

    private func showSeasonStatsError() {
        loadingIndicator.stopAnimating()
        seasonStatsContentView?.removeFromSuperview()

        let errorLabel = UILabel()
        errorLabel.text = "Stats unavailable"
        errorLabel.font = AppFont.patrick(16, textStyle: .body, compatibleWith: traitCollection)
        errorLabel.textColor = pencilColor.withAlphaComponent(0.7)
        errorLabel.textAlignment = .center
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.adjustsFontForContentSizeCategory = true
        seasonStatsContainer.addSubview(errorLabel)
        seasonStatsContentView = errorLabel

        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: seasonStatsContainer.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: seasonStatsContainer.centerYAnchor)
        ])
    }

    private func drawPencilLines() {
        drawBoxLines(for: gameStatsContainer, layer: gameStatsLinesLayer, metrics: gameGridMetrics)
        drawBoxLines(for: seasonStatsContainer, layer: seasonStatsLinesLayer, metrics: seasonGridMetrics)
    }

    private func drawBoxLines(for container: UIView, layer: CAShapeLayer, metrics: GridMetrics) {
        let b = container.bounds
        guard b.width > 0, b.height > 0 else { return }

        let path = UIBezierPath()
        path.append(UIBezierPath.pencilLine(from: .zero, to: CGPoint(x: b.width, y: 0)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: b.width, y: 0), to: CGPoint(x: b.width, y: b.height)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: b.width, y: b.height), to: CGPoint(x: 0, y: b.height)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: b.height), to: .zero))

        let columns = max(metrics.columns, 1)
        let rows = max(metrics.rows, 1)
        let colWidth = b.width / CGFloat(columns)
        for i in 1..<columns {
            let x = colWidth * CGFloat(i)
            path.append(UIBezierPath.pencilLine(from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: b.height)))
        }
        let rowHeight = b.height / CGFloat(rows)
        for i in 1..<rows {
            let y = rowHeight * CGFloat(i)
            path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: y), to: CGPoint(x: b.width, y: y)))
        }

        layer.path = path.cgPath
        layer.strokeColor = pencilColor.withAlphaComponent(0.3).cgColor
        layer.lineWidth = 1.0
        layer.fillColor = UIColor.clear.cgColor
        layer.lineCap = .round
        layer.lineJoin = .round
    }

    private func applyTypography() {
        headerLabel.font = AppFont.permanent(28, textStyle: .largeTitle, compatibleWith: traitCollection)
        bioLabel.font = AppFont.patrick(16, textStyle: .body, compatibleWith: traitCollection)
        gameTitleLabel.font = AppFont.patrick(16, textStyle: .headline, compatibleWith: traitCollection)
        seasonTitleLabel.font = AppFont.patrick(16, textStyle: .headline, compatibleWith: traitCollection)
        setupGameStatsGrid()
        if let info = playerInfo {
            updateWithPlayerInfo(info)
        }
    }
}
