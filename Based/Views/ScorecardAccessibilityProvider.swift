import UIKit

class ScorecardAccessibilityProvider {
    func spokenPosition(for batter: ScorecardBatter) -> String {
        var parts = [AccessibilitySupport.positionDescription(batter.position)]
        if let jerseyNumber = batter.jerseyNumber {
            parts.append("number \(jerseyNumber)")
        }
        if let inningEntered = batter.inningEntered, inningEntered > 1 {
            parts.append("entered in the \(AccessibilitySupport.ordinal(inningEntered))")
        }
        if let inningExited = batter.inningExited {
            parts.append("left in the \(AccessibilitySupport.ordinal(inningExited))")
        }
        return parts.joined(separator: ", ")
    }

    func nameAccessibilityLabel(for batter: ScorecardBatter, rowIndex: Int, totalRows: Int) -> String {
        AccessibilitySupport.joined([
            "Batter row \(rowIndex + 1) of \(totalRows)",
            batter.fullName,
            spokenPosition(for: batter)
        ])
    }

    func statAccessibilityLabel(statType: String, value: String, batter: ScorecardBatter?, rowIndex: Int, totalRows: Int, isTotalsRow: Bool) -> String {
        let prefix = isTotalsRow ? "Totals row" : "Batter row \(rowIndex + 1) of \(totalRows)"
        let subject = batter?.fullName
        let statName = AccessibilitySupport.statName(for: statType)
        return AccessibilitySupport.joined([
            prefix,
            subject,
            "\(statName): \(value)"
        ])
    }

    func inningAccessibilityLabel(
        for event: AtBatEvent?,
        batter: ScorecardBatter,
        inningNum: Int,
        subIndex: Int,
        totalSubColumns: Int,
        rowIndex: Int,
        totalRows: Int,
        isCurrentCell: Bool,
        isBeforeEntry: Bool,
        isAfterExit: Bool
    ) -> String {
        let location = "Batter row \(rowIndex + 1) of \(totalRows), \(batter.fullName), inning \(inningNum), plate appearance \(subIndex + 1) of \(totalSubColumns)"
        if isBeforeEntry {
            return "\(location). Did not enter the game yet."
        }
        if isAfterExit {
            return "\(location). No longer in the game."
        }
        guard let event else {
            return "\(location). No plate appearance recorded."
        }
        let currentText = isCurrentCell ? "Current at bat. " : ""
        return currentText + AccessibilitySupport.eventDescription(event)
    }

    func inningTotalsAccessibilityLabel(inningNum: Int, runs: Int) -> String {
        let runWord = runs == 1 ? "run" : "runs"
        return "Totals row, inning \(inningNum), \(runs) \(runWord)"
    }
}
