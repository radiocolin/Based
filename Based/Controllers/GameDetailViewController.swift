import UIKit

class GameDetailViewController: UIViewController, ScorecardViewDelegate, GameUpdateDelegate {
    
    // UI Components
    private let teamSegmentedControl = UISegmentedControl(items: ["Away", "Home"])
    private lazy var segmentedOverlay = PencilSegmentedOverlay(segmentedControl: teamSegmentedControl)
    private let gameHeaderView = GameHeaderView()
    
    // Sticky Header Container
    private let stickyHeaderContainer = UIView()
    private let topLeftLabel: UILabel = {
        let label = UILabel()
        label.text = "BATTER"
        label.font = UIFont(name: "PatrickHand-Regular", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        label.textColor = AppColors.pencil
        label.textAlignment = .center
        label.backgroundColor = AppColors.header
        return label
    }()
    private let horizontalScrollView = UIScrollView()
    private let rightHeaderStack = UIStackView()
    
    // Content Scroll View
    private let mainScrollView = UIScrollView()
    private let mainStackView = UIStackView()
    private let scorecardView = ScorecardView()
    private let pitcherContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }()
    private let umpireLabel = UILabel()
    private let gameInfoLabel = UILabel()
    private let infoColumnsStack = UIStackView()
    
    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "LINEUP NOT YET AVAILABLE"
        label.font = UIFont(name: "PermanentMarker-Regular", size: 20) ?? .systemFont(ofSize: 20, weight: .bold)
        label.textColor = AppColors.pencil.withAlphaComponent(0.4)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    private let currentStateView = CurrentStateView()
    
    // Advisory Banner
    private let advisoryBanner = UIView()
    private let advisoryLabel = UILabel()
    private let advisoryCloseBtn = UIButton(type: .system)
    
    // Data
    private var currentGames: [ScheduleGame] = []
    private var currentLinescore: Linescore?
    private var currentScorecard: ScorecardData?
    private var currentLivePitches: [PitchEvent] = []
    private weak var liveDetailVC: AtBatDetailViewController?
    private var lastActiveAtBatKey: String?
    private let gamePk: Int

    private var teamSegmentedTopConstraint: NSLayoutConstraint?
    private var scrollBottomConstraint: NSLayoutConstraint?
    private var dismissedAdvisories: Set<String> = []
    private var segmentJustChanged = false

    private var stickyNameWidthConstraint: NSLayoutConstraint?

    // Constants
    private let inningWidth: CGFloat = 60
    private let statWidth: CGFloat = 40
    private let headerHeight: CGFloat = 32

    init(gamePk: Int, games: [ScheduleGame]) {
        self.gamePk = gamePk
        self.currentGames = games
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        
        // Re-enable edge swipe to go back (hidden back button disables it)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)
        
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: GameDetailViewController, _) in
            self.setupNavigationBar()
            self.updateStickyHeaders()
            if let scorecard = self.currentScorecard {
                self.scorecardView.configure(with: scorecard)
            }
        }
        
        GameService.shared.delegate = self
        GameService.shared.startPolling(gamePk: gamePk)
    }
    
    @objc private func tintDidChange() {
        setupNavigationBar()
        updateStickyHeaders()
        segmentedOverlay.setNeedsLayout()
        if let scorecard = currentScorecard {
            scorecardView.configure(with: scorecard)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        GameService.shared.stopPolling()
    }


    
    private func setupNavigationBar() {
        navigationItem.hidesBackButton = true
        
        let font = UIFont(name: "PermanentMarker-Regular", size: 18) ?? .systemFont(ofSize: 18)
        let pencilColor = AppColors.pencil

        let backItem = UIBarButtonItem(title: "< BACK", style: .plain, target: self, action: #selector(backTapped))
        backItem.setTitleTextAttributes([.font: font, .foregroundColor: pencilColor], for: .normal)
        backItem.setTitleTextAttributes([.font: font, .foregroundColor: pencilColor.withAlphaComponent(0.5)], for: .highlighted)
        navigationItem.leftBarButtonItem = backItem
        
        let shareItem = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(shareScorecard))
        navigationItem.rightBarButtonItem = shareItem
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.paper
        appearance.shadowColor = .clear
        configurePlainBarButtonAppearance(appearance.buttonAppearance, font: font, color: pencilColor)
        configurePlainBarButtonAppearance(appearance.backButtonAppearance, font: font, color: pencilColor)
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = pencilColor
    }
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func shareScorecard() {
        guard let scorecard = currentScorecard else { return }
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        view.isUserInteractionEnabled = false
        
        Task {
            let generator = ScorecardImageGenerator()
            let image = await generator.generate(scorecard: scorecard, linescore: self.currentLinescore)
            
            await MainActor.run {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                self.view.isUserInteractionEnabled = true
                
                let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.barButtonItem = self.navigationItem.rightBarButtonItem
                }
                self.present(activityVC, animated: true)
            }
        }
    }

    private func configurePlainBarButtonAppearance(_ appearance: UIBarButtonItemAppearance, font: UIFont, color: UIColor) {
        let normalAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let highlightedAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color.withAlphaComponent(0.5)]
        let normalState = appearance.normal
        normalState.backgroundImage = UIImage()
        normalState.titlePositionAdjustment = .zero

        let highlightedState = appearance.highlighted
        highlightedState.backgroundImage = UIImage()
        highlightedState.titlePositionAdjustment = .zero

        let focusedState = appearance.focused
        focusedState.backgroundImage = UIImage()
        focusedState.titlePositionAdjustment = .zero

        let disabledState = appearance.disabled
        disabledState.backgroundImage = UIImage()
        disabledState.titlePositionAdjustment = .zero

        appearance.normal.titleTextAttributes = normalAttributes
        appearance.highlighted.titleTextAttributes = highlightedAttributes
        appearance.focused.titleTextAttributes = normalAttributes
        appearance.disabled.titleTextAttributes = normalAttributes
    }
    
    // MARK: - GameUpdateDelegate
    
    func didUpdateLinescore(_ linescore: Linescore, pitches: [PitchEvent], gameData: GameData?) {
        self.currentLivePitches = pitches
        if liveDetailVC != nil {
            updateLiveDetailSheet(with: linescore, pitches: pitches)
        }
        updateUI(with: linescore, pitches: pitches, gameData: gameData)
    }
    
    func didUpdateScorecard(_ scorecard: ScorecardData) {
        updateScorecard(with: scorecard)
    }
    
    func didUpdateGameStatus(_ status: String) {
        // Option to show status in UI
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.paper
        
        advisoryBanner.backgroundColor = AppColors.advisoryBackground
        advisoryBanner.layer.cornerRadius = 8
        advisoryBanner.layer.borderWidth = 1.0
        advisoryBanner.layer.borderColor = UIColor.red.withAlphaComponent(0.3).cgColor
        advisoryBanner.isHidden = true
        advisoryBanner.translatesAutoresizingMaskIntoConstraints = false
        
        advisoryLabel.font = UIFont(name: "PatrickHand-Regular", size: 14)
        advisoryLabel.textColor = .red
        advisoryLabel.numberOfLines = 0
        advisoryLabel.translatesAutoresizingMaskIntoConstraints = false
        advisoryBanner.addSubview(advisoryLabel)
        
        advisoryCloseBtn.setTitle("✕", for: .normal)
        advisoryCloseBtn.tintColor = .red
        advisoryCloseBtn.addTarget(self, action: #selector(closeAdvisory), for: .touchUpInside)
        advisoryCloseBtn.translatesAutoresizingMaskIntoConstraints = false
        advisoryBanner.addSubview(advisoryCloseBtn)
        
        [teamSegmentedControl, segmentedOverlay, gameHeaderView, stickyHeaderContainer, mainScrollView, currentStateView, advisoryBanner].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        // Sticky Header Setup
        stickyHeaderContainer.backgroundColor = AppColors.paper
        
        [topLeftLabel, horizontalScrollView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            stickyHeaderContainer.addSubview($0)
        }
        
        horizontalScrollView.addSubview(rightHeaderStack)
        rightHeaderStack.translatesAutoresizingMaskIntoConstraints = false
        rightHeaderStack.axis = .horizontal
        rightHeaderStack.distribution = .fillEqually
        horizontalScrollView.showsHorizontalScrollIndicator = false
        horizontalScrollView.delegate = self
        
        // Main Scroll Setup
        mainScrollView.addSubview(mainStackView)
        mainScrollView.delegate = self
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.axis = .vertical
        mainStackView.spacing = 4 
        
        // Umpires and Game Info side by side
        infoColumnsStack.axis = .horizontal
        infoColumnsStack.alignment = .top
        infoColumnsStack.distribution = .fill
        infoColumnsStack.spacing = 12
        infoColumnsStack.addArrangedSubview(umpireLabel)
        infoColumnsStack.addArrangedSubview(gameInfoLabel)
        
        gameInfoLabel.widthAnchor.constraint(equalToConstant: 200).isActive = true
        
        [scorecardView, pitcherContainer, infoColumnsStack, placeholderLabel].forEach {
            mainStackView.addArrangedSubview($0)
        }
        
        placeholderLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        
        scorecardView.setHeadersVisible(false)
        scorecardView.delegate = self
        
        currentStateView.tapAction = { [weak self] in
            self?.showLiveAtBatDetail()
        }
        
        currentStateView.longPressAction = { [weak self] in
            self?.syncWithActiveAtBat()
        }
        
        // Bidirectional sync for horizontal scrolling
        scorecardView.horizontalScrollCallback = { [weak self] offset in
            if self?.horizontalScrollView.contentOffset.x != offset {
                self?.horizontalScrollView.contentOffset.x = offset
            }
        }
        
        umpireLabel.numberOfLines = 0
        gameInfoLabel.numberOfLines = 0
        
        let font = UIFont(name: "PatrickHand-Regular", size: 18) ?? .systemFont(ofSize: 18)
        
        teamSegmentedControl.selectedSegmentIndex = 0
        teamSegmentedControl.addTarget(self, action: #selector(teamChanged), for: .valueChanged)
        let segTap = UITapGestureRecognizer(target: self, action: #selector(segmentTapped))
        segTap.cancelsTouchesInView = false
        teamSegmentedControl.addGestureRecognizer(segTap)
        
        // Strip all native chrome — pencil overlay provides the visuals
        let clear = UIImage()
        teamSegmentedControl.setBackgroundImage(clear, for: .normal, barMetrics: .default)
        teamSegmentedControl.setBackgroundImage(clear, for: .selected, barMetrics: .default)
        teamSegmentedControl.setBackgroundImage(clear, for: .highlighted, barMetrics: .default)
        teamSegmentedControl.setDividerImage(clear, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
        teamSegmentedControl.setDividerImage(clear, forLeftSegmentState: .selected, rightSegmentState: .normal, barMetrics: .default)
        teamSegmentedControl.setDividerImage(clear, forLeftSegmentState: .normal, rightSegmentState: .selected, barMetrics: .default)
        
        let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: AppColors.pencil.withAlphaComponent(0.6)]
        let selectedAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: AppColors.pencil]
        teamSegmentedControl.setTitleTextAttributes(normalAttrs, for: .normal)
        teamSegmentedControl.setTitleTextAttributes(selectedAttrs, for: .selected)
        
        NSLayoutConstraint.activate([
            advisoryBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            advisoryBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            advisoryBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            advisoryLabel.topAnchor.constraint(equalTo: advisoryBanner.topAnchor, constant: 8),
            advisoryLabel.leadingAnchor.constraint(equalTo: advisoryBanner.leadingAnchor, constant: 12),
            advisoryLabel.trailingAnchor.constraint(equalTo: advisoryCloseBtn.leadingAnchor, constant: -8),
            advisoryLabel.bottomAnchor.constraint(equalTo: advisoryBanner.bottomAnchor, constant: -8),
            
            advisoryCloseBtn.centerYAnchor.constraint(equalTo: advisoryBanner.centerYAnchor),
            advisoryCloseBtn.trailingAnchor.constraint(equalTo: advisoryBanner.trailingAnchor, constant: -8),
            advisoryCloseBtn.widthAnchor.constraint(equalToConstant: 30),
        ])
        
        teamSegmentedTopConstraint = teamSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        
        NSLayoutConstraint.activate([
            teamSegmentedTopConstraint!,
            teamSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            teamSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            teamSegmentedControl.heightAnchor.constraint(equalToConstant: 40),
            
            segmentedOverlay.topAnchor.constraint(equalTo: teamSegmentedControl.topAnchor),
            segmentedOverlay.leadingAnchor.constraint(equalTo: teamSegmentedControl.leadingAnchor),
            segmentedOverlay.trailingAnchor.constraint(equalTo: teamSegmentedControl.trailingAnchor),
            segmentedOverlay.bottomAnchor.constraint(equalTo: teamSegmentedControl.bottomAnchor),
            
            gameHeaderView.topAnchor.constraint(equalTo: teamSegmentedControl.bottomAnchor, constant: 8),
            gameHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gameHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Sticky Container
            stickyHeaderContainer.topAnchor.constraint(equalTo: gameHeaderView.bottomAnchor, constant: 8),
            stickyHeaderContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stickyHeaderContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stickyHeaderContainer.heightAnchor.constraint(equalToConstant: headerHeight),
            
            topLeftLabel.leadingAnchor.constraint(equalTo: stickyHeaderContainer.leadingAnchor),
            topLeftLabel.topAnchor.constraint(equalTo: stickyHeaderContainer.topAnchor),
            topLeftLabel.bottomAnchor.constraint(equalTo: stickyHeaderContainer.bottomAnchor),
            
            horizontalScrollView.leadingAnchor.constraint(equalTo: topLeftLabel.trailingAnchor),
            horizontalScrollView.topAnchor.constraint(equalTo: stickyHeaderContainer.topAnchor),
            horizontalScrollView.trailingAnchor.constraint(equalTo: stickyHeaderContainer.trailingAnchor),
            horizontalScrollView.bottomAnchor.constraint(equalTo: stickyHeaderContainer.bottomAnchor),
            
            rightHeaderStack.topAnchor.constraint(equalTo: horizontalScrollView.contentLayoutGuide.topAnchor),
            rightHeaderStack.leadingAnchor.constraint(equalTo: horizontalScrollView.contentLayoutGuide.leadingAnchor),
            rightHeaderStack.trailingAnchor.constraint(equalTo: horizontalScrollView.contentLayoutGuide.trailingAnchor),
            rightHeaderStack.bottomAnchor.constraint(equalTo: horizontalScrollView.contentLayoutGuide.bottomAnchor),
            rightHeaderStack.heightAnchor.constraint(equalTo: horizontalScrollView.frameLayoutGuide.heightAnchor),

            // Main Scroll
            mainScrollView.topAnchor.constraint(equalTo: stickyHeaderContainer.bottomAnchor),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            mainStackView.topAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.topAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            mainStackView.trailingAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            mainStackView.bottomAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            mainStackView.widthAnchor.constraint(equalTo: mainScrollView.frameLayoutGuide.widthAnchor, constant: -32),
            
            currentStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            currentStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            currentStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            currentStateView.heightAnchor.constraint(equalToConstant: 190)
        ])
        
        // Start with live panel hidden; scroll view fills to bottom
        currentStateView.isHidden = true
        scrollBottomConstraint = mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        scrollBottomConstraint?.isActive = true
        stickyNameWidthConstraint = topLeftLabel.widthAnchor.constraint(equalToConstant: 90)
        stickyNameWidthConstraint?.isActive = true
    }

    private func updateStickyHeaders() {
        // Sync name column width with scorecard
        stickyNameWidthConstraint?.constant = scorecardView.currentNameWidth
        rightHeaderStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rightHeaderStack.distribution = .fill
        let layout = scorecardView.currentColumnLayout
        for inningLayout in layout.innings {
            let label = UILabel()
            label.text = "\(inningLayout.inningNum)"
            label.textAlignment = .center
            label.font = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
            label.textColor = AppColors.pencil
            label.backgroundColor = AppColors.header
            label.layer.borderWidth = 0.5
            label.layer.borderColor = AppColors.grid.cgColor
            label.widthAnchor.constraint(equalToConstant: inningWidth * CGFloat(inningLayout.subColumnCount)).isActive = true
            rightHeaderStack.addArrangedSubview(label)
        }
        for stat in layout.statColumns {
            let label = UILabel()
            label.text = stat
            label.textAlignment = .center
            label.font = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
            label.textColor = AppColors.pencil
            label.backgroundColor = AppColors.header
            label.layer.borderWidth = 0.5
            label.layer.borderColor = AppColors.grid.cgColor
            label.widthAnchor.constraint(equalToConstant: statWidth).isActive = true
            rightHeaderStack.addArrangedSubview(label)
        }
    }

    private func updateUI(with linescore: Linescore, pitches: [PitchEvent], gameData: GameData? = nil) {
        self.currentLinescore = linescore
        let game = currentGames.first(where: { $0.gamePk == gamePk })
        let awayName = game?.teams.away.team.name ?? "Away"
        let homeName = game?.teams.home.team.name ?? "Home"
        
        gameHeaderView.configure(with: linescore, awayNameOverride: awayName, homeNameOverride: homeName)
        currentStateView.configure(with: linescore, pitches: pitches, gameData: gameData)
        updatePlaceholderVisibility()
        
        let state = linescore.inningState?.lowercased() ?? ""
        let liveStates = ["top", "bottom", "mid", "end", "in progress", "live"]
        var isLive = liveStates.contains(where: { state.contains($0) })
        
        if state.contains("final") || state.contains("scheduled") || state.contains("pre-game") || state.contains("warmup") {
            isLive = false
        }
        
        // Override with authoritative game status from schedule data
        let gameStatus = game?.status.detailedState ?? ""
        let statusCode = game?.status.statusCode ?? ""
        if gameStatus == "Final" || gameStatus == "Game Over" || gameStatus == "Completed Early" || statusCode == "F" || statusCode == "O" {
            isLive = false
        }
        
        let isDuringBreak = state == "mid" || state == "end"
        
        // Always ensure scroll view bottom matches live panel state
        let needsUpdate = currentStateView.isHidden == isLive
        let applyLayout = {
            self.currentStateView.isHidden = !isLive
            self.scrollBottomConstraint?.isActive = false
            self.scrollBottomConstraint = self.mainScrollView.bottomAnchor.constraint(
                equalTo: isLive ? self.currentStateView.topAnchor : self.view.bottomAnchor
            )
            self.scrollBottomConstraint?.isActive = true
            self.view.layoutIfNeeded()
        }
        
        if needsUpdate {
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .beginFromCurrentState) {
                applyLayout()
            }
        } else {
            applyLayout()
        }
        
        scorecardView.setIsLive(isLive && !isDuringBreak)
    }

    private func updateScorecard(with scorecard: ScorecardData) {
        let previousScorecard = self.currentScorecard
        let isFirstLoad = previousScorecard == nil
        let previousIsTop = previousScorecard?.isTopInning ?? true
        let wasViewingBattingTeam = !isFirstLoad && teamSegmentedControl.selectedSegmentIndex == (previousIsTop ? 0 : 1)
        self.currentScorecard = scorecard
        
        // Update Segmented Control Titles with prominent at-bat indicator
        let awayName = scorecard.teams.away.name ?? "Away"
        let homeName = scorecard.teams.home.name ?? "Home"
        
        let pencilColor = AppColors.pencil
        let font = UIFont(name: "PatrickHand-Regular", size: 18) ?? .systemFont(ofSize: 18)
        let boldFont = UIFont(name: "PermanentMarker-Regular", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        
        let isTop = scorecard.isTopInning ?? true
        
        // Away (Index 0)
        let awayAttrTitle = NSMutableAttributedString(string: isTop ? "● \(awayName)" : awayName)
        awayAttrTitle.addAttributes([.font: isTop ? boldFont : font, .foregroundColor: isTop ? pencilColor : pencilColor.withAlphaComponent(0.6)], range: NSRange(location: 0, length: awayAttrTitle.length))
        
        // Home (Index 1)
        let homeAttrTitle = NSMutableAttributedString(string: !isTop ? "● \(homeName)" : homeName)
        homeAttrTitle.addAttributes([.font: !isTop ? boldFont : font, .foregroundColor: !isTop ? pencilColor : pencilColor.withAlphaComponent(0.6)], range: NSRange(location: 0, length: homeAttrTitle.length))
        
        // Use standard titles since UISegmentedControl attributedTitle support can be finicky with custom fonts across iOS versions
        teamSegmentedControl.setTitle(isTop ? "● \(awayName)" : awayName, forSegmentAt: 0)
        teamSegmentedControl.setTitle(!isTop ? "● \(homeName)" : homeName, forSegmentAt: 1)
        
        // Default to the team at bat on first load
        if isFirstLoad {
            setDisplayedTeam(toBattingTeamForTopInning: isTop)
        } else if previousScorecard?.isTopInning != scorecard.isTopInning && wasViewingBattingTeam {
            setDisplayedTeam(toBattingTeamForTopInning: isTop)
        }
        
        scorecardView.configure(with: scorecard)
        updateStickyHeaders()
        updatePitcherList()
        updateUmpireList()
        updateGameInfo()
        updatePlaceholderVisibility()
        
        let inning = scorecard.currentInning ?? 1
        let currentIsTop = scorecard.isTopInning ?? true
        let batterId = scorecard.currentBatterId ?? 0
        let newKey = "\(inning)-\(currentIsTop)-\(batterId)"
        
        if isFirstLoad {
            syncWithActiveAtBat()
        } else if newKey != lastActiveAtBatKey && batterId != 0 {
            // Auto-scroll only if viewing the team at bat
            let viewingBattingTeam = (currentIsTop && teamSegmentedControl.selectedSegmentIndex == 0) ||
                                     (!currentIsTop && teamSegmentedControl.selectedSegmentIndex == 1)
            if viewingBattingTeam {
                scrollToActiveCell(scorecard: scorecard)
            }
        }
        
        lastActiveAtBatKey = newKey
        
        // Update advisory banner
        if let advisory = scorecard.advisories.first, !dismissedAdvisories.contains(advisory) {
            advisoryLabel.text = advisory
            advisoryBanner.isHidden = false
            teamSegmentedTopConstraint?.isActive = false
            teamSegmentedTopConstraint = teamSegmentedControl.topAnchor.constraint(equalTo: advisoryBanner.bottomAnchor, constant: 8)
            teamSegmentedTopConstraint?.isActive = true
        } else {
            advisoryBanner.isHidden = true
            teamSegmentedTopConstraint?.isActive = false
            teamSegmentedTopConstraint = teamSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
            teamSegmentedTopConstraint?.isActive = true
        }
    }
    
    @objc private func closeAdvisory() {
        if let current = advisoryLabel.text {
            dismissedAdvisories.insert(current)
        }
        
        UIView.animate(withDuration: 0.3) {
            self.advisoryBanner.isHidden = true
            self.teamSegmentedTopConstraint?.isActive = false
            self.teamSegmentedTopConstraint = self.teamSegmentedControl.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 8)
            self.teamSegmentedTopConstraint?.isActive = true
            self.view.layoutIfNeeded()
        }
    }

    @objc private func teamChanged() {
        segmentJustChanged = true
        let isHome = teamSegmentedControl.selectedSegmentIndex == 1
        scorecardView.setTeam(isHome: isHome)
        updateStickyHeaders()
        updatePitcherList()
        updatePlaceholderVisibility()
    }

    @objc private func segmentTapped() {
        if segmentJustChanged {
            segmentJustChanged = false
            return
        }
        // Tapped the already-selected segment — jump to active at-bat
        syncWithActiveAtBat()
    }

    private func updatePlaceholderVisibility() {
        guard let scorecard = currentScorecard else { 
            showPlaceholder(true)
            return 
        }
        
        let isHome = teamSegmentedControl.selectedSegmentIndex == 1
        let lineup = isHome ? scorecard.lineups.home : scorecard.lineups.away
        
        showPlaceholder(lineup.isEmpty)
    }

    private func showPlaceholder(_ show: Bool) {
        if placeholderLabel.isHidden != !show {
            UIView.animate(withDuration: 0.3) {
                self.placeholderLabel.isHidden = !show
                self.scorecardView.isHidden = show
                self.stickyHeaderContainer.isHidden = show
                self.pitcherContainer.isHidden = show
                self.infoColumnsStack.isHidden = show
                self.view.layoutIfNeeded()
            }
        }
        
        if show {
            placeholderLabel.text = "LINEUP NOT YET AVAILABLE"
        }
    }

    private func showLiveAtBatDetail() {
        guard let linescore = currentLinescore else { return }
        
        let liveEvent = constructLiveAtBatEvent(linescore: linescore, pitches: currentLivePitches)
        let batterName = linescore.offense?.batter?.fullName ?? "Batter"
        let pitcherName = linescore.defense?.pitcher?.fullName ?? "Pitcher"
        
        let vc = AtBatDetailViewController(event: liveEvent, batterName: batterName, pitcherName: pitcherName)
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        self.liveDetailVC = vc
        present(vc, animated: true)
    }

    private func constructLiveAtBatEvent(linescore: Linescore, pitches: [PitchEvent]) -> AtBatEvent {
        // Derive balls/strikes from the actual pitches we have if it's more consistent with the list shown
        let derivedBalls = pitches.filter { $0.isBall }.count
        let derivedStrikes = pitches.filter { $0.isStrike }.count
        
        // Use the higher of the two (linescore is usually more live, but pitches array is what we show)
        // If we only show 1 pitch, but the linescore says 2 strikes, it looks broken.
        // We'll trust the pitches list for the detail sheet to avoid this discrepancy.
        let finalBalls = pitches.isEmpty ? (linescore.balls ?? 0) : derivedBalls
        let finalStrikes = pitches.isEmpty ? (linescore.strikes ?? 0) : derivedStrikes
        
        return AtBatEvent(
            batterId: linescore.offense?.batter?.id ?? 0,
            result: "LIVE",
            description: "Current at bat",
            balls: finalBalls,
            strikes: finalStrikes,
            outs: linescore.outs ?? 0,
            rbi: 0,
            bases: BasesReached(
                first: linescore.offense?.first != nil,
                second: linescore.offense?.second != nil,
                third: linescore.offense?.third != nil,
                home: false,
                outAtFirst: false,
                outAtSecond: false,
                outAtThird: false,
                outAtHome: false
            ),
            pitches: pitches
        )
    }

    private func updateLiveDetailSheet(with linescore: Linescore, pitches: [PitchEvent]) {
        guard let liveVC = liveDetailVC else { return }
        let updatedEvent = constructLiveAtBatEvent(linescore: linescore, pitches: pitches)
        liveVC.update(event: updatedEvent)
    }

    private func updateUmpireList() {
        guard let scorecard = currentScorecard else { return }
        let umpires = scorecard.umpires
        let umpireStrings = umpires.map { "\($0.type): \($0.fullName)" }
        
        let attributedText = NSMutableAttributedString(string: "UMPIRES\n", attributes: [
            .font: UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: AppColors.pencil
        ])
        attributedText.append(NSAttributedString(string: umpireStrings.joined(separator: "\n"), attributes: [
            .font: UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14),
            .foregroundColor: AppColors.pencil.withAlphaComponent(0.7)
        ]))
        
        umpireLabel.attributedText = umpireStrings.isEmpty ? nil : attributedText
    }

    private func updatePitcherList() {
        guard let scorecard = currentScorecard else { return }
        let isHome = teamSegmentedControl.selectedSegmentIndex == 1
        let pitchers = isHome ? scorecard.pitchers.home : scorecard.pitchers.away
        
        pitcherContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        guard !pitchers.isEmpty else { return }
        
        let titleLabel = UILabel()
        titleLabel.text = "PITCHERS"
        titleLabel.font = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = AppColors.pencil
        pitcherContainer.addArrangedSubview(titleLabel)
        
        // Header Row
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 4
        
        let nameHeader = UILabel()
        nameHeader.text = "NAME"
        nameHeader.font = UIFont(name: "PatrickHand-Regular", size: 12) ?? .systemFont(ofSize: 12, weight: .bold)
        nameHeader.textColor = AppColors.pencil.withAlphaComponent(0.6)
        headerRow.addArrangedSubview(nameHeader)
        
        let statLabels = ["IP", "H", "R", "ER", "BB", "K"]
        for label in statLabels {
            let l = UILabel()
            l.text = label
            l.font = UIFont(name: "PatrickHand-Regular", size: 12) ?? .systemFont(ofSize: 12, weight: .bold)
            l.textColor = AppColors.pencil.withAlphaComponent(0.6)
            l.textAlignment = .center
            l.widthAnchor.constraint(equalToConstant: 30).isActive = true
            headerRow.addArrangedSubview(l)
        }
        pitcherContainer.addArrangedSubview(headerRow)
        
        // Pitcher Rows
        for (idx, pitcher) in pitchers.enumerated() {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 4
            row.backgroundColor = idx % 2 == 1 ? AppColors.alternateRow.withAlphaComponent(0.5) : .clear
            
            let nameLabel = UILabel()
            nameLabel.text = pitcher.fullName
            nameLabel.font = UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14)
            nameLabel.textColor = AppColors.pencil
            row.addArrangedSubview(nameLabel)
            
            let stats = [pitcher.ip, "\(pitcher.h)", "\(pitcher.r)", "\(pitcher.er)", "\(pitcher.bb)", "\(pitcher.k)"]
            for val in stats {
                let l = UILabel()
                l.text = val
                l.font = UIFont(name: "PermanentMarker-Regular", size: 12) ?? .systemFont(ofSize: 12)
                l.textColor = AppColors.pencil
                l.textAlignment = .center
                l.widthAnchor.constraint(equalToConstant: 30).isActive = true
                row.addArrangedSubview(l)
            }
            
            pitcherContainer.addArrangedSubview(row)
        }
    }

    private func updateGameInfo() {
        guard let scorecard = currentScorecard else { return }
        
        // Filter to game info fields we want below the scorecard
        let displayLabels = ["First pitch", "T", "Att", "Venue"]
        let infoItems = scorecard.gameInfo.filter { item in
            displayLabels.contains(item.label) && item.value != nil
        }
        
        // Also find a date entry (label with no value)
        let dateItem = scorecard.gameInfo.first { $0.value == nil && !$0.label.isEmpty }
        
        guard !infoItems.isEmpty || dateItem != nil else {
            gameInfoLabel.attributedText = nil
            return
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
        
        if let dateItem = dateItem {
            attributedText.append(NSAttributedString(string: dateItem.label, attributes: valueAttrs))
        }
        
        gameInfoLabel.attributedText = attributedText
    }

    // MARK: - ScorecardViewDelegate
    func didSelectAtBat(_ event: AtBatEvent, batter: ScorecardBatter, pitcherName: String) {
        let actualPitcher = currentLinescore?.defense?.pitcher?.fullName ?? pitcherName
        let vc = AtBatDetailViewController(event: event, batterName: batter.fullName, pitcherName: actualPitcher)
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }

    func didSelectPlayer(_ batter: ScorecardBatter) {
        let vc = PlayerDetailViewController(batter: batter, gameStats: calculatePlayerStats(for: batter))
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }

    func didSelectActiveAtBat() {
        showLiveAtBatDetail()
    }

    private func syncWithActiveAtBat() {
        guard let scorecard = currentScorecard else { return }
        
        // Swap to the team at bat
        let isTop = scorecard.isTopInning ?? true
        setDisplayedTeam(toBattingTeamForTopInning: isTop)
        self.updatePitcherList()
        self.updatePlaceholderVisibility()
        
        self.scrollToActiveCell(scorecard: scorecard)
    }

    private func setDisplayedTeam(toBattingTeamForTopInning isTop: Bool) {
        teamSegmentedControl.selectedSegmentIndex = isTop ? 0 : 1
        segmentedOverlay.setNeedsLayout()
        scorecardView.setTeam(isHome: !isTop)
    }

    private func scrollToActiveCell(scorecard: ScorecardData) {
        guard let inningNum = scorecard.currentInning,
              let batterId = scorecard.currentBatterId,
              let isTop = scorecard.isTopInning else { return }
        
        let isHomeTeamAtBat = !isTop
        let isViewingTeamAtBat = (teamSegmentedControl.selectedSegmentIndex == 1 && isHomeTeamAtBat) ||
                                (teamSegmentedControl.selectedSegmentIndex == 0 && !isHomeTeamAtBat)
        
        if isViewingTeamAtBat {
            let lineup = isHomeTeamAtBat ? scorecard.lineups.home : scorecard.lineups.away
            guard let rowIndex = lineup.firstIndex(where: { $0.id == batterId }) else { return }
            
            let layout = scorecardView.currentColumnLayout
            guard let inningLayout = layout.layout(forInning: inningNum) else { return }
            let colIndex = inningLayout.startColumn + inningLayout.subColumnCount - 1
            let cellWidth: CGFloat = 60
            let rowHeight: CGFloat = 70
            
            // Wait for layout to settle, then scroll
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                
                // 1. Horizontal Scroll — clamp to max scrollable offset
                let maxHOffset = max(0, self.scorecardView.horizontalContentWidth - self.scorecardView.horizontalVisibleWidth)
                let hOffset = min(max(0, CGFloat(colIndex) * cellWidth - (self.view.bounds.width / 2) + (cellWidth / 2)), maxHOffset)
                self.scorecardView.syncHorizontalOffset(hOffset)
                
                // 2. Vertical Scroll
                let rowY = CGFloat(rowIndex) * rowHeight
                let scorecardY = scorecardView.frame.origin.y

                // Scroll view frame already accounts for live panel via constraints
                let visibleHeight = mainScrollView.bounds.height

                // Center the row in the remaining visible height
                let targetY = max(0, scorecardY + rowY - (visibleHeight / 2) + (rowHeight / 2))
                let maxVOffset = max(0, mainScrollView.contentSize.height - mainScrollView.bounds.height + mainScrollView.contentInset.bottom)

                mainScrollView.setContentOffset(CGPoint(x: 0, y: min(targetY, maxVOffset)), animated: true)            }
        }
    }

    private func calculatePlayerStats(for batter: ScorecardBatter) -> PlayerGameStats {
        guard let scorecard = currentScorecard else { return PlayerGameStats(atBats: 0, hits: 0, runs: 0, rbi: 0, walks: 0, strikeouts: 0) }
        let isHome = teamSegmentedControl.selectedSegmentIndex == 1
        return scorecard.calculatePlayerStats(for: batter.id, isHome: isHome)
    }
}

extension GameDetailViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == horizontalScrollView {
            // Header scroll -> Card scroll
            scorecardView.syncHorizontalOffset(scrollView.contentOffset.x)
        }
    }
}

extension GameDetailViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only allow the pop gesture when there's something to pop back to
        return (navigationController?.viewControllers.count ?? 0) > 1
    }
}
