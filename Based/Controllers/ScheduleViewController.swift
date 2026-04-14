import UIKit

class ScheduleViewController: UIViewController {
    
    // UI Components
    private let dateHeaderView = UIView()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let dateLabel = UILabel()
    private var dateHeaderHeightConstraint: NSLayoutConstraint?
    
    private var collectionView: UICollectionView!
    private var currentGames: [ScheduleGame] = []
    private var currentDate: Date = Date()
    private var hasAttemptedAutoEntry = false
    private var backgroundTime: Date?
    
    // Date Picker Pop-up Overlay
    private let datePickerOverlay = UIView()
    private let datePickerContainer = UIView()
    private let datePicker = UIDatePicker()
    private let datePickerDoneButton = UIButton(type: .system)
    
    private let noGamesLabel: UILabel = {
        let label = UILabel()
        label.text = "No games scheduled"
        label.font = UIFont(name: "PatrickHand-Regular", size: 20) ?? .systemFont(ofSize: 20)
        label.textColor = AppColors.pencil.withAlphaComponent(0.5)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    // Loading & error state
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let errorContainer: UIView = {
        let view = UIView()
        view.accessibilityElements = [] // children set after subviews added
        return view
    }()
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.text = "Couldn't load schedule"
        label.font = UIFont(name: "PatrickHand-Regular", size: 20) ?? .systemFont(ofSize: 20)
        label.textColor = AppColors.pencil.withAlphaComponent(0.5)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    private let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Tap to retry", for: .normal)
        button.titleLabel?.font = UIFont(name: "PatrickHand-Regular", size: 18) ?? .systemFont(ofSize: 18)
        button.tintColor = AppColors.pencil
        button.accessibilityLabel = "Retry loading schedule"
        button.accessibilityHint = "Double tap to try loading the schedule again."
        return button
    }()
    private var isLoading = false
    private var loadTask: Task<Void, Never>?

    // Constants
    private var pencilColor: UIColor { AppColors.pencil }
    private let headerFont = "PermanentMarker-Regular"
    private let bodyFont = "PatrickHand-Regular"

    override func loadView() {
        let rootView = ScheduleRootView()
        rootView.onAccessibilityScroll = { [weak self] direction in
            self?.handleAccessibilityScroll(direction) ?? false
        }
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDatePickerOverlay()
        loadSchedule(for: currentDate, triggerAutoEntry: true)
        
        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: ScheduleViewController, _) in
            self.setupNavigationBar()
            self.collectionView.reloadData()
        }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: ScheduleViewController, _) in
            self.applyTypography()
            self.updateCollectionLayout()
            self.setupNavigationBar()
            self.collectionView.reloadData()
        }
    }
    
    @objc private func tintDidChange() {
        setupNavigationBar()
        // Re-resolve dynamic colors on header elements
        let pc = AppColors.pencil
        prevButton.tintColor = pc
        nextButton.tintColor = pc
        dateLabel.textColor = pc
        noGamesLabel.textColor = pc.withAlphaComponent(0.5)
        loadingIndicator.color = pc
        errorLabel.textColor = pc.withAlphaComponent(0.5)
        retryButton.tintColor = pc
        collectionView.reloadData()
    }

    @objc private func appDidBecomeActive() {
        let now = Date()
        let timeInBackground = now.timeIntervalSince(backgroundTime ?? .distantPast)
        
        // Only reset the auto-entry flag and trigger auto-entry if we've been in the background for at least 5 minutes
        let shouldTrigger = timeInBackground > 300
        if shouldTrigger {
            hasAttemptedAutoEntry = false
        }
        
        loadSchedule(for: currentDate, triggerAutoEntry: shouldTrigger)
    }

    @objc private func appDidEnterBackground() {
        backgroundTime = Date()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionLayout()
    }


    
    private func setupUI() {
        view.backgroundColor = AppColors.paper
        
        // Date Header Setup
        dateHeaderView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dateHeaderView)
        
        let arrowSize = CGSize(width: 32, height: 32)
        let prevImg = UIImage.pencilStyledIcon(named: "arrow.left", color: pencilColor, size: arrowSize)
        prevButton.setImage(prevImg, for: .normal)
        prevButton.setTitle(nil, for: .normal)
        prevButton.tintColor = pencilColor
        prevButton.accessibilityLabel = "Previous day"
        prevButton.addTarget(self, action: #selector(prevDate), for: .touchUpInside)
        
        let nextImg = UIImage.pencilStyledIcon(named: "arrow.right", color: pencilColor, size: arrowSize)
        nextButton.setImage(nextImg, for: .normal)
        nextButton.setTitle(nil, for: .normal)
        nextButton.tintColor = pencilColor
        nextButton.accessibilityLabel = "Next day"
        nextButton.accessibilityHint = "Double tap and hold to jump to today."
        nextButton.addTarget(self, action: #selector(nextDate), for: .touchUpInside)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(jumpToToday(_:)))
        nextButton.addGestureRecognizer(longPress)
        
        dateLabel.font = AppFont.permanent(20, textStyle: .title2, compatibleWith: traitCollection)
        dateLabel.textColor = pencilColor
        dateLabel.textAlignment = .center
        dateLabel.isUserInteractionEnabled = true
        dateLabel.accessibilityTraits = [.staticText, .button]
        dateLabel.accessibilityHint = "Double tap to choose a date."
        dateLabel.adjustsFontForContentSizeCategory = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(showDatePicker))
        dateLabel.addGestureRecognizer(tap)
        
        [prevButton, dateLabel, nextButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            dateHeaderView.addSubview($0)
        }
        
        // Collection View Setup
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 32, right: 16)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(GameCardCell.self, forCellWithReuseIdentifier: GameCardCell.reuseIdentifier)
        collectionView.isAccessibilityElement = false
        
        let gameLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleGameLongPress(_:)))
        collectionView.addGestureRecognizer(gameLongPress)
        
        // Pull-to-refresh
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        
        // Loading indicator
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = AppColors.pencil
        loadingIndicator.accessibilityLabel = "Loading schedule"
        
        // Error container (label + retry button stacked vertically)
        errorContainer.isHidden = true
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        
        [errorLabel, retryButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            errorContainer.addSubview($0)
        }
        errorContainer.accessibilityElements = [errorLabel, retryButton]
        
        [collectionView, noGamesLabel, loadingIndicator, errorContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        noGamesLabel.adjustsFontForContentSizeCategory = true
        errorLabel.adjustsFontForContentSizeCategory = true
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true

        NSLayoutConstraint.activate([
            // Date Header
            dateHeaderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            dateHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dateHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            prevButton.leadingAnchor.constraint(equalTo: dateHeaderView.leadingAnchor, constant: 20),
            prevButton.topAnchor.constraint(greaterThanOrEqualTo: dateHeaderView.topAnchor, constant: 8),
            prevButton.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 32),

            nextButton.trailingAnchor.constraint(equalTo: dateHeaderView.trailingAnchor, constant: -20),
            nextButton.topAnchor.constraint(greaterThanOrEqualTo: dateHeaderView.topAnchor, constant: 8),
            nextButton.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 32),

            dateLabel.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 12),
            {
                let c = dateLabel.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -12)
                c.priority = UILayoutPriority(999)
                return c
            }(),
            dateLabel.topAnchor.constraint(equalTo: dateHeaderView.topAnchor, constant: 8),
            dateLabel.bottomAnchor.constraint(equalTo: dateHeaderView.bottomAnchor, constant: -8),

            // Collection View
            collectionView.topAnchor.constraint(equalTo: dateHeaderView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            noGamesLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noGamesLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Error container
            errorContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            errorContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
            
            errorLabel.topAnchor.constraint(equalTo: errorContainer.topAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor),
            
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 8),
            retryButton.centerXAnchor.constraint(equalTo: errorContainer.centerXAnchor),
            retryButton.bottomAnchor.constraint(equalTo: errorContainer.bottomAnchor),
        ])
        dateHeaderHeightConstraint = dateHeaderView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        dateHeaderHeightConstraint?.isActive = true
        applyTypography()
        updateCollectionLayout()
    }

    private func setupNavigationBar() {        title = "Based"

        let titleFont = BarAppearanceSupport.titleFont(for: traitCollection)
        let buttonFont = BarAppearanceSupport.buttonFont(for: traitCollection)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.paper
        appearance.titleTextAttributes = [.font: titleFont, .foregroundColor: pencilColor]
        appearance.largeTitleTextAttributes = [.font: titleFont, .foregroundColor: pencilColor]
        appearance.shadowColor = .clear
        configurePlainBarButtonAppearance(appearance.buttonAppearance, font: buttonFont, color: pencilColor)
        configurePlainBarButtonAppearance(appearance.backButtonAppearance, font: buttonFont, color: pencilColor)
        
        if let navigationBar = navigationController?.navigationBar {
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
            navigationBar.tintColor = pencilColor
            navigationBar.setNeedsLayout()
            navigationBar.layoutIfNeeded()
        }
    }

    private func configurePlainBarButtonAppearance(_ appearance: UIBarButtonItemAppearance, font: UIFont, color: UIColor) {
        BarAppearanceSupport.applyPlainBarButtonAppearance(appearance, font: font, color: color)
    }
    
    private func setupDatePickerOverlay() {
        datePickerOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        datePickerOverlay.isHidden = true
        datePickerOverlay.isAccessibilityElement = false
        datePickerOverlay.accessibilityViewIsModal = true
        datePickerOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(datePickerOverlay)
        
        datePickerContainer.backgroundColor = AppColors.paper
        datePickerContainer.layer.cornerRadius = 16
        datePickerContainer.translatesAutoresizingMaskIntoConstraints = false
        datePickerContainer.shouldGroupAccessibilityChildren = true
        datePickerOverlay.addSubview(datePickerContainer)
        
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.maximumDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        datePicker.tintColor = pencilColor
        datePicker.accessibilityLabel = "Schedule date picker"
        datePicker.accessibilityHint = "Swipe up or down to adjust the selected date."
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
        datePickerContainer.addSubview(datePicker)
        
        datePickerDoneButton.setTitle("DONE", for: .normal)
        datePickerDoneButton.titleLabel?.font = AppFont.permanent(18, textStyle: .headline, compatibleWith: traitCollection)
        datePickerDoneButton.titleLabel?.adjustsFontForContentSizeCategory = true
        datePickerDoneButton.tintColor = pencilColor
        datePickerDoneButton.accessibilityHint = "Double tap to close the calendar and show the selected schedule."
        datePickerDoneButton.addTarget(self, action: #selector(hideDatePicker), for: .touchUpInside)
        datePickerDoneButton.translatesAutoresizingMaskIntoConstraints = false
        datePickerContainer.addSubview(datePickerDoneButton)
        
        NSLayoutConstraint.activate([
            datePickerOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            datePickerOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            datePickerOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            datePickerOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            datePickerContainer.centerXAnchor.constraint(equalTo: datePickerOverlay.centerXAnchor),
            datePickerContainer.centerYAnchor.constraint(equalTo: datePickerOverlay.centerYAnchor),
            datePickerContainer.widthAnchor.constraint(equalTo: datePickerOverlay.widthAnchor, multiplier: 0.85),
            
            datePicker.topAnchor.constraint(equalTo: datePickerContainer.topAnchor, constant: 16),
            datePicker.leadingAnchor.constraint(equalTo: datePickerContainer.leadingAnchor, constant: 16),
            datePicker.trailingAnchor.constraint(equalTo: datePickerContainer.trailingAnchor, constant: -16),
            
            datePickerDoneButton.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 8),
            datePickerDoneButton.centerXAnchor.constraint(equalTo: datePickerContainer.centerXAnchor),
            datePickerDoneButton.bottomAnchor.constraint(equalTo: datePickerContainer.bottomAnchor, constant: -16)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(hideDatePickerWithoutUpdate))
        tap.delegate = self
        datePickerOverlay.addGestureRecognizer(tap)
    }
    
    @objc private func dateChanged(_ sender: UIDatePicker) {
        // No-op, just to ensure picker responds properly
    }
    
    @objc private func showDatePicker() {
        datePicker.date = currentDate
        datePickerOverlay.alpha = 0
        datePickerOverlay.isHidden = false
        dateHeaderView.accessibilityElementsHidden = true
        collectionView.accessibilityElementsHidden = true
        noGamesLabel.accessibilityElementsHidden = true
        UIView.animate(withDuration: 0.3) {
            self.datePickerOverlay.alpha = 1.0
        } completion: { _ in
            UIAccessibility.post(notification: .screenChanged, argument: self.datePicker)
        }
    }
    
    @objc private func hideDatePicker() {
        let newDate = datePicker.date
        loadSchedule(for: newDate)
        
        UIView.animate(withDuration: 0.2, animations: {
            self.datePickerOverlay.alpha = 0
        }) { _ in
            self.datePickerOverlay.isHidden = true
            self.dateHeaderView.accessibilityElementsHidden = false
            self.collectionView.accessibilityElementsHidden = false
            self.noGamesLabel.accessibilityElementsHidden = false
            UIAccessibility.post(notification: .screenChanged, argument: self.dateLabel)
        }
    }
    
    @objc private func hideDatePickerWithoutUpdate() {
        UIView.animate(withDuration: 0.2, animations: {
            self.datePickerOverlay.alpha = 0
        }) { _ in
            self.datePickerOverlay.isHidden = true
            self.dateHeaderView.accessibilityElementsHidden = false
            self.collectionView.accessibilityElementsHidden = false
            self.noGamesLabel.accessibilityElementsHidden = false
            UIAccessibility.post(notification: .screenChanged, argument: self.dateLabel)
        }
    }
    
    private func updateDateLabel() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        dateLabel.text = formatter.string(from: currentDate)
        dateLabel.accessibilityLabel = "Schedule for \(formatter.string(from: currentDate))"
        
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let isTomorrow = Calendar.current.isDate(currentDate, inSameDayAs: tomorrow)
        nextButton.isEnabled = !isTomorrow
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.3
        nextButton.accessibilityHint = isTomorrow ? "No later games are available." : "Double tap and hold to jump to today."
    }

    private enum ScheduleStatusPriority: Int {
        case live = 0
        case delayedOrSuspended = 1
        case scheduled = 2
        case final = 3
    }

    private enum LiveProgressHalf: Int {
        case end = 0
        case bottom = 1
        case middle = 2
        case top = 3
        case unknown = 4
    }

    private func sortedGames(_ games: [ScheduleGame]) -> [ScheduleGame] {
        let favoriteIds = FavoritesService.shared.getFavoriteTeamIds()
        
        return games.sorted { lhs, rhs in
            let lhsAwayId = lhs.teams.away.team.id ?? 0
            let lhsHomeId = lhs.teams.home.team.id ?? 0
            let rhsAwayId = rhs.teams.away.team.id ?? 0
            let rhsHomeId = rhs.teams.home.team.id ?? 0
            
            let lhsFavoriteIndex = favoriteIds.firstIndex { $0 == lhsAwayId || $0 == lhsHomeId }
            let rhsFavoriteIndex = favoriteIds.firstIndex { $0 == rhsAwayId || $0 == rhsHomeId }
            
            if let lIndex = lhsFavoriteIndex, let rIndex = rhsFavoriteIndex {
                if lIndex != rIndex { return lIndex < rIndex }
            } else if lhsFavoriteIndex != nil {
                return true
            } else if rhsFavoriteIndex != nil {
                return false
            }

            let lhsStart = scheduleDate(from: lhs.gameDate)
            let rhsStart = scheduleDate(from: rhs.gameDate)
            if lhsStart != rhsStart { return lhsStart < rhsStart }

            let lhsStatus = statusPriority(for: lhs)
            let rhsStatus = statusPriority(for: rhs)
            if lhsStatus != rhsStatus { return lhsStatus.rawValue < rhsStatus.rawValue }

            if lhsStatus == .live {
                let lhsProgress = liveProgress(for: lhs)
                let rhsProgress = liveProgress(for: rhs)
                if lhsProgress.inning != rhsProgress.inning { return lhsProgress.inning > rhsProgress.inning }
                if lhsProgress.half != rhsProgress.half { return lhsProgress.half.rawValue < rhsProgress.half.rawValue }
            }

            let lhsHome = lhs.teams.home.team.name ?? ""
            let rhsHome = rhs.teams.home.team.name ?? ""
            let nameOrder = lhsHome.localizedCaseInsensitiveCompare(rhsHome)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }

            return lhs.gamePk < rhs.gamePk
        }
    }

    private func isFavoriteGame(_ game: ScheduleGame) -> Bool {
        FavoritesService.shared.isFavorite(teamId: game.teams.away.team.id ?? 0) ||
        FavoritesService.shared.isFavorite(teamId: game.teams.home.team.id ?? 0)
    }

    private func scheduleDate(from isoDate: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoDate) {
            return date
        }

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        return fallbackFormatter.date(from: isoDate) ?? .distantFuture
    }

    private func statusPriority(for game: ScheduleGame) -> ScheduleStatusPriority {
        let detailedState = game.status.detailedState.lowercased()
        let statusCode = game.status.statusCode?.lowercased() ?? ""

        if isLiveState(detailedState) {
            return .live
        }

        if detailedState.contains("delay") || detailedState.contains("suspend") || detailedState.contains("postpon") {
            return .delayedOrSuspended
        }

        if detailedState == "final" ||
            detailedState == "game over" ||
            detailedState == "completed early" ||
            statusCode == "f" ||
            statusCode == "o" {
            return .final
        }

        return .scheduled
    }

    private func isLiveState(_ detailedState: String) -> Bool {
        detailedState == "in progress" ||
        detailedState.hasPrefix("top ") ||
        detailedState.hasPrefix("bottom ") ||
        detailedState.hasPrefix("middle ") ||
        detailedState.hasPrefix("mid ") ||
        detailedState.hasPrefix("end ")
    }

    private func liveProgress(for game: ScheduleGame) -> (inning: Int, half: LiveProgressHalf) {
        let detailedState = game.status.detailedState.lowercased()
        let inning = inningNumber(from: detailedState)
        let half: LiveProgressHalf

        if detailedState.hasPrefix("end ") {
            half = .end
        } else if detailedState.hasPrefix("bottom ") {
            half = .bottom
        } else if detailedState.hasPrefix("middle ") || detailedState.hasPrefix("mid ") {
            half = .middle
        } else if detailedState.hasPrefix("top ") {
            half = .top
        } else {
            half = .unknown
        }

        return (inning, half)
    }

    private func inningNumber(from detailedState: String) -> Int {
        let digits = detailedState.compactMap(\.wholeNumberValue)
        guard !digits.isEmpty else { return 0 }
        return digits.reduce(0) { ($0 * 10) + $1 }
    }

    private func loadSchedule(for date: Date, triggerAutoEntry: Bool = false) {
        loadTask?.cancel()
        let didChangeDate = !Calendar.current.isDate(currentDate, inSameDayAs: date)
        currentDate = date
        updateDateLabel()

        if didChangeDate {
            currentGames = []
            collectionView.reloadData()
        }
        
        // Show loading only when we have no data to show (not during pull-to-refresh)
        let showSpinner = currentGames.isEmpty && !collectionView.refreshControl!.isRefreshing
        if showSpinner {
            loadingIndicator.startAnimating()
        }
        errorContainer.isHidden = true
        noGamesLabel.isHidden = true

        loadTask = Task {
            do {
                let games = sortedGames(try await GameService.shared.fetchSchedule(for: date))
                guard !Task.isCancelled else { return }
                self.currentGames = games
                self.loadingIndicator.stopAnimating()
                self.collectionView.refreshControl?.endRefreshing()
                self.noGamesLabel.isHidden = !games.isEmpty
                self.errorContainer.isHidden = true
                self.collectionView.reloadData()
                if triggerAutoEntry {
                    self.checkForAutoEntry()
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("Error schedule: \(error)")
                self.loadingIndicator.stopAnimating()
                self.collectionView.refreshControl?.endRefreshing()
                // Only show error state if we have nothing to display
                if self.currentGames.isEmpty {
                    self.errorContainer.isHidden = false
                    self.noGamesLabel.isHidden = true
                    UIAccessibility.post(notification: .screenChanged, argument: self.errorLabel)
                }
            }
        }
    }
    
    @objc private func pullToRefresh() {
        loadSchedule(for: currentDate)
    }
    
    @objc private func retryTapped() {
        loadSchedule(for: currentDate)
    }
    
    @objc private func prevDate() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) else { return }
        loadSchedule(for: newDate)
    }
    
    @objc private func nextDate() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) else { return }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        if Calendar.current.compare(newDate, to: tomorrow, toGranularity: .day) == .orderedDescending { return }
        loadSchedule(for: newDate)
    }

    @objc private func jumpToToday(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            let today = Date()
            if !Calendar.current.isDateInToday(currentDate) {
                // Haptic feedback for the jump (unavailable on Mac)
                if !ProcessInfo.processInfo.isiOSAppOnMac {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                
                loadSchedule(for: today)
            }
        }
    }

    @objc private func handleGameLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: collectionView)
        
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        let game = currentGames[indexPath.item]
        
        let alert = UIAlertController(title: "Favorite Teams", message: "Pin games involving these teams to the top.", preferredStyle: .actionSheet)
        
        // Away Team
        if let awayId = game.teams.away.team.id {
            let awayName = game.teams.away.team.name ?? "Away Team"
            let awayIsFav = FavoritesService.shared.isFavorite(teamId: awayId)
            alert.addAction(UIAlertAction(title: awayIsFav ? "Unfavorite \(awayName)" : "Favorite \(awayName)", style: awayIsFav ? .destructive : .default) { [weak self] _ in
                FavoritesService.shared.toggleFavorite(teamId: awayId)
                self?.loadSchedule(for: self?.currentDate ?? Date())
            })
        }
        
        // Home Team
        if let homeId = game.teams.home.team.id {
            let homeName = game.teams.home.team.name ?? "Home Team"
            let homeIsFav = FavoritesService.shared.isFavorite(teamId: homeId)
            alert.addAction(UIAlertAction(title: homeIsFav ? "Unfavorite \(homeName)" : "Favorite \(homeName)", style: homeIsFav ? .destructive : .default) { [weak self] _ in
                FavoritesService.shared.toggleFavorite(teamId: homeId)
                self?.loadSchedule(for: self?.currentDate ?? Date())
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let cell = collectionView.cellForItem(at: indexPath) {
            alert.popoverPresentationController?.sourceView = cell
            alert.popoverPresentationController?.sourceRect = cell.bounds
        }
        
        present(alert, animated: true)
    }
}

extension ScheduleViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return currentGames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GameCardCell.reuseIdentifier, for: indexPath) as! GameCardCell
        cell.configure(with: currentGames[indexPath.item], isSelected: false)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let game = currentGames[indexPath.item]
        let detailVC = GameDetailViewController(gamePk: game.gamePk, games: currentGames)
        detailVC.hidesBottomBarWhenPushed = true
        
        // Setup handwriting back button for the detail view
        let font = AppFont.permanent(18, textStyle: .headline, compatibleWith: traitCollection)
        let backItem = UIBarButtonItem(title: "< BACK", style: .plain, target: nil, action: nil)
        backItem.setTitleTextAttributes([.font: font, .foregroundColor: AppColors.pencil], for: .normal)
        navigationItem.backBarButtonItem = backItem
        
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

private extension ScheduleViewController {
    func applyTypography() {
        noGamesLabel.font = AppFont.patrick(20, textStyle: .title3, compatibleWith: traitCollection)
        dateLabel.numberOfLines = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 2 : 1
    }

    func checkForAutoEntry() {
        guard !hasAttemptedAutoEntry else { return }
        guard Calendar.current.isDateInToday(currentDate) else { return }
        
        // Ensure we are on the visible tab and the top of the stack
        guard let nav = navigationController,
              nav.tabBarController?.selectedViewController === nav,
              nav.topViewController === self else {
            return
        }

        let autoEnterGames = currentGames.filter { game in
            let detailedState = game.status.detailedState.lowercased()
            guard isLiveState(detailedState) else { return false }
            
            let awayId = game.teams.away.team.id ?? 0
            let homeId = game.teams.home.team.id ?? 0
            
            let awayAuto = FavoritesService.shared.isFavorite(teamId: awayId) && FavoritesService.shared.isAutoEnterEnabled(for: awayId)
            let homeAuto = FavoritesService.shared.isFavorite(teamId: homeId) && FavoritesService.shared.isAutoEnterEnabled(for: homeId)
            
            return awayAuto || homeAuto
        }

        if let gameToEnter = autoEnterGames.first {
            hasAttemptedAutoEntry = true
            
            let detailVC = GameDetailViewController(gamePk: gameToEnter.gamePk, games: currentGames)
            detailVC.hidesBottomBarWhenPushed = true
            
            let font = AppFont.permanent(18, textStyle: .headline, compatibleWith: traitCollection)
            let backItem = UIBarButtonItem(title: "< BACK", style: .plain, target: nil, action: nil)
            backItem.setTitleTextAttributes([.font: font, .foregroundColor: AppColors.pencil], for: .normal)
            navigationItem.backBarButtonItem = backItem
            
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }

    func updateCollectionLayout() {
        guard let layout = collectionView?.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let category = traitCollection.preferredContentSizeCategory
        let singleColumnCategories: Set<UIContentSizeCategory> = [
            .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
            .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge,
            .extraExtraExtraLarge, .extraExtraLarge
        ]
        let columns: CGFloat = singleColumnCategories.contains(category) ? 1 : 2
        let availableWidth = max(view.bounds.width - 32 - (columns > 1 ? 12 : 0), 100)
        let width = floor(availableWidth / columns)
        let height: CGFloat
        if category == .accessibilityExtraExtraExtraLarge {
            height = 250
        } else if category == .accessibilityExtraExtraLarge {
            height = 230
        } else if category == .accessibilityExtraLarge {
            height = 210
        } else if category == .accessibilityLarge {
            height = 190
        } else if category == .accessibilityMedium {
            height = 175
        } else if category == .extraExtraExtraLarge {
            height = 150
        } else if category == .extraExtraLarge {
            height = 142
        } else if category == .extraLarge {
            height = 132
        } else {
            height = 120
        }
        let size = CGSize(width: width, height: height)
        if layout.itemSize != size {
            layout.itemSize = size
            layout.invalidateLayout()
        }
    }

    func handleAccessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        guard datePickerOverlay.isHidden else { return false }

        switch direction {
        case .left:
            let previousDate = currentDate
            nextDate()
            guard !Calendar.current.isDate(previousDate, inSameDayAs: currentDate) else { return false }
            UIAccessibility.post(notification: .pageScrolled, argument: dateLabel.accessibilityLabel)
            return true
        case .right:
            let previousDate = currentDate
            prevDate()
            guard !Calendar.current.isDate(previousDate, inSameDayAs: currentDate) else { return false }
            UIAccessibility.post(notification: .pageScrolled, argument: dateLabel.accessibilityLabel)
            return true
        default:
            return false
        }
    }
}

extension ScheduleViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Prevent dismissal if we tap on the picker container
        return touch.view == datePickerOverlay
    }
}

private final class ScheduleRootView: UIView {
    var onAccessibilityScroll: ((UIAccessibilityScrollDirection) -> Bool)?

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        onAccessibilityScroll?(direction) ?? false
    }
}
