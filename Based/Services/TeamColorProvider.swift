import UIKit

struct TeamColorProvider {
    static func color(for teamName: String) -> UIColor {
        let map: [String: UIColor] = [
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
        return map[teamName] ?? UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
    }
}
