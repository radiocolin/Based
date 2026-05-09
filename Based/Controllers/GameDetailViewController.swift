import UIKit
import TipKit

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
        label.font = AppFont.ibmPlexCondensed(18, textStyle: .headline)
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
        label.font = UIFont(name: AppFont.permanentMarker, size: 20) ?? .systemFont(ofSize: 20, weight: .bold)
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
    
    private let viewModel: GameDetailViewModel
    private lazy var exportCoordinator = ScorecardExportCoordinator(viewController: self)

    private weak var liveDetailVC: AtBatDetailViewController?
    private var teamSegmentedSafeTopConstraint: NSLayoutConstraint?
    private var teamSegmentedAdvisoryTopConstraint: NSLayoutConstraint?
    private var scrollBottomConstraint: NSLayoutConstraint?
    private var timelineBottomConstraint: NSLayoutConstraint?
    private var dismissedAdvisories: Set<String> = []
    private var segmentJustChanged = false

    // Tips
    private let tapAtBatTip = TapAtBatTip()
    private let teamScheduleTip = TeamScheduleTip()
    private let shareScorecardTip = ShareScorecardTip()
    private var tipTask: Task<Void, Never>?

    private var stickyNameWidthConstraint: NSLayoutConstraint?

    // Constants
    private let inningWidth: CGFloat = 56
    private let statWidth: CGFloat = 38
    private let headerHeight: CGFloat = 32
    private let visibleSegmentedTopInset: CGFloat = 8
    private let hiddenSegmentedTopInset: CGFloat = -48

    init(gamePk: Int, games: [ScheduleGame]) {
        self.viewModel = GameDetailViewModel(gamePk: gamePk, games: games)
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
            if let scorecard = self.viewModel.currentScorecard {
                self.scorecardView.configure(with: scorecard)
            }
        }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: GameDetailViewController, _) in
            self.setupNavigationBar()
            self.updateStickyHeaders()
            self.timelineView.reloadInputViews()
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
        
        // Apply saved view mode without animation
        if viewModel.isTimelineMode {
            updateUIForMode()
            teamSegmentedControl.isHidden = true
            segmentedOverlay.isHidden = true
            stickyHeaderContainer.isHidden = true
            mainScrollView.isHidden = true
            timelineView.isHidden = false
        }
        
        setupViewModelCallbacks()
        viewModel.startPolling()

        Task { await TapAtBatTip.gameViewed.donate() }
    }
    
    private func setupViewModelCallbacks() {
        viewModel.onSnapshotUpdate = { [weak self] snapshot, wasLive in
            self?.updateUI(with: snapshot, wasLive: wasLive)
        }
        viewModel.onScorecardUpdate = { [weak self] scorecard in
            self?.updateScorecard(with: scorecard)
        }
        viewModel.onStatusUpdate = { status in
            // Option to show status in UI
        }
    }

    @objc private func tintDidChange() {
        setupNavigationBar()
        updateStickyHeaders()
        segmentedOverlay.setNeedsLayout()
        updateTeamSegmentedControlTitles()
        if let scorecard = viewModel.currentScorecard {
            scorecardView.configure(with: scorecard)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            viewModel.stopPolling()
            if viewModel.isGameLive {
                ReviewPromptService.shared.requestReviewIfAppropriate(in: view.window?.windowScene)
            }
            tipTask?.cancel()
            tipTask = nil
        }
    }


    
    private func setupNavigationBar() {
        navigationItem.hidesBackButton = true
        let prevTitle = navigationController?.viewControllers.dropLast().last?.title
        navigationItem.leftBarButtonItem = BarAppearanceSupport.makePencilBackButton(
            title: prevTitle ?? "Back", traitCollection: traitCollection, target: self, action: #selector(backTapped)
        )

        let titleFont = BarAppearanceSupport.titleFont(for: traitCollection)
        let buttonFont = BarAppearanceSupport.buttonFont(for: traitCollection)
        let pencilColor = AppColors.pencil
        
        let iconSize = BarAppearanceSupport.iconSize(for: traitCollection, base: 32, maximum: 32)
        let shareImg = UIImage.pencilStyledIcon(named: "square.and.arrow.up", color: pencilColor, size: iconSize, offset: CGPoint(x: -0.5, y: 0), scaleMultiplier: 0.9)
        let shareMenu = UIMenu(title: "", children: [
            UIAction(title: "Share Image", image: UIImage(systemName: "photo")) { [weak self] _ in
                self?.shareImage()
            },
            UIAction(title: "Save PDF", image: UIImage(systemName: "doc.richtext")) { [weak self] _ in
                self?.sharePDF()
            },
            UIAction(title: "Customize…", image: UIImage(systemName: "slider.horizontal.3")) { [weak self] _ in
                self?.showExportCustomizer()
            }
        ])
        let shareItem = UIBarButtonItem(image: shareImg, menu: shareMenu)
        shareItem.accessibilityLabel = "Share scorecard"
        
        let timelineSymbol = viewModel.isTimelineMode ? "square.grid.3x2" : "calendar.day.timeline.left"
        let timelineImg = UIImage.pencilStyledIcon(named: timelineSymbol, color: pencilColor, size: iconSize, offset: CGPoint(x: 1.5, y: 1.0))
        let timelineItem = UIBarButtonItem(image: timelineImg, style: .plain, target: self, action: #selector(toggleTimelineMode))
        timelineItem.accessibilityLabel = viewModel.isTimelineMode ? "Show scorecard" : "Show timeline"
        
        navigationItem.rightBarButtonItems = [shareItem, timelineItem]
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.paper
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.font: titleFont, .foregroundColor: pencilColor]
        appearance.largeTitleTextAttributes = [.font: titleFont, .foregroundColor: pencilColor]
        configurePlainBarButtonAppearance(appearance.buttonAppearance, font: buttonFont, color: pencilColor)
        configurePlainBarButtonAppearance(appearance.backButtonAppearance, font: buttonFont, color: pencilColor)
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = pencilColor
        navigationController?.navigationBar.setNeedsLayout()
        navigationController?.navigationBar.layoutIfNeeded()
    }
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func toggleTimelineMode() {
        viewModel.isTimelineMode.toggle()
        
        self.setupNavigationBar()

        if viewModel.isTimelineMode {
            timelineView.isHidden = false
            timelineView.alpha = 0
        } else {
            teamSegmentedControl.isHidden = false
            segmentedOverlay.isHidden = false
            stickyHeaderContainer.isHidden = false
            mainScrollView.isHidden = false
        }

        // Swap live panel placement
        if viewModel.isGameLive {
            if viewModel.isTimelineMode {
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
            if self.viewModel.isTimelineMode {
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
        teamSegmentedControl.alpha = viewModel.isTimelineMode ? 0 : 1
        segmentedOverlay.alpha = viewModel.isTimelineMode ? 0 : 1
        stickyHeaderContainer.alpha = viewModel.isTimelineMode ? 0 : 1
        mainScrollView.alpha = viewModel.isTimelineMode ? 0 : 1
        timelineView.alpha = viewModel.isTimelineMode ? 1 : 0
        
        // Adjust constraints to move headers
        let inset = viewModel.isTimelineMode ? hiddenSegmentedTopInset : visibleSegmentedTopInset
        teamSegmentedSafeTopConstraint?.constant = inset
        teamSegmentedAdvisoryTopConstraint?.constant = inset
    }

    private func shareImage() {
        shareScorecardTip.invalidate(reason: .actionPerformed)
        guard let scorecard = viewModel.currentScorecard else { return }

        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        view.isUserInteractionEnabled = false

        Task {
            let generator = ScorecardImageGenerator()
            let image = await generator.generate(scorecard: scorecard, linescore: self.viewModel.currentLinescore)

            await MainActor.run {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                self.view.isUserInteractionEnabled = true

                let awayName = scorecard.teams.away.name ?? "Away"
                let homeName = scorecard.teams.home.name ?? "Home"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(awayName) vs \(homeName) Scorecard.png")
                try? image.pngData()?.write(to: tempURL)

                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.barButtonItem = self.navigationItem.rightBarButtonItem
                }
                self.present(activityVC, animated: true)
            }
        }
    }

    private func sharePDF() {
        shareScorecardTip.invalidate(reason: .actionPerformed)
        guard let scorecard = viewModel.currentScorecard else { return }

        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        view.isUserInteractionEnabled = false

        Task {
            let generator = ScorecardImageGenerator()
            let pdfData = await generator.generatePDF(scorecard: scorecard, linescore: self.viewModel.currentLinescore)

            await MainActor.run {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                self.view.isUserInteractionEnabled = true

                let awayName = scorecard.teams.away.name ?? "Away"
                let homeName = scorecard.teams.home.name ?? "Home"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(awayName) vs \(homeName) Scorecard.pdf")
                try? pdfData.write(to: tempURL)

                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.barButtonItem = self.navigationItem.rightBarButtonItem
                }
                self.present(activityVC, animated: true)
            }
        }
    }

    private func showExportCustomizer() {
        shareScorecardTip.invalidate(reason: .actionPerformed)
        guard let scorecard = viewModel.currentScorecard else { return }
        let exportVC = ScorecardExportViewController(scorecard: scorecard, linescore: viewModel.currentLinescore)
        let nav = UINavigationController(rootViewController: exportVC)
        present(nav, animated: true)
    }

    private func configurePlainBarButtonAppearance(_ appearance: UIBarButtonItemAppearance, font: UIFont, color: UIColor) {
        BarAppearanceSupport.applyPlainBarButtonAppearance(appearance, font: font, color: color)
    }
    
    // MARK: - Tips

    private func observeTips() {
        guard tipTask == nil else { return }
        tipTask = Task { @MainActor in
            await showTipOnce(tapAtBatTip) { [weak self] in
                guard let self else { return nil }
                return self.scorecardView.rightCollectionView?.cellForItem(at: IndexPath(item: 0, section: 0))
                    ?? self.scorecardView
            }
            await showTipOnce(teamScheduleTip) { [weak self] in
                self?.gameHeaderView.homeNameLabel
            }
            await showTipOnce(shareScorecardTip) { [weak self] in
                self?.navigationItem.rightBarButtonItems?.first
            }
        }
    }

    private func showTipOnce(_ tip: any Tip, sourceItem: @escaping () -> (any UIPopoverPresentationControllerSourceItem)?) async {
        var presented = false
        for await shouldDisplay in tip.shouldDisplayUpdates {
            if shouldDisplay && !presented {
                while presentedViewController != nil {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                if Task.isCancelled { return }
                guard let source = sourceItem() else { return }
                let popover = TipUIPopoverViewController(tip, sourceItem: source)
                present(popover, animated: true)
                presented = true
            } else if !shouldDisplay {
                if presented, presentedViewController is TipUIPopoverViewController {
                    dismiss(animated: true)
                }
                if presented { break }
                if case .invalidated = tip.status { break }
            }
        }
    }

    // MARK: - GameUpdateDelegate

    func didUpdateSnapshot(_ snapshot: LiveGameSnapshot) {
        // Redundant with ViewModel callbacks, but keeping for protocol conformance if needed
        // or we can remove GameUpdateDelegate from VC
    }
    
    func didUpdateGameStatus(_ status: String) {
        // Redundant with ViewModel callbacks
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.paper

        setupAdvisoryBanner()

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

        setupStickyHeader()
        setupMainContent()
        setupCallbacks()
        setupSegmentedControlAppearance()

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

        teamSegmentedSafeTopConstraint = teamSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: viewModel.isTimelineMode ? hiddenSegmentedTopInset : visibleSegmentedTopInset)
        teamSegmentedAdvisoryTopConstraint = teamSegmentedControl.topAnchor.constraint(equalTo: advisoryBanner.bottomAnchor, constant: viewModel.isTimelineMode ? hiddenSegmentedTopInset : visibleSegmentedTopInset)

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
                c.priority = .init(999)
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

    private func setupAdvisoryBanner() {
        advisoryBanner.backgroundColor = AppColors.advisoryBackground
        advisoryBanner.layer.cornerRadius = 8
        advisoryBanner.layer.borderWidth = 1.0
        advisoryBanner.layer.borderColor = UIColor.red.withAlphaComponent(0.3).cgColor
        advisoryBanner.isHidden = true
        advisoryBanner.translatesAutoresizingMaskIntoConstraints = false

        advisoryLabel.font = UIFont(name: AppFont.patrickHand, size: 14)
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
    }

    private func setupStickyHeader() {
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
    }

    private func setupMainContent() {
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

        let footerSpacer = UIView()
        footerSpacer.translatesAutoresizingMaskIntoConstraints = false
        footerSpacer.heightAnchor.constraint(equalToConstant: 12).isActive = true

        [scorecardView, pitcherContainer, footerSpacer, infoColumnsStack, placeholderLabel].forEach {
            mainStackView.addArrangedSubview($0)
        }

        let placeholderHeight = placeholderLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        placeholderHeight.priority = .init(999)
        placeholderHeight.isActive = true

        scorecardView.setHeadersVisible(false)
    }

    private func setupCallbacks() {
        scorecardView.delegate = self

        gameHeaderView.onTeamTapped = { [weak self] teamId, teamName in
            self?.teamScheduleTip.invalidate(reason: .actionPerformed)
            ShareScorecardTip.teamScheduleSeen = true
            self?.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Game", style: .plain, target: nil, action: nil)
            let scheduleVC = TeamScheduleViewController(teamId: teamId, teamName: teamName)
            self?.navigationController?.pushViewController(scheduleVC, animated: true)
        }

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
    }

    private func setupSegmentedControlAppearance() {
        let font = UIFont(name: AppFont.patrickHand, size: 18) ?? .systemFont(ofSize: 18)

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
            label.font = AppFont.ibmPlexCondensed(16, textStyle: .caption1)
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
            label.font = AppFont.ibmPlexCondensed(16, textStyle: .caption1)
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
        let game = viewModel.currentGames.first(where: { $0.gamePk == viewModel.gamePk })
        let awayName = game?.teams.away.team.name ?? "Away"
        let homeName = game?.teams.home.team.name ?? "Home"

        updateTeamSegmentedControlTitles()

        let hasCurrentAtBat = snapshot.phase == .activeAtBat
        let livePitches = snapshot.currentAtBat?.pitches

        let isFinal = snapshot.phase == .final
        let awayId = game?.teams.away.team.id
        let homeId = game?.teams.home.team.id
        gameHeaderView.configure(with: linescore, awayNameOverride: awayName, homeNameOverride: homeName, awayId: awayId, homeId: homeId, isFinal: isFinal)
        currentStateView.configure(with: linescore, pitches: livePitches, gameData: gameData, hasActiveAtBat: hasCurrentAtBat)
        timelineView.configureLiveState(linescore: linescore, pitches: livePitches, gameData: gameData, hasActiveAtBat: hasCurrentAtBat)
        updateGameInfo()
        updateTimelineFooter()
        updatePlaceholderVisibility()
        
        // In timeline mode, use embedded live panel instead of bottom panel
        let showBottomPanel = viewModel.isGameLive && !viewModel.isTimelineMode
        let showEmbeddedLive = viewModel.isGameLive && viewModel.isTimelineMode
        
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
        if !wasLive && viewModel.isGameLive && hasCurrentAtBat {
            syncWithActiveAtBat()
        }

        if wasLive && isFinal {
            ReviewPromptService.shared.requestReviewIfAppropriate(in: view.window?.windowScene)
        }
    }

    private func updateScorecard(with scorecard: ScorecardData) {
        let previousScorecard = viewModel.currentScorecard
        let isFirstLoad = previousScorecard == nil
        let previousIsTop = previousScorecard?.isTopInning ?? true
        let wasViewingBattingTeam = !isFirstLoad && teamSegmentedControl.selectedSegmentIndex == (previousIsTop ? 0 : 1)
        
        updateTeamSegmentedControlTitles()
        
        let isTop = scorecard.isTopInning ?? true

        // For live games, default to the team at bat and follow half-inning changes.
        // For non-live games, leave the picker on away (index 0) — no auto-switching.
        if viewModel.isGameLive {
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
            if viewModel.isGameLive {
                syncWithActiveAtBat()
            }
        } else if viewModel.isGameLive && newKey != viewModel.lastActiveAtBatKey && batterId != 0 {
            // Auto-scroll only if viewing the team at bat
            let viewingBattingTeam = (currentIsTop && teamSegmentedControl.selectedSegmentIndex == 0) ||
                                     (!currentIsTop && teamSegmentedControl.selectedSegmentIndex == 1)
            if viewingBattingTeam {
                scrollToActiveCell(scorecard: scorecard)
            }
        }
        
        viewModel.lastActiveAtBatKey = newKey
        
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

        observeTips()
    }

    private func updateTeamSegmentedControlTitles() {
        guard let scorecard = viewModel.currentScorecard else { return }
        
        let awayName = scorecard.teams.away.name ?? "Away"
        let homeName = scorecard.teams.home.name ?? "Home"
        
        let isTop = scorecard.isTopInning ?? true
        
        // Only show prominent at-bat indicator dot if the game is live
        let showAwayDot = viewModel.isGameLive && isTop
        let showHomeDot = viewModel.isGameLive && !isTop
        
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
        guard viewModel.isGameLive else { return }
        if segmentJustChanged {
            segmentJustChanged = false
            return
        }
        // Tapped the already-selected segment — jump to active at-bat
        syncWithActiveAtBat()
    }

    private func updatePlaceholderVisibility() {
        guard let scorecard = viewModel.currentScorecard else { 
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
        guard let liveEvent = viewModel.currentSnapshot?.currentAtBat else { return }
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
            previousPitcherName: previousPitcherName(for: liveEvent),
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
        guard let scorecard = viewModel.currentScorecard else { return }
        let umpires = scorecard.umpires
        if umpires == viewModel.currentUmpires { return }
        // Note: umpires update is handled in updateScorecard calling this

        umpireLabel.attributedText = GameFooterContent.makeUmpireText(umpires)
        umpireLabel.accessibilityLabel = GameFooterContent.makeUmpireAccessibilityLabel(umpires)
    }

    private func updatePitcherList() {
        guard let scorecard = viewModel.currentScorecard else { return }
        let isHome = teamSegmentedControl.selectedSegmentIndex == 1
        let pitchers = isHome ? scorecard.pitchers.home : scorecard.pitchers.away
        
        if pitchers == viewModel.currentPitchers { return }
        // Note: pitchers update is handled in updateScorecard calling this
        
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
        guard let scorecard = viewModel.currentScorecard else { return }
        
        let weather = viewModel.currentLinescore?.weather ?? viewModel.currentGameData?.weather
        if scorecard.gameInfo == viewModel.currentGameInfo && weather == currentWeather { return }
        // Note: gameInfo update is handled in updateScorecard calling this
        self.currentWeather = weather
        
        gameInfoLabel.attributedText = GameFooterContent.makeGameInfoText(
            gameInfoItems: scorecard.gameInfo,
            weather: weather
        )
    }

    private func updateTimelineFooter() {
        guard let scorecard = viewModel.currentScorecard else { return }
        timelineView.configureFooter(
            pitchers: scorecard.pitchers,
            umpires: scorecard.umpires,
            gameInfo: scorecard.gameInfo,
            weather: viewModel.currentLinescore?.weather ?? viewModel.currentGameData?.weather,
            teams: scorecard.teams
        )
    }

    private func previousPitcherName(for event: AtBatEvent) -> String? {
        if let previousPitcherName = event.previousPitcherName {
            return previousPitcherName
        }

        guard let scorecard = viewModel.currentScorecard else { return nil }
        let eventsInInning = scorecard.events(inningNum: event.inning, isHomeBatting: !event.isTop)
        
        if let index = eventsInInning.firstIndex(of: event) {
            guard index > 0,
                  eventsInInning[index].pitcherId != eventsInInning[index - 1].pitcherId else {
                return nil
            }
            return eventsInInning[index - 1].pitcherName
        }
        
        return nil
    }

    // MARK: - TimelineViewDelegate
    func didSelectTimelineAtBat(_ event: AtBatEvent) {
        let vc = AtBatDetailViewController(
            event: event,
            batterName: event.batterName,
            pitcherName: event.pitcherName,
            previousPitcherName: previousPitcherName(for: event),
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
        tapAtBatTip.invalidate(reason: .actionPerformed)
        TeamScheduleTip.tapAtBatSeen = true
        let vc = AtBatDetailViewController(
            event: event,
            batterName: batter.fullName,
            pitcherName: event.pitcherName,
            previousPitcherName: previousPitcherName(for: event),
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
        guard viewModel.isGameLive, let scorecard = viewModel.currentScorecard else { return }
        
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
        guard viewModel.isGameLive,
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
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
    }

    private func scorecardBatter(for id: Int, fallbackName: String) -> ScorecardBatter {
        if let scorecard = viewModel.currentScorecard {
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
        if let scorecard = viewModel.currentScorecard {
            if let pitcher = (scorecard.pitchers.home + scorecard.pitchers.away).first(where: { $0.id == id }) {
                return pitcher
            }
        }
        return ScorecardPitcher(id: id, fullName: fallbackName, stats: "", ip: "0.0", h: 0, r: 0, er: 0, bb: 0, k: 0)
    }

    private func teamAccentColor(isTopInning: Bool) -> UIColor? {
        guard let scorecard = viewModel.currentScorecard else { return nil }
        return scorecard.teamAccentColor(isTopInning: isTopInning)
    }

    @objc private func handlePitcherNameTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        guard let pitcher = viewModel.currentPitchers.first(where: { $0.id == view.tag }) else { return }
        presentPitcherDetail(for: pitcher)
    }

    private func calculatePlayerStats(for batter: ScorecardBatter) -> PlayerGameStats {
        guard let scorecard = viewModel.currentScorecard else { return PlayerGameStats(atBats: 0, hits: 0, runs: 0, rbi: 0, walks: 0, strikeouts: 0) }
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
