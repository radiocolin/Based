import UIKit

class GameDetailViewController: UIViewController, ScorecardViewDelegate, GameUpdateDelegate, TimelineViewDelegate {
    
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
    private let timelineView = TimelineView()
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
    private var currentSnapshot: LiveGameSnapshot?
    private var currentLinescore: Linescore?
    private var currentScorecard: ScorecardData?
    private var currentGameData: GameData?
    private var currentUmpires: [ScorecardUmpire] = []
    private var currentGameInfo: [GameInfoItem] = []
    private var currentPitchers: [ScorecardPitcher] = []
    private weak var liveDetailVC: AtBatDetailViewController?
    private var lastActiveAtBatKey: String?
    private let gamePk: Int
    private var isGameLive = false
    private var isTimelineMode = UserDefaults.standard.bool(forKey: "preferTimelineMode") {
        didSet {
            let inset = isTimelineMode ? hiddenSegmentedTopInset : visibleSegmentedTopInset
            teamSegmentedSafeTopConstraint?.constant = inset
            teamSegmentedAdvisoryTopConstraint?.constant = inset
        }
    }

    private var teamSegmentedSafeTopConstraint: NSLayoutConstraint?
    private var teamSegmentedAdvisoryTopConstraint: NSLayoutConstraint?
    private var scrollBottomConstraint: NSLayoutConstraint?
    private var timelineBottomConstraint: NSLayoutConstraint?
    private var dismissedAdvisories: Set<String> = []
    private var segmentJustChanged = false

    private var stickyNameWidthConstraint: NSLayoutConstraint?

    // Constants
    private let inningWidth: CGFloat = 56
    private let statWidth: CGFloat = 38
    private let headerHeight: CGFloat = 32
    private let visibleSegmentedTopInset: CGFloat = 8
    private let hiddenSegmentedTopInset: CGFloat = -48

    init(gamePk: Int, games: [ScheduleGame]) {
        self.gamePk = gamePk
        self.currentGames = games
        // Derive initial live state from schedule data so we don't have to wait for fetches
        let game = games.first(where: { $0.gamePk == gamePk })
        let state = game?.status.detailedState.lowercased() ?? ""
        let code = game?.status.statusCode?.lowercased() ?? ""
        let isFinal = state == "final" || state == "game over" || state == "completed early" || code == "f" || code == "o"
        let isScheduled = state == "scheduled" || state == "pre-game" || state == "postponed" || code == "s" || code == "p"
        self.isGameLive = !isFinal && !isScheduled && !state.isEmpty
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
            self.advisoryBanner.layer.borderColor = UIColor.red.withAlphaComponent(0.3).cgColor
            if let scorecard = self.currentScorecard {
                self.scorecardView.configure(with: scorecard)
            }
        }
        
        // Apply saved view mode without animation
        if isTimelineMode {
            updateUIForMode()
            teamSegmentedControl.isHidden = true
            segmentedOverlay.isHidden = true
            stickyHeaderContainer.isHidden = true
            mainScrollView.isHidden = true
            timelineView.isHidden = false
        }
        
        GameService.shared.delegate = self
        GameService.shared.startPolling(gamePk: gamePk)
    }
    
    @objc private func tintDidChange() {
        setupNavigationBar()
        updateStickyHeaders()
        segmentedOverlay.setNeedsLayout()
        updateTeamSegmentedControlTitles()
        if let scorecard = currentScorecard {
            scorecardView.configure(with: scorecard)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            GameService.shared.stopPolling()
        }
    }


    
    private func setupNavigationBar() {
        navigationItem.hidesBackButton = true
        
        let font = UIFont(name: "PermanentMarker-Regular", size: 18) ?? .systemFont(ofSize: 18)
        let pencilColor = AppColors.pencil

        // Custom Back Button with wobbly chevron
        let backBtn = UIButton(type: .system)
        let chevronImg = UIImage.pencilStyledIcon(named: "chevron.backward", color: pencilColor, size: CGSize(width: 20, height: 20))
        
        let backFont = UIFont(name: "PatrickHand-Regular", size: 20) ?? .systemFont(ofSize: 20)
        
        var config = UIButton.Configuration.plain()
        config.image = chevronImg
        config.title = "Back"
        config.imagePadding = 2
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10)
        
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = backFont
            return outgoing
        }
        
        backBtn.configuration = config
        backBtn.tintColor = pencilColor
        backBtn.accessibilityLabel = "Back"
        backBtn.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backBtn)
        
        let iconSize = CGSize(width: 32, height: 32)
        let shareImg = UIImage.pencilStyledIcon(named: "square.and.arrow.up", color: pencilColor, size: iconSize, offset: CGPoint(x: -0.5, y: 0), scaleMultiplier: 0.9)
        let shareItem = UIBarButtonItem(image: shareImg, style: .plain, target: self, action: #selector(shareScorecard))
        shareItem.accessibilityLabel = "Share scorecard"
        
        let timelineSymbol = isTimelineMode ? "square.grid.3x2" : "calendar.day.timeline.left"
        let timelineImg = UIImage.pencilStyledIcon(named: timelineSymbol, color: pencilColor, size: iconSize, offset: CGPoint(x: 1.5, y: 1.0))
        let timelineItem = UIBarButtonItem(image: timelineImg, style: .plain, target: self, action: #selector(toggleTimelineMode))
        timelineItem.accessibilityLabel = isTimelineMode ? "Show scorecard" : "Show timeline"
        
        navigationItem.rightBarButtonItems = [shareItem, timelineItem]
        
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

    @objc private func toggleTimelineMode() {
        isTimelineMode.toggle()
        UserDefaults.standard.set(isTimelineMode, forKey: "preferTimelineMode")
        
        self.setupNavigationBar()

        if isTimelineMode {
            timelineView.isHidden = false
            timelineView.alpha = 0
        } else {
            teamSegmentedControl.isHidden = false
            segmentedOverlay.isHidden = false
            stickyHeaderContainer.isHidden = false
            mainScrollView.isHidden = false
        }

        // Swap live panel placement
        if isGameLive {
            if isTimelineMode {
                // Moving to timeline: hide bottom panel, show embedded
                currentStateView.isHidden = true
                timelineView.setLiveState(visible: true)
                timelineBottomConstraint?.isActive = false
                timelineBottomConstraint = timelineView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                timelineBottomConstraint?.isActive = true
            } else {
                // Moving to scorecard: show bottom panel, hide embedded
                timelineView.setLiveState(visible: false)
                currentStateView.isHidden = false
                scrollBottomConstraint?.isActive = false
                scrollBottomConstraint = mainScrollView.bottomAnchor.constraint(equalTo: currentStateView.topAnchor)
                scrollBottomConstraint?.isActive = true
            }
        }

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: .curveEaseInOut) {
            self.updateUIForMode()
            self.view.layoutIfNeeded()
        } completion: { _ in
            if self.isTimelineMode {
                self.teamSegmentedControl.isHidden = true
                self.segmentedOverlay.isHidden = true
                self.stickyHeaderContainer.isHidden = true
                self.mainScrollView.isHidden = true
            } else {
                self.timelineView.isHidden = true
            }
        }
    }

    private func updateUIForMode() {
        teamSegmentedControl.alpha = isTimelineMode ? 0 : 1
        segmentedOverlay.alpha = isTimelineMode ? 0 : 1
        stickyHeaderContainer.alpha = isTimelineMode ? 0 : 1
        mainScrollView.alpha = isTimelineMode ? 0 : 1
        timelineView.alpha = isTimelineMode ? 1 : 0
        
        // Adjust constraints to move headers
        let inset = isTimelineMode ? hiddenSegmentedTopInset : visibleSegmentedTopInset
        teamSegmentedSafeTopConstraint?.constant = inset
        teamSegmentedAdvisoryTopConstraint?.constant = inset
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
    
    func didUpdateSnapshot(_ snapshot: LiveGameSnapshot) {
        currentSnapshot = snapshot
        currentLinescore = snapshot.linescore
        currentGameData = snapshot.gameData

        // Update live state before scorecard so all decisions see the correct value
        let wasLive = isGameLive
        isGameLive = snapshot.isGameLive

        if let scorecard = snapshot.scorecard, scorecard != currentScorecard {
            updateScorecard(with: scorecard)
        }

        if let currentAtBat = snapshot.currentAtBat {
            updateLiveDetailSheet(with: currentAtBat)
        }

        updateUI(with: snapshot, wasLive: wasLive)
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
        advisoryCloseBtn.accessibilityLabel = "Dismiss advisory"
        advisoryCloseBtn.addTarget(self, action: #selector(closeAdvisory), for: .touchUpInside)
        advisoryCloseBtn.translatesAutoresizingMaskIntoConstraints = false
        advisoryBanner.addSubview(advisoryCloseBtn)
        
        [teamSegmentedControl, segmentedOverlay, gameHeaderView, stickyHeaderContainer, mainScrollView, timelineView, currentStateView, advisoryBanner].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        timelineView.isHidden = true
        timelineView.alpha = 0
        timelineView.delegate = self
        stickyHeaderContainer.isAccessibilityElement = false
        topLeftLabel.isAccessibilityElement = false
        horizontalScrollView.isAccessibilityElement = false
        rightHeaderStack.isAccessibilityElement = false
        
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
        
        let gameInfoWidth = gameInfoLabel.widthAnchor.constraint(equalToConstant: 200)
        gameInfoWidth.priority = .init(999)
        gameInfoWidth.isActive = true
        
        [scorecardView, pitcherContainer, infoColumnsStack, placeholderLabel].forEach {
            mainStackView.addArrangedSubview($0)
        }
        
        let placeholderHeight = placeholderLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        placeholderHeight.priority = .init(999)
        placeholderHeight.isActive = true
        
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
        teamSegmentedControl.accessibilityLabel = "Batting team"
        teamSegmentedControl.accessibilityHint = "Choose the away or home scorecard."
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
        
        teamSegmentedSafeTopConstraint = teamSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: isTimelineMode ? hiddenSegmentedTopInset : visibleSegmentedTopInset)
        teamSegmentedAdvisoryTopConstraint = teamSegmentedControl.topAnchor.constraint(equalTo: advisoryBanner.bottomAnchor, constant: isTimelineMode ? hiddenSegmentedTopInset : visibleSegmentedTopInset)
        
        NSLayoutConstraint.activate([
            teamSegmentedSafeTopConstraint!,
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
            {
                let c = stickyHeaderContainer.heightAnchor.constraint(equalToConstant: headerHeight)
                c.priority = .init(999)
                return c
            }(),
            
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
            {
                let c = mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
                c.priority = UILayoutPriority(999)
                return c
            }(),
            
            // Timeline
            timelineView.topAnchor.constraint(equalTo: gameHeaderView.bottomAnchor, constant: 8),
            timelineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            {
                let c = timelineView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
                c.priority = UILayoutPriority(999)
                return c
            }(),
            
            mainStackView.topAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.topAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            {
                let c = mainStackView.trailingAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.trailingAnchor, constant: -16)
                c.priority = UILayoutPriority(999)
                return c
            }(),
            mainStackView.bottomAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            mainStackView.widthAnchor.constraint(equalTo: mainScrollView.frameLayoutGuide.widthAnchor, constant: -32),
            
            currentStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            currentStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            {
                let c = currentStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
                c.priority = UILayoutPriority(999)
                return c
            }(),
            currentStateView.heightAnchor.constraint(equalToConstant: 190)
        ])
        
        // Start with live panel hidden; scroll view fills to bottom
        currentStateView.isHidden = true
        scrollBottomConstraint = mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        scrollBottomConstraint?.isActive = true
        
        timelineBottomConstraint = timelineView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        timelineBottomConstraint?.isActive = true
        
        stickyNameWidthConstraint = topLeftLabel.widthAnchor.constraint(equalToConstant: 90)
        stickyNameWidthConstraint?.priority = .init(999)
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
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = "\(inningLayout.inningNum)"
            label.textAlignment = .center
            label.font = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
            label.textColor = AppColors.pencil
            label.backgroundColor = AppColors.header
            label.isAccessibilityElement = false
            label.layer.borderWidth = 0.5
            label.layer.borderColor = AppColors.grid.cgColor
            
            let width = inningWidth * CGFloat(inningLayout.subColumnCount)
            let widthConstraint = label.widthAnchor.constraint(equalToConstant: width)
            widthConstraint.priority = .init(999)
            widthConstraint.isActive = true
            
            rightHeaderStack.addArrangedSubview(label)
        }
        for stat in layout.statColumns {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = stat
            label.textAlignment = .center
            label.font = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
            label.textColor = AppColors.pencil
            label.backgroundColor = AppColors.header
            label.isAccessibilityElement = false
            label.layer.borderWidth = 0.5
            label.layer.borderColor = AppColors.grid.cgColor
            
            let widthConstraint = label.widthAnchor.constraint(equalToConstant: statWidth)
            widthConstraint.priority = .init(999)
            widthConstraint.isActive = true
            
            rightHeaderStack.addArrangedSubview(label)
        }
    }

    private func performWithoutAnimations(_ updates: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        UIView.performWithoutAnimation {
            updates()
            self.view.layoutIfNeeded()
        }
        CATransaction.commit()
    }

    private func updateUI(with snapshot: LiveGameSnapshot, wasLive: Bool) {
        let linescore = snapshot.linescore
        let gameData = snapshot.gameData
        let game = currentGames.first(where: { $0.gamePk == gamePk })
        let awayName = game?.teams.away.team.name ?? "Away"
        let homeName = game?.teams.home.team.name ?? "Home"

        updateTeamSegmentedControlTitles()

        let hasCurrentAtBat = snapshot.phase == .activeAtBat
        let livePitches = snapshot.currentAtBat?.pitches

        let isFinal = snapshot.phase == .final
        gameHeaderView.configure(with: linescore, awayNameOverride: awayName, homeNameOverride: homeName, isFinal: isFinal)
        currentStateView.configure(with: linescore, pitches: livePitches, gameData: gameData, hasActiveAtBat: hasCurrentAtBat)
        timelineView.configureLiveState(linescore: linescore, pitches: livePitches, gameData: gameData, hasActiveAtBat: hasCurrentAtBat)
        updateGameInfo()
        updateTimelineFooter()
        updatePlaceholderVisibility()
        
        // In timeline mode, use embedded live panel instead of bottom panel
        let showBottomPanel = isGameLive && !isTimelineMode
        let showEmbeddedLive = isGameLive && isTimelineMode
        
        // Always ensure scroll view bottom matches live panel state
        let needsUpdate = currentStateView.isHidden == showBottomPanel
        let applyLayout = {
            self.currentStateView.isHidden = !showBottomPanel
            
            self.scrollBottomConstraint?.isActive = false
            self.scrollBottomConstraint = self.mainScrollView.bottomAnchor.constraint(
                equalTo: showBottomPanel ? self.currentStateView.topAnchor : self.view.bottomAnchor
            )
            self.scrollBottomConstraint?.isActive = true
            
            // Timeline always goes to bottom of view (embedded panel is inside it)
            self.timelineBottomConstraint?.isActive = false
            self.timelineBottomConstraint = self.timelineView.bottomAnchor.constraint(
                equalTo: self.view.bottomAnchor
            )
            self.timelineBottomConstraint?.isActive = true
            
            self.view.layoutIfNeeded()
        }
        
        if needsUpdate {
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .beginFromCurrentState) {
                applyLayout()
            }
        } else {
            applyLayout()
        }
        
        // Update timeline's embedded live panel
        timelineView.setLiveState(visible: showEmbeddedLive)
        
        scorecardView.setIsLive(hasCurrentAtBat)
        
        // Auto-sync on first live detection
        if !wasLive && isGameLive && hasCurrentAtBat {
            syncWithActiveAtBat()
        }
    }

    private func updateScorecard(with scorecard: ScorecardData) {
        let previousScorecard = self.currentScorecard
        let isFirstLoad = previousScorecard == nil
        let previousIsTop = previousScorecard?.isTopInning ?? true
        let wasViewingBattingTeam = !isFirstLoad && teamSegmentedControl.selectedSegmentIndex == (previousIsTop ? 0 : 1)
        self.currentScorecard = scorecard
        
        updateTeamSegmentedControlTitles()
        
        let isTop = scorecard.isTopInning ?? true

        // For live games, default to the team at bat and follow half-inning changes.
        // For non-live games, leave the picker on away (index 0) — no auto-switching.
        if isGameLive {
            if isFirstLoad {
                setDisplayedTeam(toBattingTeamForTopInning: isTop)
            } else if previousScorecard?.isTopInning != scorecard.isTopInning && wasViewingBattingTeam {
                setDisplayedTeam(toBattingTeamForTopInning: isTop)
            }
        }

        performWithoutAnimations {
            self.scorecardView.configure(with: scorecard)
            self.timelineView.configure(with: scorecard.timeline, teams: scorecard.teams)
            self.updateStickyHeaders()
            self.updatePitcherList()
            self.updateUmpireList()
            self.updateGameInfo()
            self.updateTimelineFooter()
            self.updatePlaceholderVisibility()
            self.segmentedOverlay.layoutIfNeeded()
        }
        
        let inning = scorecard.currentInning ?? 1
        let currentIsTop = scorecard.isTopInning ?? true
        let batterId = scorecard.currentBatterId ?? 0
        let newKey = "\(inning)-\(currentIsTop)-\(batterId)"
        
        if isFirstLoad {
            if isGameLive {
                syncWithActiveAtBat()
            }
        } else if isGameLive && newKey != lastActiveAtBatKey && batterId != 0 {
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
            teamSegmentedSafeTopConstraint?.isActive = false
            teamSegmentedAdvisoryTopConstraint?.isActive = true
        } else {
            advisoryBanner.isHidden = true
            teamSegmentedAdvisoryTopConstraint?.isActive = false
            teamSegmentedSafeTopConstraint?.isActive = true
        }
    }

    private func updateTeamSegmentedControlTitles() {
        guard let scorecard = currentScorecard else { return }
        
        let awayName = scorecard.teams.away.name ?? "Away"
        let homeName = scorecard.teams.home.name ?? "Home"
        
        let isTop = scorecard.isTopInning ?? true
        
        // Only show prominent at-bat indicator dot if the game is live
        let showAwayDot = isGameLive && isTop
        let showHomeDot = isGameLive && !isTop
        
        let awayTitle = showAwayDot ? "● \(awayName)" : awayName
        let homeTitle = showHomeDot ? "● \(homeName)" : homeName

        performWithoutAnimations {
            self.teamSegmentedControl.setTitle(awayTitle, forSegmentAt: 0)
            self.teamSegmentedControl.setTitle(homeTitle, forSegmentAt: 1)
            self.segmentedOverlay.setNeedsLayout()
            self.segmentedOverlay.layoutIfNeeded()
        }
        teamSegmentedControl.accessibilityValue = teamSegmentedControl.selectedSegmentIndex == 0 ? awayName : homeName
    }
    
    @objc private func closeAdvisory() {
        if let current = advisoryLabel.text {
            dismissedAdvisories.insert(current)
        }
        
        UIView.animate(withDuration: 0.3) {
            self.advisoryBanner.isHidden = true
            self.teamSegmentedAdvisoryTopConstraint?.isActive = false
            self.teamSegmentedSafeTopConstraint?.isActive = true
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
        guard isGameLive else { return }
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
            performWithoutAnimations {
                self.placeholderLabel.isHidden = !show
                self.scorecardView.isHidden = show
                self.stickyHeaderContainer.isHidden = show
                self.pitcherContainer.isHidden = show
                self.infoColumnsStack.isHidden = show
            }
        }
        
        if show {
            placeholderLabel.text = "LINEUP NOT YET AVAILABLE"
        }
    }

    private func showLiveAtBatDetail() {
        guard let liveEvent = currentSnapshot?.currentAtBat else { return }
        if liveDetailVC != nil { return }
        let batterName = liveEvent.batterName
        let pitcherName = liveEvent.pitcherName
        
        let vc = AtBatDetailViewController(
            event: liveEvent,
            batterName: batterName,
            pitcherName: pitcherName,
            accentColor: teamAccentColor(isTopInning: liveEvent.isTop)
        )
        configureAtBatDetailCallbacks(vc, event: liveEvent, batterName: batterName, pitcherName: pitcherName)
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        self.liveDetailVC = vc
        present(vc, animated: true)
    }

    private func updateLiveDetailSheet(with liveEvent: AtBatEvent) {
        guard let liveVC = liveDetailVC else { return }
        liveVC.update(
            event: liveEvent,
            batterName: liveEvent.batterName,
            pitcherName: liveEvent.pitcherName,
            accentColor: teamAccentColor(isTopInning: liveEvent.isTop)
        )
        configureAtBatDetailCallbacks(
            liveVC,
            event: liveEvent,
            batterName: liveEvent.batterName,
            pitcherName: liveEvent.pitcherName
        )
    }

    private func updateUmpireList() {
        guard let scorecard = currentScorecard else { return }
        let umpires = scorecard.umpires
        if umpires == currentUmpires { return }
        self.currentUmpires = umpires

        umpireLabel.attributedText = GameFooterContent.makeUmpireText(umpires)
    }

    private func updatePitcherList() {
        guard let scorecard = currentScorecard else { return }
        let isHome = teamSegmentedControl.selectedSegmentIndex == 1
        let pitchers = isHome ? scorecard.pitchers.home : scorecard.pitchers.away
        
        if pitchers == currentPitchers { return }
        self.currentPitchers = pitchers
        
        pitcherContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let pitcherSection = GameFooterContent.makePitcherSection(
            groups: [FooterPitcherGroup(title: "PITCHERS", pitchers: pitchers)],
            target: self,
            action: #selector(handlePitcherNameTap(_:))
        ) {
            pitcherContainer.addArrangedSubview(pitcherSection)
        }
    }

    private var currentWeather: Weather?
    
    private func updateGameInfo() {
        guard let scorecard = currentScorecard else { return }
        
        let weather = currentLinescore?.weather ?? currentGameData?.weather
        if scorecard.gameInfo == currentGameInfo && weather == currentWeather { return }
        self.currentGameInfo = scorecard.gameInfo
        self.currentWeather = weather
        
        gameInfoLabel.attributedText = GameFooterContent.makeGameInfoText(
            gameInfoItems: scorecard.gameInfo,
            weather: weather
        )
    }

    private func updateTimelineFooter() {
        guard let scorecard = currentScorecard else { return }
        timelineView.configureFooter(
            pitchers: scorecard.pitchers,
            umpires: scorecard.umpires,
            gameInfo: scorecard.gameInfo,
            weather: currentLinescore?.weather ?? currentGameData?.weather,
            teams: scorecard.teams
        )
    }

    // MARK: - TimelineViewDelegate
    func didSelectTimelineAtBat(_ event: AtBatEvent) {
        let vc = AtBatDetailViewController(
            event: event,
            batterName: event.batterName,
            pitcherName: event.pitcherName,
            accentColor: teamAccentColor(isTopInning: event.isTop)
        )
        configureAtBatDetailCallbacks(vc, event: event, batterName: event.batterName, pitcherName: event.pitcherName)
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }
    
    func didTapTimelineLiveAtBat() {
        showLiveAtBatDetail()
    }
    
    func didLongPressTimelineLiveAtBat() {
        syncWithActiveAtBat()
    }

    func didSelectTimelinePitcher(_ pitcher: ScorecardPitcher) {
        presentPitcherDetail(for: pitcher)
    }

    // MARK: - ScorecardViewDelegate
    func didSelectAtBat(_ event: AtBatEvent, batter: ScorecardBatter, pitcherName: String) {
        let vc = AtBatDetailViewController(
            event: event,
            batterName: batter.fullName,
            pitcherName: event.pitcherName,
            accentColor: teamAccentColor(isTopInning: event.isTop)
        )
        configureAtBatDetailCallbacks(vc, event: event, batterName: batter.fullName, pitcherName: event.pitcherName)
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }

    func didSelectPlayer(_ batter: ScorecardBatter) {
        presentBatterDetail(for: batter)
    }

    func didSelectActiveAtBat() {
        showLiveAtBatDetail()
    }

    private func syncWithActiveAtBat() {
        guard isGameLive, let scorecard = currentScorecard else { return }
        
        // Swap to the team at bat
        let isTop = scorecard.isTopInning ?? true
        let targetIndex = isTop ? 0 : 1
        if teamSegmentedControl.selectedSegmentIndex != targetIndex {
            setDisplayedTeam(toBattingTeamForTopInning: isTop)
            self.updatePitcherList()
            self.updatePlaceholderVisibility()
        }
        
        self.scrollToActiveCell(scorecard: scorecard)
    }

    private func setDisplayedTeam(toBattingTeamForTopInning isTop: Bool) {
        teamSegmentedControl.selectedSegmentIndex = isTop ? 0 : 1
        segmentedOverlay.setNeedsLayout()
        scorecardView.setTeam(isHome: !isTop)
    }

    private func scrollToActiveCell(scorecard: ScorecardData) {
        guard isGameLive,
              let inningNum = scorecard.currentInning,
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
            let cellWidth: CGFloat = 56
            let rowHeight: CGFloat = 64
            
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

    private func configureAtBatDetailCallbacks(_ vc: AtBatDetailViewController, event: AtBatEvent, batterName: String, pitcherName: String) {
        vc.onBatterTap = { [weak self, weak vc] in
            guard let self, let vc else { return }
            let batter = self.scorecardBatter(for: event.batterId, fallbackName: batterName)
            let detailVC = PlayerDetailViewController(batter: batter, gameStats: self.calculatePlayerStats(for: batter))
            self.configurePlayerDetailSheet(detailVC)
            vc.present(detailVC, animated: true)
        }
        vc.onPitcherTap = { [weak self, weak vc] in
            guard let self, let vc else { return }
            let pitcher = self.scorecardPitcher(for: event.pitcherId, fallbackName: pitcherName)
            let detailVC = PlayerDetailViewController(pitcher: pitcher)
            self.configurePlayerDetailSheet(detailVC)
            vc.present(detailVC, animated: true)
        }
    }

    private func presentBatterDetail(for batter: ScorecardBatter) {
        let vc = PlayerDetailViewController(batter: batter, gameStats: calculatePlayerStats(for: batter))
        presentPlayerDetailSheet(vc)
    }

    private func presentPitcherDetail(for pitcher: ScorecardPitcher) {
        let vc = PlayerDetailViewController(pitcher: pitcher)
        presentPlayerDetailSheet(vc)
    }

    private func presentPlayerDetailSheet(_ vc: UIViewController) {
        configurePlayerDetailSheet(vc)
        present(vc, animated: true)
    }

    private func configurePlayerDetailSheet(_ vc: UIViewController) {
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
    }

    private func scorecardBatter(for id: Int, fallbackName: String) -> ScorecardBatter {
        if let scorecard = currentScorecard {
            if let batter = (scorecard.lineups.home + scorecard.lineups.away).first(where: { $0.id == id }) {
                return batter
            }
        }
        let parts = fallbackName.split(separator: " ")
        let abbreviation = parts.last.map(String.init) ?? fallbackName
        return ScorecardBatter(
            id: id,
            fullName: fallbackName,
            abbreviation: abbreviation,
            position: "",
            jerseyNumber: nil,
            inningEntered: nil,
            inningExited: nil
        )
    }

    private func scorecardPitcher(for id: Int, fallbackName: String) -> ScorecardPitcher {
        if let scorecard = currentScorecard {
            if let pitcher = (scorecard.pitchers.home + scorecard.pitchers.away).first(where: { $0.id == id }) {
                return pitcher
            }
        }
        return ScorecardPitcher(id: id, fullName: fallbackName, stats: "", ip: "0.0", h: 0, r: 0, er: 0, bb: 0, k: 0)
    }

    private func teamAccentColor(isTopInning: Bool) -> UIColor? {
        guard let scorecard = currentScorecard else { return nil }
        return scorecard.teamAccentColor(isTopInning: isTopInning)
    }

    @objc private func handlePitcherNameTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        guard let pitcher = currentPitchers.first(where: { $0.id == view.tag }) else { return }
        presentPitcherDetail(for: pitcher)
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
