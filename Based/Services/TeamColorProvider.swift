import UIKit

struct TeamColorProvider {
    private static let teamColors: [String: UIColor] = [
        "Arizona Diamondbacks": UIColor(red: 0.65, green: 0.12, blue: 0.21, alpha: 1.0),
        "Atlanta Braves": UIColor(red: 0.75, green: 0.04, blue: 0.18, alpha: 1.0),
        "Baltimore Orioles": UIColor(red: 0.88, green: 0.29, blue: 0.13, alpha: 1.0),
        "Boston Red Sox": UIColor(red: 0.74, green: 0.03, blue: 0.15, alpha: 1.0),
        "Chicago Cubs": UIColor(red: 0.04, green: 0.31, blue: 0.64, alpha: 1.0),
        // Use UI-safe, team-representative accents instead of literal near-black primaries.
        "Chicago White Sox": UIColor(red: 0.52, green: 0.54, blue: 0.56, alpha: 1.0),
        "Cincinnati Reds": UIColor(red: 0.78, green: 0.0, blue: 0.13, alpha: 1.0),
        "Cleveland Guardians": UIColor(red: 0.12, green: 0.25, blue: 0.43, alpha: 1.0),
        "Colorado Rockies": UIColor(red: 0.42, green: 0.29, blue: 0.63, alpha: 1.0),
        "Detroit Tigers": UIColor(red: 0.09, green: 0.28, blue: 0.49, alpha: 1.0),
        "Houston Astros": UIColor(red: 0.06, green: 0.25, blue: 0.47, alpha: 1.0),
        "Kansas City Royals": UIColor(red: 0.0, green: 0.29, blue: 0.57, alpha: 1.0),
        "Los Angeles Angels": UIColor(red: 0.73, green: 0.0, blue: 0.13, alpha: 1.0),
        "Los Angeles Dodgers": UIColor(red: 0.0, green: 0.35, blue: 0.67, alpha: 1.0),
        "Miami Marlins": UIColor(red: 0.0, green: 0.66, blue: 0.82, alpha: 1.0),
        "Milwaukee Brewers": UIColor(red: 0.13, green: 0.25, blue: 0.47, alpha: 1.0),
        "Minnesota Twins": UIColor(red: 0.07, green: 0.24, blue: 0.45, alpha: 1.0),
        "New York Mets": UIColor(red: 0.04, green: 0.27, blue: 0.56, alpha: 1.0),
        "New York Yankees": UIColor(red: 0.12, green: 0.27, blue: 0.47, alpha: 1.0),
        "Oakland Athletics": UIColor(red: 0.0, green: 0.40, blue: 0.29, alpha: 1.0),
        "Philadelphia Phillies": UIColor(red: 0.75, green: 0.03, blue: 0.15, alpha: 1.0),
        "Pittsburgh Pirates": UIColor(red: 0.82, green: 0.62, blue: 0.12, alpha: 1.0),
        "San Diego Padres": UIColor(red: 0.49, green: 0.34, blue: 0.22, alpha: 1.0),
        "San Francisco Giants": UIColor(red: 0.99, green: 0.31, blue: 0.13, alpha: 1.0),
        "Seattle Mariners": UIColor(red: 0.0, green: 0.36, blue: 0.45, alpha: 1.0),
        "St. Louis Cardinals": UIColor(red: 0.77, green: 0.03, blue: 0.15, alpha: 1.0),
        "Tampa Bay Rays": UIColor(red: 0.10, green: 0.29, blue: 0.54, alpha: 1.0),
        "Texas Rangers": UIColor(red: 0.04, green: 0.30, blue: 0.60, alpha: 1.0),
        "Toronto Blue Jays": UIColor(red: 0.05, green: 0.31, blue: 0.62, alpha: 1.0),
        "Washington Nationals": UIColor(red: 0.67, green: 0.04, blue: 0.16, alpha: 1.0),
    ]

    // A few teams still need stronger dark-mode lifts than the shared algorithm provides.
    private static let darkOverrides: [String: UIColor] = [
        "Chicago White Sox": UIColor(red: 0.76, green: 0.78, blue: 0.80, alpha: 1.0),
        "Pittsburgh Pirates": UIColor(red: 0.95, green: 0.82, blue: 0.24, alpha: 1.0),
        "San Diego Padres": UIColor(red: 0.73, green: 0.56, blue: 0.40, alpha: 1.0),
    ]

    static func color(for teamName: String) -> UIColor {
        UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                if let override = darkOverrides[teamName] { return override }
                let base = teamColors[teamName] ?? AppColors.pencil
                return boostedForDarkBackground(base)
            }
            return teamColors[teamName] ?? AppColors.pencil
        }
    }

    /// Increases brightness and, if needed, reduces saturation until the color
    /// meets a 4.5:1 WCAG contrast ratio against the dark paper background.
    private static func boostedForDarkBackground(_ color: UIColor, minRatio: CGFloat = 4.5) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        let darkBG = AppColors.paper.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        var bgR: CGFloat = 0, bgG: CGFloat = 0, bgB: CGFloat = 0
        darkBG.getRed(&bgR, green: &bgG, blue: &bgB, alpha: nil)
        let bgLum = relativeLuminance(bgR, bgG, bgB)

        func contrastRatio(hue: CGFloat, sat: CGFloat, bri: CGFloat) -> CGFloat {
            let candidate = UIColor(hue: hue, saturation: sat, brightness: bri, alpha: a)
            var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0
            candidate.getRed(&r, green: &g, blue: &bl, alpha: nil)
            let fgLum = relativeLuminance(r, g, bl)
            return (max(fgLum, bgLum) + 0.05) / (min(fgLum, bgLum) + 0.05)
        }

        // Phase 1: Increase brightness, keeping saturation vivid (min 0.6)
        let targetS = max(s, 0.6)
        var curB = b
        while curB <= 1.0 {
            if contrastRatio(hue: h, sat: targetS, bri: curB) >= minRatio {
                return UIColor(hue: h, saturation: targetS, brightness: curB, alpha: a)
            }
            curB += 0.02
        }

        // Phase 2: At max brightness, reduce saturation until contrast met
        var curS = targetS
        while curS >= 0.3 {
            if contrastRatio(hue: h, sat: curS, bri: 1.0) >= minRatio {
                return UIColor(hue: h, saturation: curS, brightness: 1.0, alpha: a)
            }
            curS -= 0.02
        }

        return UIColor(hue: h, saturation: 0.3, brightness: 1.0, alpha: a)
    }

    // MARK: - WCAG Relative Luminance

    private static func sRGBLinear(_ c: CGFloat) -> CGFloat {
        c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func relativeLuminance(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGFloat {
        0.2126 * sRGBLinear(r) + 0.7152 * sRGBLinear(g) + 0.0722 * sRGBLinear(b)
    }
}
