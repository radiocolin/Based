import UIKit

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        updateAppearance()
        
        NotificationCenter.default.addObserver(self, selector: #selector(tintDidChange), name: TintService.tintDidChangeNotification, object: nil)
    }
    
    private func setupTabs() {
        let scheduleVC = ScheduleViewController()
        let scheduleNav = UINavigationController(rootViewController: scheduleVC)
        
        let settingsVC = SettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        
        viewControllers = [scheduleNav, settingsNav]
        updateTabIcons()
    }
    
    @objc private func tintDidChange() {
        updateTabIcons()
        updateAppearance()
    }
    
    private func updateTabIcons() {
        guard let vcs = viewControllers, vcs.count >= 2 else { return }
        
        let baseballImg = UIImage.pencilStyledIcon(named: "baseball", color: AppColors.pencil, size: CGSize(width: 30, height: 30))
        let gearImg = UIImage.pencilStyledIcon(named: "gear", color: AppColors.pencil, size: CGSize(width: 30, height: 30))
        
        vcs[0].tabBarItem = UITabBarItem(title: "Games", image: baseballImg, selectedImage: nil)
        vcs[1].tabBarItem = UITabBarItem(title: "Settings", image: gearImg, selectedImage: nil)
    }
    
    private func updateAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.paper
        
        let font = UIFont(name: "PatrickHand-Regular", size: 12) ?? .systemFont(ofSize: 12)
        let pencilColor = AppColors.pencil
        
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .font: font, 
            .foregroundColor: pencilColor.withAlphaComponent(0.6)
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .font: font, 
            .foregroundColor: pencilColor
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = pencilColor.withAlphaComponent(0.6)
        appearance.stackedLayoutAppearance.selected.iconColor = pencilColor
        
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = pencilColor
    }
}
