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
        label.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.5)
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    // Constants
    private let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
    private let headerFont = "PermanentMarker-Regular"
    private let bodyFont = "PatrickHand-Regular"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupDatePickerOverlay()
        loadSchedule(for: currentDate)
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)
        
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
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(GameCardCell.self, forCellWithReuseIdentifier: GameCardCell.reuseIdentifier)
        
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
    
    private func setupNavigationBar() {
        title = "BASED"
        
        let font = UIFont(name: "PermanentMarker-Regular", size: 28) ?? .systemFont(ofSize: 28, weight: .bold)
        let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)
        appearance.titleTextAttributes = [.font: font, .foregroundColor: pencilColor]
        appearance.shadowColor = .clear
        
        if let navigationBar = navigationController?.navigationBar {
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
            navigationBar.tintColor = pencilColor
        }
    }
    
    private func setupDatePickerOverlay() {
        datePickerOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        datePickerOverlay.isHidden = true
        datePickerOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(datePickerOverlay)
        
        let container = UIView()
        container.backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        datePickerOverlay.addSubview(container)
        
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.maximumDate = Date()
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
        
        let isToday = Calendar.current.isDateInToday(currentDate)
        nextButton.isEnabled = !isToday
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.3
    }

    private func loadSchedule(for date: Date) {
        currentDate = date
        updateDateLabel()
        Task {
            do {
                let games = try await GameService.shared.fetchSchedule(for: date)
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
        if newDate > Date() { return }
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
        
        // Setup handwriting back button for the detail view
        let font = UIFont(name: "PermanentMarker-Regular", size: 18) ?? .systemFont(ofSize: 18)
        let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        let backItem = UIBarButtonItem(title: "< BACK", style: .plain, target: nil, action: nil)
        backItem.setTitleTextAttributes([.font: font, .foregroundColor: pencilColor], for: .normal)
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
