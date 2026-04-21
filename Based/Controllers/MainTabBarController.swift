import UIKit

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        updateAppearance()
        
        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: MainTabBarController, _) in
            self.updateTabIcons()
            self.updateAppearance()
        }
    }
    
    private func setupTabs() {
        let scheduleVC = ScheduleViewController()
        let scheduleNav = UINavigationController(rootViewController: scheduleVC)
        
        let teamsVC = TeamsViewController(style: .plain)
        let teamsNav = UINavigationController(rootViewController: teamsVC)
        
        let settingsVC = SettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        
        viewControllers = [scheduleNav, teamsNav, settingsNav]
        updateTabIcons()
    }
    
    @objc private func tintDidChange() {
        updateTabIcons()
        updateAppearance()
    }
    
    private func updateTabIcons() {
        guard let vcs = viewControllers, vcs.count >= 3 else { return }
        
        let category = traitCollection.preferredContentSizeCategory
        let iconSide: CGFloat
        if category.isAccessibilityCategory {
            iconSide = 38
        } else if category == .extraExtraExtraLarge || category == .extraExtraLarge {
            iconSide = 34
        } else {
            iconSide = 30
        }
        let iconSize = CGSize(width: iconSide, height: iconSide)
        
        let baseballImg = UIImage.pencilStyledIcon(named: "baseball", color: AppColors.pencil, size: iconSize)
        let teamsImg = UIImage.pencilStyledIcon(named: "figure.baseball", color: AppColors.pencil, size: iconSize)
        let gearImg = UIImage.pencilStyledIcon(named: "gear", color: AppColors.pencil, size: iconSize)
        
        vcs[0].tabBarItem = UITabBarItem(title: "Games", image: baseballImg, selectedImage: nil)
        vcs[1].tabBarItem = UITabBarItem(title: "Teams", image: teamsImg, selectedImage: nil)
        vcs[2].tabBarItem = UITabBarItem(title: "Settings", image: gearImg, selectedImage: nil)
    }
    
    private func updateAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.paper
        
        let font = AppFont.patrick(12, textStyle: .caption2, compatibleWith: traitCollection)
        let pencilColor = AppColors.pencil

        for itemAppearance in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            itemAppearance.normal.titleTextAttributes = [
                .font: font,
                .foregroundColor: pencilColor.withAlphaComponent(0.6)
            ]
            itemAppearance.selected.titleTextAttributes = [
                .font: font,
                .foregroundColor: pencilColor
            ]
            itemAppearance.normal.iconColor = pencilColor.withAlphaComponent(0.6)
            itemAppearance.selected.iconColor = pencilColor
        }
        
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = pencilColor
    }
}
