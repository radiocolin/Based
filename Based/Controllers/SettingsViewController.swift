import UIKit

class SettingsViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var favoriteTeamIds: [Int] = []
    private var teamMap: [Int: String] = [:]
    
    private let appearanceOptions = ThemeService.Theme.allCases
    private let mlbTeams = [
        "Arizona Diamondbacks", "Atlanta Braves", "Baltimore Orioles", "Boston Red Sox",
        "Chicago Cubs", "Chicago White Sox", "Cincinnati Reds", "Cleveland Guardians",
        "Colorado Rockies", "Detroit Tigers", "Houston Astros", "Kansas City Royals",
        "Los Angeles Angels", "Los Angeles Dodgers", "Miami Marlins", "Milwaukee Brewers",
        "Minnesota Twins", "New York Mets", "New York Yankees", "Oakland Athletics",
        "Philadelphia Phillies", "Pittsburgh Pirates", "San Diego Padres", "San Francisco Giants",
        "Seattle Mariners", "St. Louis Cardinals", "Tampa Bay Rays", "Texas Rangers",
        "Toronto Blue Jays", "Washington Nationals"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(favoritesDidChange), name: FavoritesService.favoritesDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: ThemeService.themeDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)
    }
    
    private func setupUI() {
        title = "Settings"
        view.backgroundColor = AppColors.paper
        
        setupNavigationBar()
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func favoriteTeamName(for id: Int) -> String {
        teamMap[id] ?? "Team \(id)"
    }
    
    private func setupNavigationBar() {
        let font = UIFont(name: "PermanentMarker-Regular", size: 28) ?? .systemFont(ofSize: 28, weight: .bold)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.paper
        appearance.titleTextAttributes = [.font: font, .foregroundColor: AppColors.pencil]
        appearance.shadowColor = .clear
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = AppColors.pencil
    }
    
    private func loadData() {
        favoriteTeamIds = FavoritesService.shared.getFavoriteTeamIds()
        
        Task {
            do {
                let teams = try await MLBAPIClient.shared.fetchTeams()
                await MainActor.run {
                    self.teamMap = Dictionary(uniqueKeysWithValues: teams.compactMap { team in
                        guard let id = team.id, let name = team.name else { return nil }
                        return (id, name)
                    })
                    self.tableView.reloadData()
                }
            } catch {
                print("Error fetching teams: \(error)")
            }
        }
    }
    
    @objc private func favoritesDidChange() {
        favoriteTeamIds = FavoritesService.shared.getFavoriteTeamIds()
        tableView.reloadData()
    }
    
    @objc private func themeDidChange() {
        tableView.reloadData()
    }
    
    @objc private func tintDidChange() {
        setupNavigationBar()
        tableView.reloadData()
    }
    
    private func presentColorPicker() {
        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.selectedColor = TintService.shared.tintColor ?? AppColors.pencil
        present(picker, animated: true)
    }
}

extension SettingsViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        TintService.shared.tintColor = viewController.selectedColor
    }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4 // Appearance (Theme + Tint), Favorites, More Apps, Attribution
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2 // Appearance + Tint Color
        case 1: return favoriteTeamIds.count + 1 // Favorites + Add row
        case 2: return 1 // Wheelie
        case 3: return 1 // Attribution
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 3 {
            let footerCell = UITableViewCell(style: .default, reuseIdentifier: "FooterCell")
            footerCell.backgroundColor = .clear
            footerCell.selectionStyle = .none
            footerCell.isAccessibilityElement = true
            footerCell.accessibilityTraits = .staticText
            footerCell.accessibilityLabel = "Made with love in Philadelphia by Colin Weir"
            
            let stack = UIStackView()
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 4
            stack.translatesAutoresizingMaskIntoConstraints = false
            footerCell.contentView.addSubview(stack)
            
            let line1 = UIStackView()
            line1.axis = .horizontal
            line1.alignment = .center
            line1.spacing = 0
            
            let font = UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14)
            let color = AppColors.pencil.withAlphaComponent(0.6)
            
            let label1 = UILabel()
            label1.text = "Made with "
            label1.font = font
            label1.textColor = color
            label1.isAccessibilityElement = false
            
            // Re-reverting to the original SF Symbol implementation
            let heart = UIImageView(image: UIImage(named: "PhiladelphiaLove.symbols")?.withRenderingMode(.alwaysTemplate))
            heart.tintColor = .systemRed
            heart.contentMode = .scaleAspectFit
            heart.setContentHuggingPriority(.required, for: .horizontal)
            heart.setContentCompressionResistancePriority(.required, for: .horizontal)
            heart.isAccessibilityElement = false
            
            let label2 = UILabel()
            label2.text = " in Philadelphia by Colin Weir"
            label2.font = font
            label2.textColor = color
            label2.isAccessibilityElement = false
            
            line1.addArrangedSubview(label1)
            line1.addArrangedSubview(heart)
            line1.addArrangedSubview(label2)
            
            stack.addArrangedSubview(line1)
            
            NSLayoutConstraint.activate([
                heart.heightAnchor.constraint(equalToConstant: 14),
                heart.widthAnchor.constraint(equalToConstant: 16),
                stack.centerXAnchor.constraint(equalTo: footerCell.contentView.centerXAnchor),
                stack.topAnchor.constraint(equalTo: footerCell.contentView.topAnchor, constant: 16),
                stack.bottomAnchor.constraint(equalTo: footerCell.contentView.bottomAnchor, constant: -32)
            ])
            return footerCell
        }
        
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "SettingsCell")
        cell.backgroundColor = .clear
        cell.selectionStyle = .default
        cell.textLabel?.font = UIFont(name: "PatrickHand-Regular", size: 18)
        cell.detailTextLabel?.font = UIFont(name: "PatrickHand-Regular", size: 16)
        cell.textLabel?.textColor = AppColors.pencil
        cell.detailTextLabel?.textColor = AppColors.pencil.withAlphaComponent(0.6)
        cell.accessibilityHint = nil
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.isAccessibilityElement = true
        cell.accessibilityTraits = .button
        cell.textLabel?.isAccessibilityElement = false
        cell.detailTextLabel?.isAccessibilityElement = false
        
        let bg = PencilSectionBackgroundView()
        let rows = tableView.numberOfRows(inSection: indexPath.section)
        if rows == 1 {
            bg.position = .single
        } else if indexPath.row == 0 {
            bg.position = .top
        } else if indexPath.row == rows - 1 {
            bg.position = .bottom
        } else {
            bg.position = .middle
        }
        cell.backgroundView = bg
        
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Appearance"
                let currentTheme = ThemeService.shared.theme
                let actions = appearanceOptions.map { theme in
                    UIAction(title: theme.displayName, state: currentTheme == theme ? .on : .off) { _ in
                        ThemeService.shared.theme = theme
                    }
                }
                let menu = UIMenu(title: "Choose Appearance", children: actions)
                let button = UIButton(type: .system)
                button.setTitle(currentTheme.displayName, for: .normal)
                button.menu = menu
                button.showsMenuAsPrimaryAction = true
                button.titleLabel?.font = cell.detailTextLabel?.font
                button.tintColor = cell.detailTextLabel?.textColor
                button.accessibilityLabel = "Appearance"
                button.accessibilityValue = currentTheme.displayName
                button.accessibilityHint = "Double tap to choose the app appearance."
                cell.accessoryView = button
                button.sizeToFit()
                cell.isAccessibilityElement = false
            } else {
                cell.textLabel?.text = "Tint Color"
                let currentTint = TintService.shared.tintColor
                
                let resetAction = UIAction(title: "Pencil", state: currentTint == nil ? .on : .off) { _ in
                    TintService.shared.tintColor = nil
                }
                
                let customAction = UIAction(title: "Custom Color...", state: .off) { [weak self] _ in
                    self?.presentColorPicker()
                }
                
                var teamActions: [UIAction] = []
                var currentTeamName: String?
                for team in mlbTeams {
                    let color = TeamColorProvider.color(for: team)
                    let isMatch = currentTint != nil && currentTint!.isSimilar(to: color)
                    if isMatch { currentTeamName = team }
                    teamActions.append(UIAction(title: team, state: isMatch ? .on : .off) { _ in
                        TintService.shared.tintColor = color
                    })
                }
                
                let menu = UIMenu(title: "Choose Tint Color", children: [resetAction, customAction, UIMenu(title: "Teams", options: .displayInline, children: teamActions)])
                let button = UIButton(type: .system)
                button.setTitle(currentTeamName ?? (currentTint == nil ? "Pencil" : "Custom"), for: .normal)
                button.menu = menu
                button.showsMenuAsPrimaryAction = true
                button.titleLabel?.font = cell.detailTextLabel?.font
                button.tintColor = cell.detailTextLabel?.textColor
                let tintName = currentTeamName ?? (currentTint == nil ? "Pencil" : "Custom")
                button.accessibilityLabel = "Tint color"
                button.accessibilityValue = tintName
                button.accessibilityHint = "Double tap to choose the tint color."
                cell.accessoryView = button
                button.sizeToFit()
                cell.isAccessibilityElement = false
            }
            
        case 1:
            if indexPath.row < favoriteTeamIds.count {
                let teamId = favoriteTeamIds[indexPath.row]
                let teamName = favoriteTeamName(for: teamId)
                cell.textLabel?.text = teamName
                
                let removeBtn = UIButton(type: .system)
                let xImg = UIImage.pencilStyledIcon(named: "xmark", color: .systemRed, size: CGSize(width: 24, height: 24))
                removeBtn.setImage(xImg, for: .normal)
                removeBtn.tintColor = .systemRed
                removeBtn.accessibilityLabel = "Remove \(teamName) from favorites"
                removeBtn.accessibilityHint = "Double tap to remove this team from favorites."
                removeBtn.addAction(UIAction { _ in
                    FavoritesService.shared.toggleFavorite(teamId: teamId)
                }, for: .touchUpInside)
                removeBtn.sizeToFit()
                cell.accessoryView = removeBtn
                cell.accessibilityLabel = teamName
                cell.accessibilityValue = "Favorite team"
                cell.accessibilityHint = "Use the remove button to remove this team from favorites."
                cell.accessibilityTraits = .staticText
            } else {
                let button = UIButton(type: .system)
                button.setTitle("Add favorite team...", for: .normal)
                button.titleLabel?.font = UIFont(name: "PatrickHand-Regular", size: 18)
                button.contentHorizontalAlignment = .left
                button.accessibilityLabel = "Add favorite team"
                button.accessibilityHint = "Double tap to choose a team to favorite."
                
                let sorted = teamMap.sorted { $0.value < $1.value }
                var actions: [UIAction] = []
                for (id, name) in sorted {
                    if !favoriteTeamIds.contains(id) {
                        actions.append(UIAction(title: name) { _ in
                            FavoritesService.shared.toggleFavorite(teamId: id)
                        })
                    }
                }
                
                button.menu = UIMenu(title: "Add Favorite Team", children: actions)
                button.showsMenuAsPrimaryAction = true
                
                button.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(button)
                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                    button.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                    button.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                    button.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
                ])
                cell.isAccessibilityElement = false
            }
            
        case 2:
            cell.textLabel?.text = "Wheelie"
            cell.detailTextLabel?.text = "Bike Ride Tracking"
            cell.imageView?.image = UIImage(named: "Wheelie-iOS-Default-1024x1024")
            cell.imageView?.layer.cornerRadius = 6
            cell.imageView?.clipsToBounds = true
            let size = CGSize(width: 30, height: 30)
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
            cell.imageView?.image?.draw(in: CGRect(origin: .zero, size: size))
            let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            cell.imageView?.image = scaledImage
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityLabel = "Wheelie"
            cell.accessibilityValue = "Bike Ride Tracking"
            cell.accessibilityHint = "Double tap to open the App Store page."
            
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 1 else { return nil }
        
        let container = UIView()
        container.isAccessibilityElement = true
        container.accessibilityTraits = .header
        container.accessibilityLabel = "Favorite teams. Favorite teams appear first in the schedule."
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isAccessibilityElement = false
        container.addSubview(stack)
        
        let titleLabel = UILabel()
        titleLabel.text = "FAVORITE TEAMS"
        titleLabel.font = UIFont(name: "PermanentMarker-Regular", size: 16)
        titleLabel.textColor = AppColors.pencil.withAlphaComponent(0.7)
        titleLabel.isAccessibilityElement = false
        
        let descLabel = UILabel()
        descLabel.text = "Favorite teams appear first in the schedule."
        descLabel.font = UIFont(name: "PatrickHand-Regular", size: 14)
        descLabel.textColor = AppColors.pencil.withAlphaComponent(0.5)
        descLabel.isAccessibilityElement = false
        
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(descLabel)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8) // Correct breathing room
        ])
        
        return container
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "APPEARANCE"
        case 1: return nil // Custom view
        case 2: return "MORE APPS"
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.font = UIFont(name: "PermanentMarker-Regular", size: 16)
            header.textLabel?.textColor = AppColors.pencil.withAlphaComponent(0.7)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 2 {
            if let url = URL(string: "https://apps.apple.com/us/app/wheelie-bike-ride-tracking/id6747010503") {
                UIApplication.shared.open(url)
            }
        }
    }
}
