import UIKit

class ScheduleViewController: UIViewController {
    
    // UI Components
    private let dateHeaderView = UIView()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let dateLabel = UILabel()
    
    private var collectionView: UICollectionView!
    private var currentGames: [ScheduleGame] = []
    private var currentDate: Date = Date()
    
    // Date Picker Pop-up Overlay
    private let datePickerOverlay = UIView()
    private let datePicker = UIDatePicker()
    
    private let noGamesLabel: UILabel = {
        let label = UILabel()
        label.text = "No games scheduled"
        label.font = UIFont(name: "PatrickHand-Regular", size: 20) ?? .systemFont(ofSize: 20)
        label.textColor = AppColors.pencil.withAlphaComponent(0.5)
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    // Constants
    private var pencilColor: UIColor { AppColors.pencil }
    private let headerFont = "PermanentMarker-Regular"
    private let bodyFont = "PatrickHand-Regular"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDatePickerOverlay()
        loadSchedule(for: currentDate)
        
        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)
        
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: ScheduleViewController, _) in
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
        collectionView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
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
        prevButton.addTarget(self, action: #selector(prevDate), for: .touchUpInside)
        
        let nextImg = UIImage.pencilStyledIcon(named: "arrow.right", color: pencilColor, size: arrowSize)
        nextButton.setImage(nextImg, for: .normal)
        nextButton.setTitle(nil, for: .normal)
        nextButton.tintColor = pencilColor
        nextButton.addTarget(self, action: #selector(nextDate), for: .touchUpInside)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(jumpToToday(_:)))
        nextButton.addGestureRecognizer(longPress)
        
        dateLabel.font = UIFont(name: headerFont, size: 20) ?? .boldSystemFont(ofSize: 20)
        dateLabel.textColor = pencilColor
        dateLabel.textAlignment = .center
        dateLabel.isUserInteractionEnabled = true
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
        
        let padding: CGFloat = 16 * 2 + 12
        let screenWidth = view.window?.windowScene?.screen.bounds.width ?? view.frame.width
        let width = (screenWidth - padding) / 2
        layout.itemSize = CGSize(width: width, height: 120) 
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(GameCardCell.self, forCellWithReuseIdentifier: GameCardCell.reuseIdentifier)
        
        let gameLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleGameLongPress(_:)))
        collectionView.addGestureRecognizer(gameLongPress)
        
        [collectionView, noGamesLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            // Date Header
            dateHeaderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            dateHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dateHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dateHeaderView.heightAnchor.constraint(equalToConstant: 50),

            prevButton.leadingAnchor.constraint(equalTo: dateHeaderView.leadingAnchor, constant: 20),
            prevButton.centerYAnchor.constraint(equalTo: dateHeaderView.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 32),

            nextButton.trailingAnchor.constraint(equalTo: dateHeaderView.trailingAnchor, constant: -20),
            nextButton.centerYAnchor.constraint(equalTo: dateHeaderView.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 32),

            dateLabel.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor),
            {
                let c = dateLabel.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor)
                c.priority = UILayoutPriority(999)
                return c
            }(),
            dateLabel.centerYAnchor.constraint(equalTo: dateHeaderView.centerYAnchor),

            // Collection View
            collectionView.topAnchor.constraint(equalTo: dateHeaderView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            noGamesLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noGamesLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        }

    private func setupNavigationBar() {        title = "Based"
        
        let font = UIFont(name: "PermanentMarker-Regular", size: 28) ?? .systemFont(ofSize: 28, weight: .bold)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.paper
        appearance.titleTextAttributes = [.font: font, .foregroundColor: pencilColor]
        appearance.shadowColor = .clear
        configurePlainBarButtonAppearance(appearance.buttonAppearance, color: pencilColor)
        configurePlainBarButtonAppearance(appearance.backButtonAppearance, color: pencilColor)
        
        if let navigationBar = navigationController?.navigationBar {
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
            navigationBar.tintColor = pencilColor
        }
    }

    private func configurePlainBarButtonAppearance(_ appearance: UIBarButtonItemAppearance, color: UIColor) {
        let normalState = appearance.normal
        normalState.backgroundImage = UIImage()

        let highlightedState = appearance.highlighted
        highlightedState.backgroundImage = UIImage()

        let focusedState = appearance.focused
        focusedState.backgroundImage = UIImage()

        let disabledState = appearance.disabled
        disabledState.backgroundImage = UIImage()

        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color]
        appearance.normal.titleTextAttributes = attributes
        appearance.highlighted.titleTextAttributes = attributes
        appearance.focused.titleTextAttributes = attributes
        appearance.disabled.titleTextAttributes = attributes
    }
    
    private func setupDatePickerOverlay() {
        datePickerOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        datePickerOverlay.isHidden = true
        datePickerOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(datePickerOverlay)
        
        let container = UIView()
        container.backgroundColor = AppColors.paper
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        datePickerOverlay.addSubview(container)
        
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.maximumDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        datePicker.tintColor = pencilColor
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
        container.addSubview(datePicker)
        
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("DONE", for: .normal)
        doneButton.titleLabel?.font = UIFont(name: headerFont, size: 18)
        doneButton.tintColor = pencilColor
        doneButton.addTarget(self, action: #selector(hideDatePicker), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(doneButton)
        
        NSLayoutConstraint.activate([
            datePickerOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            datePickerOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            datePickerOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            datePickerOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            container.centerXAnchor.constraint(equalTo: datePickerOverlay.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: datePickerOverlay.centerYAnchor),
            container.widthAnchor.constraint(equalTo: datePickerOverlay.widthAnchor, multiplier: 0.85),
            
            datePicker.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            datePicker.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            datePicker.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            doneButton.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 8),
            doneButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            doneButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
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
        UIView.animate(withDuration: 0.3) {
            self.datePickerOverlay.alpha = 1.0
        }
    }
    
    @objc private func hideDatePicker() {
        let newDate = datePicker.date
        loadSchedule(for: newDate)
        
        UIView.animate(withDuration: 0.2, animations: {
            self.datePickerOverlay.alpha = 0
        }) { _ in
            self.datePickerOverlay.isHidden = true
        }
    }
    
    @objc private func hideDatePickerWithoutUpdate() {
        UIView.animate(withDuration: 0.2, animations: {
            self.datePickerOverlay.alpha = 0
        }) { _ in
            self.datePickerOverlay.isHidden = true
        }
    }
    
    private func updateDateLabel() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        dateLabel.text = formatter.string(from: currentDate)
        
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let isTomorrow = Calendar.current.isDate(currentDate, inSameDayAs: tomorrow)
        nextButton.isEnabled = !isTomorrow
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.3
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
        games.sorted { lhs, rhs in
            let lhsFavorite = isFavoriteGame(lhs)
            let rhsFavorite = isFavoriteGame(rhs)
            if lhsFavorite != rhsFavorite { return lhsFavorite && !rhsFavorite }

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

    private func loadSchedule(for date: Date) {
        currentDate = date
        updateDateLabel()

        Task {
            do {
                let games = sortedGames(try await GameService.shared.fetchSchedule(for: date))
                self.currentGames = games
                await MainActor.run {
                    self.noGamesLabel.isHidden = !games.isEmpty
                    self.collectionView.reloadData()
                }
            } catch {
                print("Error schedule: \(error)")
            }
        }
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
                // Haptic feedback for the jump
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
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
        let font = UIFont(name: "PermanentMarker-Regular", size: 18) ?? .systemFont(ofSize: 18)
        let backItem = UIBarButtonItem(title: "< BACK", style: .plain, target: nil, action: nil)
        backItem.setTitleTextAttributes([.font: font, .foregroundColor: AppColors.pencil], for: .normal)
        navigationItem.backBarButtonItem = backItem
        
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

extension ScheduleViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Prevent dismissal if we tap on the picker container
        return touch.view == datePickerOverlay
    }
}
