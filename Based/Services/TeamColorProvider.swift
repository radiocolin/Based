import UIKit

struct TeamColorProvider {
    private static let teamColors: [String: UIColor] = [
        "Arizona Diamondbacks": UIColor(red: 0.65, green: 0.12, blue: 0.21, alpha: 1.0),
        "Atlanta Braves": UIColor(red: 0.75, green: 0.04, blue: 0.18, alpha: 1.0),
        "Baltimore Orioles": UIColor(red: 0.88, green: 0.29, blue: 0.13, alpha: 1.0),
        "Boston Red Sox": UIColor(red: 0.74, green: 0.03, blue: 0.15, alpha: 1.0),
        "Chicago Cubs": UIColor(red: 0.04, green: 0.31, blue: 0.64, alpha: 1.0),
        "Chicago White Sox": UIColor(red: 0.15, green: 0.16, blue: 0.16, alpha: 1.0),
        "Cincinnati Reds": UIColor(red: 0.78, green: 0.0, blue: 0.13, alpha: 1.0),
        "Cleveland Guardians": UIColor(red: 0.02, green: 0.13, blue: 0.26, alpha: 1.0),
        "Colorado Rockies": UIColor(red: 0.2, green: 0.11, blue: 0.44, alpha: 1.0),
        "Detroit Tigers": UIColor(red: 0.05, green: 0.11, blue: 0.23, alpha: 1.0),
        "Houston Astros": UIColor(red: 0.0, green: 0.13, blue: 0.28, alpha: 1.0),
        "Kansas City Royals": UIColor(red: 0.0, green: 0.29, blue: 0.57, alpha: 1.0),
        "Los Angeles Angels": UIColor(red: 0.73, green: 0.0, blue: 0.13, alpha: 1.0),
        "Los Angeles Dodgers": UIColor(red: 0.0, green: 0.35, blue: 0.67, alpha: 1.0),
        "Miami Marlins": UIColor(red: 0.0, green: 0.66, blue: 0.82, alpha: 1.0),
        "Milwaukee Brewers": UIColor(red: 0.07, green: 0.13, blue: 0.26, alpha: 1.0),
        "Minnesota Twins": UIColor(red: 0.0, green: 0.16, blue: 0.35, alpha: 1.0),
        "New York Mets": UIColor(red: 0.0, green: 0.18, blue: 0.44, alpha: 1.0),
        "New York Yankees": UIColor(red: 0.05, green: 0.11, blue: 0.23, alpha: 1.0),
        "Oakland Athletics": UIColor(red: 0.0, green: 0.24, blue: 0.19, alpha: 1.0),
        "Philadelphia Phillies": UIColor(red: 0.75, green: 0.03, blue: 0.15, alpha: 1.0),
        "Pittsburgh Pirates": UIColor(red: 0.15, green: 0.16, blue: 0.16, alpha: 1.0),
        "San Diego Padres": UIColor(red: 0.18, green: 0.13, blue: 0.1, alpha: 1.0),
        "San Francisco Giants": UIColor(red: 0.99, green: 0.31, blue: 0.13, alpha: 1.0),
        "Seattle Mariners": UIColor(red: 0.05, green: 0.18, blue: 0.33, alpha: 1.0),
        "St. Louis Cardinals": UIColor(red: 0.77, green: 0.03, blue: 0.15, alpha: 1.0),
        "Tampa Bay Rays": UIColor(red: 0.04, green: 0.18, blue: 0.38, alpha: 1.0),
        "Texas Rangers": UIColor(red: 0.0, green: 0.2, blue: 0.46, alpha: 1.0),
        "Toronto Blue Jays": UIColor(red: 0.05, green: 0.31, blue: 0.62, alpha: 1.0),
        "Washington Nationals": UIColor(red: 0.67, green: 0.04, blue: 0.16, alpha: 1.0),
    ]

    // Near-black teams need a completely different color in dark mode
    private static let darkOverrides: [String: UIColor] = [
        "Chicago White Sox": UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0),
        "Pittsburgh Pirates": UIColor(red: 0.92, green: 0.78, blue: 0.2, alpha: 1.0),
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
