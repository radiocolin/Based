import UIKit

final class TintService {
    static let shared = TintService()

    static let tintDidChangeNotification = Notification.Name("TintServiceTintDidChange")

    private let defaults = UserDefaults.standard
    private let key = "based_tint_color_rgba"

    private init() {}

    var tintColor: UIColor? {
        get {
            guard let components = defaults.array(forKey: key) as? [CGFloat],
                  components.count == 4 else { return nil }
            return UIColor(red: components[0], green: components[1],
                           blue: components[2], alpha: components[3])
        }
        set {
            if let color = newValue {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                defaults.set([r, g, b, a], forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
            NotificationCenter.default.post(name: Self.tintDidChangeNotification, object: nil)
        }
    }
}
