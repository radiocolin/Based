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

    private var neutralPencilColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.82, green: 0.80, blue: 0.78, alpha: 0.9)
                : UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        tableView.register(SubtitleCell.self, forCellReuseIdentifier: "SubtitleCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FooterCell")
        setupUI()
        loadData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(favoritesDidChange), name: FavoritesService.favoritesDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: ThemeService.themeDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self, UITraitUserInterfaceStyle.self]) { (self: SettingsViewController, _) in
            self.setupNavigationBar()
            self.tableView.reloadData()
        }
    }
    
    private func setupUI() {
        title = "Settings"
        view.backgroundColor = AppColors.paper
        
        setupNavigationBar()
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 60
        tableView.setEditing(true, animated: false)
        tableView.allowsSelectionDuringEditing = true
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
        let titleFont = BarAppearanceSupport.titleFont(for: traitCollection)
        let buttonFont = BarAppearanceSupport.buttonFont(for: traitCollection)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.paper
        appearance.titleTextAttributes = [.font: titleFont, .foregroundColor: AppColors.pencil]
        appearance.largeTitleTextAttributes = [.font: titleFont, .foregroundColor: AppColors.pencil]
        appearance.shadowColor = .clear
        BarAppearanceSupport.applyPlainBarButtonAppearance(appearance.buttonAppearance, font: buttonFont, color: AppColors.pencil)
        BarAppearanceSupport.applyPlainBarButtonAppearance(appearance.backButtonAppearance, font: buttonFont, color: AppColors.pencil)
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = AppColors.pencil
        navigationController?.navigationBar.setNeedsLayout()
        navigationController?.navigationBar.layoutIfNeeded()
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

    private func presentAppearanceSelector() {
        let currentTheme = ThemeService.shared.theme
        let sections = [
            SettingsSelectionSection(
                title: nil,
                options: appearanceOptions.map { theme in
                    SettingsSelectionOption(
                        title: theme.displayName,
                        isSelected: currentTheme == theme,
                        accessibilityValue: currentTheme == theme ? "Selected" : nil
                    ) { [weak self] in
                        ThemeService.shared.theme = theme
                        self?.dismiss(animated: true)
                    }
                }
            )
        ]

        presentSelectionSheet(title: "Appearance", sections: sections)
    }

    private func presentTintSelector() {
        let currentTint = TintService.shared.tintColor
        let selectedTeamTint = mlbTeams.first { team in
            let color = TeamColorProvider.color(for: team)
            return currentTint != nil && currentTint!.isSimilar(to: color)
        }
        let customTintDisplayColor = selectedTeamTint == nil ? currentTint : nil

        let quickOptions = [
            SettingsSelectionOption(
                title: "Pencil",
                isSelected: currentTint == nil,
                accessibilityValue: currentTint == nil ? "Selected" : nil,
                displayColor: neutralPencilColor
            ) { [weak self] in
                TintService.shared.tintColor = nil
                self?.dismiss(animated: true)
            },
            SettingsSelectionOption(
                title: "Custom Color...",
                displayColor: customTintDisplayColor
            ) { [weak self] in
                self?.dismiss(animated: true) {
                    self?.presentColorPicker()
                }
            }
        ]

        let teamOptions = mlbTeams.map { team in
            let color = TeamColorProvider.color(for: team)
            let isSelected = currentTint != nil && currentTint!.isSimilar(to: color)
            return SettingsSelectionOption(
                title: team,
                isSelected: isSelected,
                accessibilityValue: isSelected ? "Selected" : nil,
                displayColor: color
            ) { [weak self] in
                TintService.shared.tintColor = color
                self?.dismiss(animated: true)
            }
        }

        let sections = [
            SettingsSelectionSection(title: nil, options: quickOptions),
            SettingsSelectionSection(title: "Team Colors", options: teamOptions)
        ]

        presentSelectionSheet(title: "Tint Color", sections: sections)
    }

    private func presentFavoriteTeamSelector() {
        let sorted = teamMap.sorted { $0.value < $1.value }
        let options = sorted.compactMap { id, name -> SettingsSelectionOption? in
            guard !favoriteTeamIds.contains(id) else { return nil }
            return SettingsSelectionOption(title: name) { [weak self] in
                FavoritesService.shared.toggleFavorite(teamId: id)
                self?.dismiss(animated: true)
            }
        }

        let sections = [
            SettingsSelectionSection(title: nil, options: options)
        ]

        presentSelectionSheet(title: "Add Favorite Team", sections: sections)
    }

    private func presentFavoriteTeamOptions(teamId: Int) {
        let teamName = favoriteTeamName(for: teamId)
        let isAutoEnter = FavoritesService.shared.isAutoEnterEnabled(for: teamId)

        let sections = [
            SettingsSelectionSection(
                title: nil,
                options: [
                    SettingsSelectionOption(
                        title: "Automatically enter live games",
                        showToggle: true,
                        isToggleOn: isAutoEnter,
                        toggleAction: { isOn in
                            FavoritesService.shared.setAutoEnterEnabled(isOn, for: teamId)
                        }
                    ),
                    SettingsSelectionOption(
                        title: "Remove favorite",
                        isDestructive: true,
                        action: { [weak self] in
                            FavoritesService.shared.toggleFavorite(teamId: teamId)
                            self?.dismiss(animated: true)
                        }
                    )
                ]
            )
        ]

        presentSelectionSheet(title: teamName, sections: sections)
    }

    private func presentSelectionSheet(title: String, sections: [SettingsSelectionSection]) {
        let controller = SettingsSelectionViewController(titleText: title, sections: sections)
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .pageSheet
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(navigationController, animated: true)
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
        case 2: return 2 // Wheelie, Away Message
        case 3: return 1 // Attribution
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SubtitleCell", for: indexPath)
            cell.backgroundColor = .clear
            cell.selectionStyle = .default
            cell.textLabel?.font = AppFont.patrick(18, textStyle: .body, compatibleWith: traitCollection)
            cell.textLabel?.textColor = AppColors.pencil
            cell.textLabel?.adjustsFontForContentSizeCategory = true
            cell.textLabel?.numberOfLines = 0
            cell.detailTextLabel?.font = AppFont.patrick(14, textStyle: .caption1, compatibleWith: traitCollection)
            cell.detailTextLabel?.textColor = AppColors.pencil.withAlphaComponent(0.6)
            cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
            cell.detailTextLabel?.numberOfLines = 0
            cell.isAccessibilityElement = true
            cell.accessibilityTraits = .button
            cell.textLabel?.isAccessibilityElement = false
            cell.detailTextLabel?.isAccessibilityElement = false
            
            let appName: String
            let appSubtitle: String
            let appIcon: String
            
            if indexPath.row == 0 {
                appName = "Wheelie"
                appSubtitle = "Track every ride"
                appIcon = "Wheelie-iOS-Default-1024x1024"
            } else {
                appName = "Away Message"
                appSubtitle = "Digital sticky notes for your real friends"
                appIcon = "away message icon-iOS-Default-1024x1024"
            }
            
            cell.textLabel?.text = appName
            cell.detailTextLabel?.text = appSubtitle
            let iconAsset = UIImage(named: appIcon)
            let resolved = iconAsset?.imageAsset?.image(with: traitCollection) ?? iconAsset
            let size = CGSize(width: 30, height: 30)
            let renderer = UIGraphicsImageRenderer(size: size)
            let scaledImage = renderer.image { _ in
                resolved?.draw(in: CGRect(origin: .zero, size: size))
            }
            cell.imageView?.image = scaledImage
            cell.imageView?.layer.cornerRadius = 6
            cell.imageView?.clipsToBounds = true
            cell.accessoryType = .disclosureIndicator
            cell.editingAccessoryType = .disclosureIndicator
            cell.accessibilityLabel = appName
            cell.accessibilityValue = appSubtitle
            cell.accessibilityHint = "Double tap to open the App Store page."
            
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
            
            return cell
        }
        
        if indexPath.section == 3 {
            let footerCell = tableView.dequeueReusableCell(withIdentifier: "FooterCell", for: indexPath)
            footerCell.contentView.subviews.forEach { $0.removeFromSuperview() }
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
            
            let font = AppFont.patrick(14, textStyle: .footnote, compatibleWith: traitCollection)
            let color = AppColors.pencil.withAlphaComponent(0.6)
            let symbolHeight = UIFontMetrics(forTextStyle: .footnote).scaledValue(for: 14, compatibleWith: traitCollection)
            let symbolWidth = UIFontMetrics(forTextStyle: .footnote).scaledValue(for: 16, compatibleWith: traitCollection)
            
            let label1 = UILabel()
            label1.text = "Made with "
            label1.font = font
            label1.textColor = color
            label1.isAccessibilityElement = false
            label1.adjustsFontForContentSizeCategory = true
            
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
            label2.adjustsFontForContentSizeCategory = true
            label2.numberOfLines = 0
            label2.textAlignment = .center
            
            line1.addArrangedSubview(label1)
            line1.addArrangedSubview(heart)
            
            stack.addArrangedSubview(line1)
            stack.addArrangedSubview(label2)
            
            let bottomConstraint = stack.bottomAnchor.constraint(equalTo: footerCell.contentView.bottomAnchor, constant: -32)
            bottomConstraint.priority = UILayoutPriority(999)
            
            NSLayoutConstraint.activate([
                heart.heightAnchor.constraint(equalToConstant: symbolHeight),
                heart.widthAnchor.constraint(equalToConstant: symbolWidth),
                stack.centerXAnchor.constraint(equalTo: footerCell.contentView.centerXAnchor),
                stack.leadingAnchor.constraint(greaterThanOrEqualTo: footerCell.contentView.leadingAnchor, constant: 20),
                stack.trailingAnchor.constraint(lessThanOrEqualTo: footerCell.contentView.trailingAnchor, constant: -20),
                stack.topAnchor.constraint(equalTo: footerCell.contentView.topAnchor, constant: 16),
                bottomConstraint
            ])
            return footerCell
        }
        
        // Dequeue standard cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        
        // Reset cell to clean state
        cell.backgroundColor = .clear
        cell.selectionStyle = .default
        cell.textLabel?.font = AppFont.patrick(18, textStyle: .body, compatibleWith: traitCollection)
        cell.detailTextLabel?.font = AppFont.patrick(16, textStyle: .callout, compatibleWith: traitCollection)
        cell.textLabel?.textColor = AppColors.pencil
        cell.detailTextLabel?.textColor = AppColors.pencil.withAlphaComponent(0.6)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        cell.textLabel?.lineBreakMode = .byWordWrapping
        cell.detailTextLabel?.lineBreakMode = .byWordWrapping
        cell.accessibilityHint = nil
        cell.accessoryView = nil
        cell.editingAccessoryView = nil
        cell.accessoryType = .none
        cell.editingAccessoryType = .none
        cell.isAccessibilityElement = true
        cell.accessibilityTraits = .button
        cell.textLabel?.isAccessibilityElement = false
        cell.detailTextLabel?.isAccessibilityElement = false
        cell.imageView?.image = nil
        
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
                let currentTheme = ThemeService.shared.theme
                cell.textLabel?.text = "Appearance"
                cell.detailTextLabel?.text = currentTheme.displayName
                
                let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                let ellipsisImg = UIImage(systemName: "ellipsis", withConfiguration: config)
                let ellipsisView = UIImageView(image: ellipsisImg)
                ellipsisView.tintColor = AppColors.pencil.withAlphaComponent(0.6)
                cell.accessoryView = ellipsisView
                cell.editingAccessoryView = ellipsisView
                
                cell.accessibilityLabel = "Appearance"
                cell.accessibilityValue = currentTheme.displayName
                cell.accessibilityHint = "Double tap to choose the app appearance."
            } else {
                let currentTint = TintService.shared.tintColor
                var currentTeamName: String?
                for team in mlbTeams {
                    let color = TeamColorProvider.color(for: team)
                    if currentTint != nil && currentTint!.isSimilar(to: color) {
                        currentTeamName = team
                        break
                    }
                }
                let tintName = currentTeamName ?? (currentTint == nil ? "Pencil" : "Custom")
                cell.textLabel?.text = "Tint Color"
                cell.detailTextLabel?.text = tintName
                
                let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                let ellipsisImg = UIImage(systemName: "ellipsis", withConfiguration: config)
                let ellipsisView = UIImageView(image: ellipsisImg)
                ellipsisView.tintColor = AppColors.pencil.withAlphaComponent(0.6)
                cell.accessoryView = ellipsisView
                cell.editingAccessoryView = ellipsisView
                
                cell.accessibilityLabel = "Tint color"
                cell.accessibilityValue = tintName
                cell.accessibilityHint = "Double tap to choose the tint color."
            }
            
        case 1:
            if indexPath.row < favoriteTeamIds.count {
                let teamId = favoriteTeamIds[indexPath.row]
                let teamName = favoriteTeamName(for: teamId)
                cell.textLabel?.text = teamName
                cell.detailTextLabel?.text = nil
                
                let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                let ellipsisImg = UIImage(systemName: "ellipsis", withConfiguration: config)
                let ellipsisView = UIImageView(image: ellipsisImg)
                ellipsisView.tintColor = AppColors.pencil.withAlphaComponent(0.6)
                cell.editingAccessoryView = ellipsisView
                
                cell.accessibilityLabel = teamName
                cell.accessibilityValue = "Favorite team"
                cell.accessibilityHint = "Double tap to manage options for this team."
                cell.accessibilityTraits = .button
                cell.showsReorderControl = true
                cell.selectionStyle = .default
            } else {
                let hasAvailableTeams = teamMap.keys.contains { !favoriteTeamIds.contains($0) }
                cell.textLabel?.text = hasAvailableTeams ? "Add Favorite Team" : "All Teams Added"
                cell.detailTextLabel?.text = nil
                cell.accessoryType = hasAvailableTeams ? .disclosureIndicator : .none
                cell.editingAccessoryType = hasAvailableTeams ? .disclosureIndicator : .none
                cell.selectionStyle = hasAvailableTeams ? .default : .none
                cell.accessibilityLabel = hasAvailableTeams ? "Add favorite team" : "All teams added"
                cell.accessibilityHint = hasAvailableTeams ? "Double tap to choose a team to favorite." : nil
                cell.accessibilityTraits = hasAvailableTeams ? .button : .staticText
                cell.showsReorderControl = false
            }
            
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && indexPath.row < favoriteTeamIds.count
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath.section == 1, destinationIndexPath.section == 1,
              sourceIndexPath.row < favoriteTeamIds.count, destinationIndexPath.row < favoriteTeamIds.count else {
            tableView.reloadData()
            return
        }
        
        let movedId = favoriteTeamIds.remove(at: sourceIndexPath.row)
        favoriteTeamIds.insert(movedId, at: destinationIndexPath.row)
        FavoritesService.shared.setFavoriteTeamIds(favoriteTeamIds)
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
        titleLabel.font = AppFont.permanent(16, textStyle: .headline, compatibleWith: traitCollection)
        titleLabel.textColor = AppColors.pencil.withAlphaComponent(0.7)
        titleLabel.isAccessibilityElement = false
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        
        let descLabel = UILabel()
        descLabel.text = "Favorite teams appear first in the schedule."
        descLabel.font = AppFont.patrick(14, textStyle: .footnote, compatibleWith: traitCollection)
        descLabel.textColor = AppColors.pencil.withAlphaComponent(0.5)
        descLabel.isAccessibilityElement = false
        descLabel.adjustsFontForContentSizeCategory = true
        descLabel.numberOfLines = 0
        
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
            header.textLabel?.font = AppFont.permanent(16, textStyle: .headline, compatibleWith: traitCollection)
            header.textLabel?.textColor = AppColors.pencil.withAlphaComponent(0.7)
            header.textLabel?.adjustsFontForContentSizeCategory = true
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && indexPath.row == 0 {
            presentAppearanceSelector()
        } else if indexPath.section == 0 && indexPath.row == 1 {
            presentTintSelector()
        } else if indexPath.section == 1 && indexPath.row < favoriteTeamIds.count {
            presentFavoriteTeamOptions(teamId: favoriteTeamIds[indexPath.row])
        } else if indexPath.section == 1 && indexPath.row == favoriteTeamIds.count
            && teamMap.keys.contains(where: { !favoriteTeamIds.contains($0) }) {
            presentFavoriteTeamSelector()
        } else if indexPath.section == 2 {
            let urlString: String
            if indexPath.row == 0 {
                urlString = "https://apple.co/4qx0GMA"
            } else {
                urlString = "https://apple.co/3NzZ4E7"
            }
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
}

private struct SettingsSelectionOption {
    let title: String
    let isSelected: Bool
    let isDestructive: Bool
    let showToggle: Bool
    let isToggleOn: Bool
    let accessibilityValue: String?
    let displayColor: UIColor?
    let action: () -> Void
    let toggleAction: ((Bool) -> Void)?

    init(
        title: String,
        isSelected: Bool = false,
        isDestructive: Bool = false,
        showToggle: Bool = false,
        isToggleOn: Bool = false,
        accessibilityValue: String? = nil,
        displayColor: UIColor? = nil,
        action: @escaping () -> Void = {},
        toggleAction: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self.isSelected = isSelected
        self.isDestructive = isDestructive
        self.showToggle = showToggle
        self.isToggleOn = isToggleOn
        self.accessibilityValue = accessibilityValue
        self.displayColor = displayColor
        self.action = action
        self.toggleAction = toggleAction
    }
}

private struct SettingsSelectionSection {
    let title: String?
    let options: [SettingsSelectionOption]
}

private final class SettingsSelectionViewController: UITableViewController {
    private let titleText: String
    private let sections: [SettingsSelectionSection]
    private let neutralPencilColor = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.82, green: 0.80, blue: 0.78, alpha: 0.9)
            : UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
    }

    init(titleText: String, sections: [SettingsSelectionSection]) {
        self.titleText = titleText
        self.sections = sections
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = titleText
        view.backgroundColor = AppColors.paper
        tableView.backgroundColor = .clear
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "OptionCell")

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(close)
        )

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: SettingsSelectionViewController, _) in
            self.tableView.reloadData()
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].options.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.font = AppFont.permanent(14, textStyle: .headline, compatibleWith: traitCollection)
            header.textLabel?.textColor = AppColors.pencil.withAlphaComponent(0.7)
            header.textLabel?.adjustsFontForContentSizeCategory = true
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let option = sections[indexPath.section].options[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "OptionCell", for: indexPath)
        cell.backgroundColor = .clear
        cell.textLabel?.text = option.title
        cell.textLabel?.font = AppFont.patrick(18, textStyle: .body, compatibleWith: traitCollection)
        
        let textColor: UIColor
        if option.isDestructive {
            textColor = .systemRed
        } else {
            textColor = option.displayColor ?? neutralPencilColor
        }
        
        cell.textLabel?.textColor = textColor
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        
        if option.showToggle {
            let toggle = UISwitch()
            toggle.isOn = option.isToggleOn
            toggle.onTintColor = AppColors.pencil
            toggle.addAction(UIAction { action in
                if let toggle = action.sender as? UISwitch {
                    option.toggleAction?(toggle.isOn)
                }
            }, for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        } else {
            cell.accessoryType = option.isSelected ? .checkmark : .none
            cell.accessoryView = nil
            cell.selectionStyle = .default
        }
        
        cell.tintColor = textColor
        cell.accessibilityLabel = option.title
        cell.accessibilityValue = option.showToggle ? (option.isToggleOn ? "On" : "Off") : option.accessibilityValue
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let option = sections[indexPath.section].options[indexPath.row]
        if !option.showToggle {
            tableView.deselectRow(at: indexPath, animated: true)
            option.action()
        }
    }
}
private final class SubtitleCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

