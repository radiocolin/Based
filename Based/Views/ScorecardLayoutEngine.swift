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
    
    func computeCompactColumnLayout(data: ScorecardData?, isHomeTeam: Bool) -> CompactColumnLayout {
        guard let data = data else {
            let innings = (1...3).map { InningColumnLayout(inningNum: $0, subColumnCount: 1, startColumn: $0 - 1) }
            return CompactColumnLayout(columns: [], columnLayout: ColumnLayout(innings: innings))
        }

        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        let inningCount = max(data.innings.count, 9)

        var allEvents: [(event: AtBatEvent, inning: Int)] = []
        for i in 1...inningCount {
            let events = data.events(inningNum: i, isHomeBatting: isHomeTeam)
            for event in events {
                allEvents.append((event, i))
            }
        }

        var paIndexBySlot: [Int: Int] = [:]
        for batter in lineup {
            guard let slot = batter.battingOrderSlot else { continue }
            paIndexBySlot[slot] = 0
        }

        let compactEventsBySlot = compactPlateAppearancesBySlot(data: data, lineup: lineup, isHomeTeam: isHomeTeam)
        let maxPAs = compactEventsBySlot.values.map(\.count).max() ?? 1
        let columnCount = max(maxPAs, 1)

        var columnInnings: [[Int]] = Array(repeating: [], count: columnCount)
        var columnLeadoffs: [Int?] = Array(repeating: nil, count: columnCount)
        let batterIndexByID = Dictionary(uniqueKeysWithValues: lineup.enumerated().map { ($1.id, $0) })
        let slotByBatterID = Dictionary(uniqueKeysWithValues: lineup.compactMap { batter in
            batter.battingOrderSlot.map { (batter.id, $0) }
        })

        for (event, inning) in allEvents {
            let batterId = event.batterId
            guard
                let batterIdx = batterIndexByID[batterId],
                let slot = slotByBatterID[batterId]
            else { continue }
            let pa = paIndexBySlot[slot] ?? 0
            guard pa < columnCount else { continue }

            if columnLeadoffs[pa] == nil {
                columnLeadoffs[pa] = batterIdx
            }
            if !columnInnings[pa].contains(inning) {
                columnInnings[pa].append(inning)
            }
            paIndexBySlot[slot] = pa + 1
        }

        var compactColumns: [CompactColumn] = []
        var layouts: [InningColumnLayout] = []
        for i in 0..<columnCount {
            let sorted = columnInnings[i].sorted()
            let start = sorted.first ?? (i + 1)
            let end = sorted.last ?? (i + 1)
            compactColumns.append(CompactColumn(index: i, inningStart: start, inningEnd: end, leadoffLineupIndex: columnLeadoffs[i] ?? 0))
            layouts.append(InningColumnLayout(inningNum: i + 1, subColumnCount: 1, startColumn: i))
        }

        return CompactColumnLayout(columns: compactColumns, columnLayout: ColumnLayout(innings: layouts))
    }

    func compactPlateAppearancesBySlot(data: ScorecardData, lineup: [ScorecardBatter], isHomeTeam: Bool) -> [Int: [Int: AtBatEvent]] {
        let inningCount = max(data.innings.count, 9)
        let slotByBatterID = Dictionary(uniqueKeysWithValues: lineup.compactMap { batter in
            batter.battingOrderSlot.map { (batter.id, $0) }
        })
        var paIndexBySlot: [Int: Int] = [:]
        for batter in lineup {
            guard let slot = batter.battingOrderSlot else { continue }
            paIndexBySlot[slot] = 0
        }

        var eventsBySlot: [Int: [Int: AtBatEvent]] = [:]
        for inning in 1...inningCount {
            let events = data.events(inningNum: inning, isHomeBatting: isHomeTeam)
            for event in events {
                let batterId = event.batterId
                guard let slot = slotByBatterID[batterId] else { continue }
                let paIndex = paIndexBySlot[slot] ?? 0
                eventsBySlot[slot, default: [:]][paIndex] = event
                paIndexBySlot[slot] = paIndex + 1
            }
        }
        return eventsBySlot
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
