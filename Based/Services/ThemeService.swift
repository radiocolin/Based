import UIKit

final class ThemeService {
    static let shared = ThemeService()
    static let themeDidChangeNotification = Notification.Name("ThemeServiceThemeDidChange")
    
    enum Theme: String, CaseIterable {
        case system
        case light
        case dark
        
        var userInterfaceStyle: UIUserInterfaceStyle {
            switch self {
            case .system: return .unspecified
            case .light: return .light
            case .dark: return .dark
            }
        }
        
        var displayName: String {
            rawValue.capitalized
        }
    }
    
    private let key = "based_user_theme"
    
    var theme: Theme {
        get {
            if let string = UserDefaults.standard.string(forKey: key),
               let theme = Theme(rawValue: string) {
                return theme
            }
            return .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            applyTheme()
            NotificationCenter.default.post(name: Self.themeDidChangeNotification, object: nil)
        }
    }
    
    private init() {}
    
    func applyTheme() {
        let style = theme.userInterfaceStyle
        Task { @MainActor in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { $0.overrideUserInterfaceStyle = style }
            }
        }
    }
}
