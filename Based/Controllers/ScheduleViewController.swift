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
        
        prevButton.setTitle("<", for: .normal)
        prevButton.titleLabel?.font = UIFont(name: headerFont, size: 24) ?? .boldSystemFont(ofSize: 24)
        prevButton.tintColor = pencilColor
        prevButton.addTarget(self, action: #selector(prevDate), for: .touchUpInside)
        
        nextButton.setTitle(">", for: .normal)
        nextButton.titleLabel?.font = UIFont(name: headerFont, size: 24) ?? .boldSystemFont(ofSize: 24)
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
        layout.footerReferenceSize = CGSize(width: screenWidth, height: 140)        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(GameCardCell.self, forCellWithReuseIdentifier: GameCardCell.reuseIdentifier)
        collectionView.register(ScheduleFooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: ScheduleFooterView.reuseIdentifier)
        
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
            prevButton.widthAnchor.constraint(equalToConstant: 44),

            nextButton.trailingAnchor.constraint(equalTo: dateHeaderView.trailingAnchor, constant: -20),
            nextButton.centerYAnchor.constraint(equalTo: dateHeaderView.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 44),

            dateLabel.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor),
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

    private func setupNavigationBar() {        title = "BASED"
        
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
        dateLabel.text = formatter.string(from: currentDate).uppercased()
        
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let isTomorrow = Calendar.current.isDate(currentDate, inSameDayAs: tomorrow)
        nextButton.isEnabled = !isTomorrow
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.3
    }

    private func loadSchedule(for date: Date) {
        currentDate = date
        updateDateLabel()

        Task {
            do {
                var games = try await GameService.shared.fetchSchedule(for: date)

                // Sort favorites to the top
                games.sort { g1, g2 in
                    let g1Fav = FavoritesService.shared.isFavorite(teamId: g1.teams.away.team.id ?? 0) || 
                               FavoritesService.shared.isFavorite(teamId: g1.teams.home.team.id ?? 0)
                    let g2Fav = FavoritesService.shared.isFavorite(teamId: g2.teams.away.team.id ?? 0) || 
                               FavoritesService.shared.isFavorite(teamId: g2.teams.home.team.id ?? 0)

                    if g1Fav && !g2Fav { return true }
                    if !g1Fav && g2Fav { return false }
                    return false // Maintain original order if both or neither are favorites
                }
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

// MARK: - Footer View

// MARK: - Pencil Swatch Button

private class PencilSwatchButton: UIControl {
    let swatchColor: UIColor?  // nil = eraser/reset
    private let fillLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let checkLayer = CAShapeLayer()

    init(color: UIColor?) {
        self.swatchColor = color
        super.init(frame: .zero)
        layer.addSublayer(fillLayer)
        layer.addSublayer(borderLayer)
        layer.addSublayer(checkLayer)
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 1.2
        borderLayer.lineCap = .round
        checkLayer.fillColor = UIColor.clear.cgColor
        checkLayer.lineWidth = 1.8
        checkLayer.lineCap = .round
    }

    required init?(coder: NSCoder) { fatalError() }

    var isCurrentTint: Bool = false {
        didSet { setNeedsLayout() }
    }

    override var intrinsicContentSize: CGSize { CGSize(width: 32, height: 32) }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = min(bounds.width, bounds.height) / 2 - 2

        // Fill
        let circlePath = UIBezierPath.pencilRoughCircle(center: center, radius: radius, jitter: 0.8)
        if let c = swatchColor {
            fillLayer.path = circlePath.cgPath
            fillLayer.fillColor = c.cgColor
        } else {
            // Eraser: empty circle with an X
            fillLayer.path = circlePath.cgPath
            fillLayer.fillColor = AppColors.paper.cgColor
        }

        // Border
        let borderPath = UIBezierPath.pencilRoughCircle(center: center, radius: radius, jitter: 1.0)
        borderLayer.path = borderPath.cgPath
        borderLayer.strokeColor = AppColors.pencil.withAlphaComponent(isCurrentTint ? 0.8 : 0.3).cgColor

        // Check mark or X for eraser
        if swatchColor == nil {
            // Draw a small X
            let s: CGFloat = radius * 0.45
            let xPath = UIBezierPath()
            xPath.append(.pencilLine(from: CGPoint(x: center.x - s, y: center.y - s),
                                     to: CGPoint(x: center.x + s, y: center.y + s), jitter: 0.5))
            xPath.append(.pencilLine(from: CGPoint(x: center.x + s, y: center.y - s),
                                     to: CGPoint(x: center.x - s, y: center.y + s), jitter: 0.5))
            checkLayer.path = xPath.cgPath
            checkLayer.strokeColor = AppColors.pencil.withAlphaComponent(0.4).cgColor
        } else if isCurrentTint {
            // Draw a small check
            let s: CGFloat = radius * 0.4
            let checkPath = UIBezierPath()
            checkPath.append(.pencilLine(
                from: CGPoint(x: center.x - s * 0.6, y: center.y),
                to: CGPoint(x: center.x - s * 0.1, y: center.y + s * 0.5), jitter: 0.3))
            checkPath.append(.pencilLine(
                from: CGPoint(x: center.x - s * 0.1, y: center.y + s * 0.5),
                to: CGPoint(x: center.x + s * 0.7, y: center.y - s * 0.5), jitter: 0.3))
            checkLayer.path = checkPath.cgPath
            checkLayer.strokeColor = UIColor.white.cgColor
        } else {
            checkLayer.path = nil
        }
    }
}

class ScheduleFooterView: UICollectionReusableView {
    static let reuseIdentifier = "ScheduleFooterView"

    private let stackView = UIStackView()
    private let madeInStack = UIStackView()
    private let madeWithLabel = UILabel()
    private let heartImageView = UIImageView(image: UIImage(named: "PhiladelphiaLove.symbols")?.withRenderingMode(.alwaysTemplate))
    private let inPhiladelphiaLabel = UILabel()


    // Tint row
    private let tintRow = UIStackView()
    private let colorWell = UIColorWell()
    private var swatchButtons: [PencilSwatchButton] = []

    private static let presetColors: [UIColor] = [
        UIColor(red: 0.00, green: 0.22, blue: 0.52, alpha: 1.0),   // Dodger blue
        UIColor(red: 0.76, green: 0.09, blue: 0.17, alpha: 1.0),   // Cardinal red
        UIColor(red: 0.11, green: 0.24, blue: 0.15, alpha: 1.0),   // Oakland green
        UIColor(red: 0.92, green: 0.38, blue: 0.04, alpha: 1.0),   // Oriole orange
        UIColor(red: 0.42, green: 0.27, blue: 0.14, alpha: 1.0),   // Padre brown
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        let font = UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14)
        let pencilColor = AppColors.pencil.withAlphaComponent(0.6)

        [madeWithLabel, inPhiladelphiaLabel].forEach {
            $0.font = font
            $0.textColor = pencilColor
            $0.textAlignment = .center
        }

        madeWithLabel.text = "Made with "
        inPhiladelphiaLabel.text = " in Philadelphia by Colin Weir"

        heartImageView.contentMode = .scaleAspectFit
        heartImageView.tintColor = .systemRed
        heartImageView.setContentHuggingPriority(.required, for: .horizontal)
        heartImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        madeInStack.axis = .horizontal
        madeInStack.spacing = 0
        madeInStack.alignment = .center
        madeInStack.addArrangedSubview(madeWithLabel)
        madeInStack.addArrangedSubview(heartImageView)
        madeInStack.addArrangedSubview(inPhiladelphiaLabel)

        // Build tint swatch row: eraser + presets + color well
        tintRow.axis = .horizontal
        tintRow.spacing = 8
        tintRow.alignment = .center

        // Eraser button (nil color = reset)
        let eraserBtn = PencilSwatchButton(color: nil)
        eraserBtn.addTarget(self, action: #selector(swatchTapped(_:)), for: .touchUpInside)
        tintRow.addArrangedSubview(eraserBtn)
        swatchButtons.append(eraserBtn)

        // Preset color swatches
        for color in Self.presetColors {
            let btn = PencilSwatchButton(color: color)
            btn.addTarget(self, action: #selector(swatchTapped(_:)), for: .touchUpInside)
            tintRow.addArrangedSubview(btn)
            swatchButtons.append(btn)
        }

        // Color well for custom
        colorWell.supportsAlpha = false
        colorWell.selectedColor = TintService.shared.tintColor
        colorWell.addTarget(self, action: #selector(colorChanged(_:)), for: .valueChanged)
        tintRow.addArrangedSubview(colorWell)

        updateSwatchSelection()

        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        stackView.addArrangedSubview(tintRow)
        stackView.addArrangedSubview(madeInStack)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -32),
            heartImageView.heightAnchor.constraint(equalToConstant: 14),
            heartImageView.widthAnchor.constraint(equalToConstant: 16)
        ])
    }

    private func updateSwatchSelection() {
        let current = TintService.shared.tintColor
        for btn in swatchButtons {
            if let sc = btn.swatchColor, let cur = current {
                // Compare hue to handle dynamic color resolution
                var h1: CGFloat = 0, h2: CGFloat = 0
                var s1: CGFloat = 0, s2: CGFloat = 0
                sc.getHue(&h1, saturation: &s1, brightness: nil, alpha: nil)
                cur.getHue(&h2, saturation: &s2, brightness: nil, alpha: nil)
                btn.isCurrentTint = abs(h1 - h2) < 0.02 && abs(s1 - s2) < 0.1
            } else {
                btn.isCurrentTint = (btn.swatchColor == nil && current == nil)
            }
        }
    }

    @objc private func swatchTapped(_ sender: PencilSwatchButton) {
        TintService.shared.tintColor = sender.swatchColor
        colorWell.selectedColor = sender.swatchColor
    }

    @objc private func colorChanged(_ sender: UIColorWell) {
        TintService.shared.tintColor = sender.selectedColor
    }

    @objc private func tintDidChange() {
        updateSwatchSelection()
        // Refresh attribution label colors
        let pencilColor = AppColors.pencil.withAlphaComponent(0.6)
        [madeWithLabel, inPhiladelphiaLabel].forEach { $0.textColor = pencilColor }
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
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionFooter {
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ScheduleFooterView.reuseIdentifier, for: indexPath) as! ScheduleFooterView
            return footer
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let game = currentGames[indexPath.item]
        let detailVC = GameDetailViewController(gamePk: game.gamePk, games: currentGames)
        
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
