import UIKit

class ScorecardLayoutEngine {
    private let inningWidth: CGFloat = 56
    private let statWidth: CGFloat = 38
    private let rowHeight: CGFloat = 64
    
    func computeColumnLayout(data: ScorecardData?, isHomeTeam: Bool) -> ColumnLayout {
        guard let data = data else {
            let innings = (1...9).map { InningColumnLayout(inningNum: $0, subColumnCount: 1, startColumn: $0 - 1) }
            return ColumnLayout(innings: innings)
        }
        
        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        let inningCount = max(data.innings.count, 9)
        var layouts: [InningColumnLayout] = []
        var runningColumn = 0
        
        for i in 1...inningCount {
            let events = data.events(inningNum: i, isHomeBatting: isHomeTeam)
            
            // Count max at-bats for any single batter in this inning half
            var maxABs = 1
            for batter in lineup {
                let count = events.filter { $0.batterId == batter.id }.count
                maxABs = max(maxABs, count)
            }
            
            layouts.append(InningColumnLayout(inningNum: i, subColumnCount: maxABs, startColumn: runningColumn))
            runningColumn += maxABs
        }
        
        return ColumnLayout(innings: layouts)
    }
    
    func computeNameWidth(data: ScorecardData?, isHomeTeam: Bool) -> CGFloat {
        guard let data = data else { return 90 }
        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        
        let nameFont = UIFont(name: AppFont.patrickHand, size: 18) ?? .systemFont(ofSize: 18)
        let posFont = UIFont(name: AppFont.patrickHand, size: 14) ?? .systemFont(ofSize: 14)
        
        var maxWidth: CGFloat = 40 // minimum
        for batter in lineup {
            let nameSize = (batter.abbreviation as NSString).size(withAttributes: [.font: nameFont])
            var posText = batter.position
            if let num = batter.jerseyNumber { posText += " #\(num)" }
            if let entry = batter.inningEntered { posText += " (\(entry))" }
            let posSize = (posText as NSString).size(withAttributes: [.font: posFont])
            maxWidth = max(maxWidth, max(nameSize.width, posSize.width))
        }
        
        // Add padding (6pt each side in cell + 4pt extra breathing room)
        return ceil(maxWidth + 20)
    }
    
    func mergedWidth(columnLayout: ColumnLayout, fromInning startInning: Int, toInning endInning: Int) -> CGFloat {
        guard startInning <= endInning else { return 0 }
        var totalWidth: CGFloat = 0
        for i in startInning...endInning {
            if let layout = columnLayout.layout(forInning: i) {
                totalWidth += inningWidth * CGFloat(layout.subColumnCount)
            }
        }
        return totalWidth
    }
    
    func calculateContentWidth(columnLayout: ColumnLayout) -> CGFloat {
        let inningsWidth = inningWidth * CGFloat(columnLayout.innings.map { $0.subColumnCount }.reduce(0, +))
        let statsWidthTotal = statWidth * CGFloat(columnLayout.statColumns.count)
        return inningsWidth + statsWidthTotal
    }
}
