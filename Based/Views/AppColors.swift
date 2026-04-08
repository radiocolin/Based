import UIKit

enum AppColors {
    /// Warm off-white paper background (dark: charcoal)
    static let paper = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
            : UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)
    }

    /// Main pencil stroke / text color — tint-aware
    static var pencil: UIColor { UIColor { tc in
        let isDark = tc.userInterfaceStyle == .dark
        if let tint = TintService.shared.tintColor {
            return adjustedPencil(tint: tint, isDark: isDark)
        }
        return isDark
            ? UIColor(red: 0.82, green: 0.80, blue: 0.78, alpha: 0.9)
            : UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
    }}

    /// Header / section tint background — tint-aware
    static var header: UIColor { UIColor { tc in
        let isDark = tc.userInterfaceStyle == .dark
        if let tint = TintService.shared.tintColor {
            return tintedBackground(tint: tint, isDark: isDark, mixAmount: 0.08)
        }
        return isDark
            ? UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1.0)
            : UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1.0)
    }}

    /// Selected / pressed state background — tint-aware
    static var selected: UIColor { UIColor { tc in
        let isDark = tc.userInterfaceStyle == .dark
        if let tint = TintService.shared.tintColor {
            return tintedBackground(tint: tint, isDark: isDark, mixAmount: 0.12)
        }
        return isDark
            ? UIColor(red: 0.20, green: 0.20, blue: 0.21, alpha: 1.0)
            : UIColor(red: 0.93, green: 0.92, blue: 0.90, alpha: 1.0)
    }}

    /// Thin grid / border lines — tint-aware
    static var grid: UIColor { UIColor { tc in
        let isDark = tc.userInterfaceStyle == .dark
        if let tint = TintService.shared.tintColor {
            return adjustedPencil(tint: tint, isDark: isDark).withAlphaComponent(0.25)
        }
        return isDark
            ? UIColor(white: 0.35, alpha: 0.5)
            : UIColor(white: 0.6, alpha: 0.5)
    }}

    /// Alternating row tint — tint-aware
    static var alternateRow: UIColor { UIColor { tc in
        let isDark = tc.userInterfaceStyle == .dark
        if let tint = TintService.shared.tintColor {
            return tintedBackground(tint: tint, isDark: isDark, mixAmount: 0.05)
                .withAlphaComponent(0.3)
        }
        return isDark
            ? UIColor(white: 0.18, alpha: 0.3)
            : UIColor(red: 0.95, green: 0.95, blue: 0.9, alpha: 0.3)
    }}

    /// Inactive / unavailable cell overlay
    static var inactive: UIColor { UIColor { tc in
        let isDark = tc.userInterfaceStyle == .dark
        if let tint = TintService.shared.tintColor {
            return tintedBackground(tint: tint, isDark: isDark, mixAmount: 0.15)
        }
        return isDark
            ? UIColor(white: 0.2, alpha: 0.8)
            : UIColor(white: 0.85, alpha: 0.8)
    }}

    /// Diamond infield fill
    static let diamondFill = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.2, alpha: 1.0)
            : UIColor(white: 0.9, alpha: 1.0)
    }

    /// Empty base box fill
    static let baseEmpty = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.15, alpha: 0.6)
            : UIColor.white.withAlphaComponent(0.6)
    }

    /// Strike zone fill
    static let zoneFill = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.2, alpha: 0.5)
            : UIColor(white: 0.9, alpha: 0.5)
    }

    /// Base-running line stroke — tint-aware
    static var lineStroke: UIColor { UIColor { tc in
        let isDark = tc.userInterfaceStyle == .dark
        if let tint = TintService.shared.tintColor {
            return adjustedPencil(tint: tint, isDark: isDark).withAlphaComponent(0.8)
        }
        return isDark
            ? UIColor(white: 0.85, alpha: 0.8)
            : UIColor(white: 0.1, alpha: 0.8)
    }}

    /// Advisory banner background
    static let advisoryBackground = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.25, green: 0.1, blue: 0.1, alpha: 1.0)
            : UIColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 1.0)
    }

    // MARK: - Tint Helpers

    private static func adjustedPencil(tint: UIColor, isDark: Bool) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        tint.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if isDark {
            return UIColor(hue: h, saturation: min(s, 0.65), brightness: max(b, 0.78), alpha: 0.9)
        } else {
            return UIColor(hue: h, saturation: max(s, 0.7), brightness: min(b, 0.55), alpha: 0.9)
        }
    }

    private static func tintedBackground(tint: UIColor, isDark: Bool, mixAmount: CGFloat) -> UIColor {
        var tH: CGFloat = 0, tS: CGFloat = 0, tB: CGFloat = 0, tA: CGFloat = 0
        tint.getHue(&tH, saturation: &tS, brightness: &tB, alpha: &tA)
        if isDark {
            let base = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
            let accent = UIColor(hue: tH, saturation: 0.3, brightness: 0.25, alpha: 1.0)
            return blend(base: base, accent: accent, amount: mixAmount)
        } else {
            let base = UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1.0)
            let accent = UIColor(hue: tH, saturation: 0.15, brightness: 0.95, alpha: 1.0)
            return blend(base: base, accent: accent, amount: mixAmount)
        }
    }

    private static func blend(base: UIColor, accent: UIColor, amount: CGFloat) -> UIColor {
        var bR: CGFloat = 0, bG: CGFloat = 0, bB: CGFloat = 0, bA: CGFloat = 0
        var aR: CGFloat = 0, aG: CGFloat = 0, aB: CGFloat = 0, aA: CGFloat = 0
        base.getRed(&bR, green: &bG, blue: &bB, alpha: &bA)
        accent.getRed(&aR, green: &aG, blue: &aB, alpha: &aA)
        return UIColor(
            red: bR + (aR - bR) * amount,
            green: bG + (aG - bG) * amount,
            blue: bB + (aB - bB) * amount,
            alpha: bA + (aA - bA) * amount
        )
    }
}
