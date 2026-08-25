import UIKit

class ScorecardViewDataSource: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    weak var delegate: ScorecardViewDelegate?
    var scorecardData: ScorecardData?
    var isHomeTeam = false
    var isLive = false
    var isCompact = false
    var columnLayout: ColumnLayout
    var compactColumns: [CompactColumn] = []
    var nameWidth: CGFloat = 90
    
    private let layoutEngine: ScorecardLayoutEngine
    private let accessibilityProvider: ScorecardAccessibilityProvider
    
    private let inningWidth: CGFloat = 56
    private let statWidth: CGFloat = 38
    private let rowHeight: CGFloat = 64
    
    var horizontalScrollCallback: ((CGFloat) -> Void)?
    
    init(columnLayout: ColumnLayout, layoutEngine: ScorecardLayoutEngine, accessibilityProvider: ScorecardAccessibilityProvider) {
        self.columnLayout = columnLayout
        self.layoutEngine = layoutEngine
        self.accessibilityProvider = accessibilityProvider
        super.init()
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let data = scorecardData else { return 0 }
        let lineupCount = (isHomeTeam ? data.lineups.home.count : data.lineups.away.count) + 1 // +1 for totals
        
        let leftCollectionView = (collectionView.superview as? ScorecardView)?.leftCollectionView
        return collectionView == leftCollectionView ? lineupCount : lineupCount * columnLayout.totalColumns
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let data = scorecardData else { return UICollectionViewCell() }
        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        let totalCols = columnLayout.totalColumns
        
        let scorecardView = collectionView.superview as? ScorecardView
        let leftCollectionView = scorecardView?.leftCollectionView
        
        let rowIndex = (collectionView == leftCollectionView) ? indexPath.item : indexPath.item / totalCols
        let totalRows = lineup.count
        let isTotalsRow = rowIndex == lineup.count
        let rowBackgroundColor = rowIndex % 2 == 0 ? UIColor.clear : AppColors.alternateRow

        if collectionView == leftCollectionView {
            return configureNameCell(collectionView, indexPath: indexPath, data: data, lineup: lineup, rowIndex: rowIndex, totalRows: totalRows, isTotalsRow: isTotalsRow, rowBackgroundColor: rowBackgroundColor)
        }

        let col = indexPath.item % totalCols

        if let statType = columnLayout.statInfo(forColumn: col) {
            return configureStatCell(collectionView, indexPath: indexPath, data: data, lineup: lineup, statType: statType, rowIndex: rowIndex, totalRows: totalRows, isTotalsRow: isTotalsRow, rowBackgroundColor: rowBackgroundColor)
        }

        if isCompact {
            if isTotalsRow {
                return configureCompactTotalsCell(collectionView, indexPath: indexPath, data: data, col: col)
            }
            return configureCompactCell(collectionView, indexPath: indexPath, data: data, lineup: lineup, batter: lineup[rowIndex], col: col, rowIndex: rowIndex, totalRows: totalRows, rowBackgroundColor: rowBackgroundColor)
        }

        if isTotalsRow {
            return configureTotalsInningCell(collectionView, indexPath: indexPath, data: data, col: col)
        }

        return configureInningCell(collectionView, indexPath: indexPath, data: data, lineup: lineup, batter: lineup[rowIndex], col: col, rowIndex: rowIndex, totalRows: totalRows, rowBackgroundColor: rowBackgroundColor)
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let leftCollectionView = (collectionView.superview as? ScorecardView)?.leftCollectionView
        
        if collectionView == leftCollectionView {
            return CGSize(width: nameWidth, height: rowHeight)
        } else {
            let totalCols = columnLayout.totalColumns
            let col = indexPath.item % totalCols
            
            let rowIndex = indexPath.item / totalCols
            guard let data = scorecardData else { return .zero }
            let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
            let isTotalsRow = rowIndex == lineup.count
            
            if isCompact {
                let width = columnLayout.statInfo(forColumn: col) != nil ? statWidth : inningWidth
                return CGSize(width: width, height: rowHeight)
            }

            if isTotalsRow {
                if let (inningNum, subIndex) = columnLayout.inningInfo(forColumn: col) {
                    if let inningLayout = columnLayout.layout(forInning: inningNum), inningLayout.subColumnCount > 1 {
                        if subIndex == 0 {
                            return CGSize(width: inningWidth * CGFloat(inningLayout.subColumnCount), height: rowHeight)
                        } else {
                            return CGSize(width: 0, height: rowHeight)
                        }
                    }
                }
            } else {
                let batter = lineup[rowIndex]
                if let (inningNum, subIndex) = columnLayout.inningInfo(forColumn: col) {
                    let isBeforeEntry = inningNum < (batter.inningEntered ?? 1)
                    let exitInning = batter.inningExited ?? 99
                    let isAfterExit = inningNum > exitInning
                    
                    if isBeforeEntry {
                        if inningNum == 1 && subIndex == 0 {
                            return CGSize(width: layoutEngine.mergedWidth(columnLayout: columnLayout, fromInning: 1, toInning: (batter.inningEntered ?? 1) - 1), height: rowHeight)
                        } else {
                            return CGSize(width: 0, height: rowHeight)
                        }
                    } else if isAfterExit {
                        if inningNum == exitInning + 1 && subIndex == 0 {
                            let maxInning = columnLayout.innings.last?.inningNum ?? 9
                            return CGSize(width: layoutEngine.mergedWidth(columnLayout: columnLayout, fromInning: exitInning + 1, toInning: maxInning), height: rowHeight)
                        } else {
                            return CGSize(width: 0, height: rowHeight)
                        }
                    }
                }
            }
            
            let width = columnLayout.statInfo(forColumn: col) != nil ? statWidth : inningWidth
            return CGSize(width: width, height: rowHeight)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let data = scorecardData else { return }
        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        let totalCols = columnLayout.totalColumns
        
        let leftCollectionView = (collectionView.superview as? ScorecardView)?.leftCollectionView
        
        let rowIndex = (collectionView == leftCollectionView) ? indexPath.item : indexPath.item / totalCols
        if rowIndex >= lineup.count { return } // Totals row not selectable
        let batter = lineup[rowIndex]
        
        if collectionView == leftCollectionView {
            delegate?.didSelectPlayer(batter)
        } else if isCompact {
            let col = indexPath.item % totalCols
            guard columnLayout.inningInfo(forColumn: col) != nil else { return }
            let paIndex = col
            let allPAs = compactPAsByColumn(for: batter, data: data, lineup: lineup)
            
            let isCurrentBatter = data.currentBatterId == batter.id
            let isCurrentHalf = data.isTopInning == !isHomeTeam
            let event = allPAs[paIndex]
            
            let isCurrentCell: Bool
            if isLive && isCurrentHalf && isCurrentBatter {
                if let event = event, event.result.isLive {
                    isCurrentCell = true
                } else if event == nil {
                    let maxPAIndex = allPAs.keys.max() ?? -1
                    isCurrentCell = paIndex == maxPAIndex + 1
                } else {
                    isCurrentCell = false
                }
            } else {
                isCurrentCell = false
            }

            if isCurrentCell {
                delegate?.didSelectActiveAtBat()
                return
            }

            guard let event = event else { return }
            delegate?.didSelectAtBat(event, batter: batter, pitcherName: event.pitcherName)
        } else {
            let col = indexPath.item % totalCols
            guard let (inningNum, subIndex) = columnLayout.inningInfo(forColumn: col) else { return }

            let isCurrentInning = data.currentInning == inningNum
            let isCurrentHalf = data.isTopInning == !isHomeTeam
            let isCurrentBatter = data.currentBatterId == batter.id

            if isLive && isCurrentInning && isCurrentHalf && isCurrentBatter {
                delegate?.didSelectActiveAtBat()
                return
            }

            let events = data.events(inningNum: inningNum, isHomeBatting: isHomeTeam)
            let batterEvents = events.filter { $0.batterId == batter.id }
            if subIndex < batterEvents.count {
                let event = batterEvents[subIndex]
                delegate?.didSelectAtBat(event, batter: batter, pitcherName: event.pitcherName)
            }
        }
    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // This is tricky because ScorecardView needs to handle the sync.
        // We'll pass it back via callback.
        if !(scrollView is UICollectionView) {
             horizontalScrollCallback?(scrollView.contentOffset.x)
        }
    }

    // MARK: - Private Configuration Helpers
    
    private func configureNameCell(_ collectionView: UICollectionView, indexPath: IndexPath, data: ScorecardData, lineup: [ScorecardBatter], rowIndex: Int, totalRows: Int, isTotalsRow: Bool, rowBackgroundColor: UIColor) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NameCell", for: indexPath) as! LabelCell
        if isTotalsRow {
            cell.label.text = "TOTALS"
            cell.label.font = AppFont.ibmPlexCondensed(16, textStyle: .headline)
            cell.label.textAlignment = .center
            cell.backgroundColor = AppColors.header
            cell.accessibilityLabel = "Totals row"
            cell.accessibilityTraits = .staticText
            return cell
        }

        let batter = lineup[rowIndex]
        let nameAttrs: [NSAttributedString.Key: Any] = [.font: UIFont(name: AppFont.permanentMarker, size: 16) ?? .systemFont(ofSize: 16), .foregroundColor: AppColors.pencil]
        let posAttrs: [NSAttributedString.Key: Any] = [.font: UIFont(name: AppFont.patrickHand, size: 14) ?? .systemFont(ofSize: 14), .foregroundColor: AppColors.pencil.withAlphaComponent(0.5)]

        let nameLines = ScorecardLayoutEngine.nameDisplayLines(batter.abbreviation)
        let text = NSMutableAttributedString(string: "\(nameLines.joined(separator: "\n"))\n", attributes: nameAttrs)
        var posText = batter.position
        if let num = batter.jerseyNumber { posText += " #\(num)" }
        if let entryInning = batter.inningEntered { posText += " (\(entryInning))" }
        text.append(NSAttributedString(string: posText, attributes: posAttrs))

        cell.label.numberOfLines = nameLines.count + 1
        cell.label.attributedText = text
        cell.label.textAlignment = .left
        cell.backgroundColor = rowBackgroundColor
        cell.accessibilityLabel = accessibilityProvider.nameAccessibilityLabel(for: batter, rowIndex: rowIndex, totalRows: totalRows)
        cell.accessibilityHint = "Double tap for player details."
        cell.accessibilityTraits = .button
        return cell
    }

    private func configureStatCell(_ collectionView: UICollectionView, indexPath: IndexPath, data: ScorecardData, lineup: [ScorecardBatter], statType: String, rowIndex: Int, totalRows: Int, isTotalsRow: Bool, rowBackgroundColor: UIColor) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LabelCell.reuseIdentifier, for: indexPath) as! LabelCell
        cell.label.font = UIFont(name: AppFont.permanentMarker, size: 16) ?? .systemFont(ofSize: 16)
        cell.label.textColor = AppColors.pencil

        if isTotalsRow {
            var totalValue = 0
            for batter in lineup {
                let stats = data.calculatePlayerStats(for: batter.id, isHome: isHomeTeam)
                switch statType {
                case "AB": totalValue += stats.atBats
                case "R": totalValue += stats.runs
                case "H": totalValue += stats.hits
                case "RBI": totalValue += stats.rbi
                default: break
                }
            }
            cell.label.text = "\(totalValue)"
            cell.label.font = UIFont(name: AppFont.permanentMarker, size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
            if statType == "R", totalValue > 0 {
                cell.label.textColor = data.teamAccentColor(isHomeTeam: isHomeTeam)
            }
            cell.backgroundColor = AppColors.header
            cell.accessibilityLabel = accessibilityProvider.statAccessibilityLabel(
                statType: statType, value: "\(totalValue)", batter: nil,
                rowIndex: rowIndex, totalRows: totalRows, isTotalsRow: true
            )
        } else {
            let batter = lineup[rowIndex]
            let stats = data.calculatePlayerStats(for: batter.id, isHome: isHomeTeam)
            switch statType {
            case "AB": cell.label.text = "\(stats.atBats)"
            case "R":
                cell.label.text = "\(stats.runs)"
                if stats.runs > 0 { cell.label.textColor = data.teamAccentColor(isHomeTeam: isHomeTeam) }
            case "H": cell.label.text = "\(stats.hits)"
            case "RBI": cell.label.text = "\(stats.rbi)"
            default: cell.label.text = "-"
            }
            cell.backgroundColor = rowBackgroundColor
            cell.accessibilityLabel = accessibilityProvider.statAccessibilityLabel(
                statType: statType, value: cell.label.text ?? "0", batter: batter,
                rowIndex: rowIndex, totalRows: totalRows, isTotalsRow: false
            )
        }
        cell.accessibilityTraits = .staticText
        return cell
    }

    private func configureTotalsInningCell(_ collectionView: UICollectionView, indexPath: IndexPath, data: ScorecardData, col: Int) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LabelCell.reuseIdentifier, for: indexPath) as! LabelCell
        cell.label.font = UIFont(name: AppFont.permanentMarker, size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        cell.label.textColor = AppColors.pencil
        if let (inningNum, subIndex) = columnLayout.inningInfo(forColumn: col) {
            if subIndex == 0 {
                let inningObj = data.innings.first { $0.num == inningNum }
                let events = isHomeTeam ? (inningObj?.home ?? []) : (inningObj?.away ?? [])
                let linescoreRuns = isHomeTeam ? inningObj?.homeRuns : inningObj?.awayRuns
                let derivedRuns = events.filter { $0.bases.home }.count
                let runs = linescoreRuns ?? derivedRuns
                cell.label.text = runs > 0 ? "\(runs)" : ""
                cell.label.textColor = (runs > 0) ? data.teamAccentColor(isHomeTeam: isHomeTeam) : AppColors.pencil
                cell.contentView.layer.borderWidth = 0.5
                cell.accessibilityLabel = accessibilityProvider.inningTotalsAccessibilityLabel(inningNum: inningNum, runs: runs)
                cell.isAccessibilityElement = true
            } else {
                cell.label.text = ""
                cell.contentView.layer.borderWidth = 0
                cell.isAccessibilityElement = false
            }
        } else {
            cell.label.text = ""
            cell.contentView.layer.borderWidth = 0.5
            cell.accessibilityLabel = nil
            cell.isAccessibilityElement = false
        }
        cell.backgroundColor = AppColors.header
        cell.accessibilityTraits = .staticText
        return cell
    }

    private func configureInningCell(_ collectionView: UICollectionView, indexPath: IndexPath, data: ScorecardData, lineup: [ScorecardBatter], batter: ScorecardBatter, col: Int, rowIndex: Int, totalRows: Int, rowBackgroundColor: UIColor) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ScorecardCell.reuseIdentifier, for: indexPath) as! ScorecardCell
        cell.setAccentColor(data.teamAccentColor(isHomeTeam: isHomeTeam))

        guard let (inningNum, subIndex) = columnLayout.inningInfo(forColumn: col) else {
            cell.configure(with: nil)
            cell.setInactive(false)
            return cell
        }

        let events = data.events(inningNum: inningNum, isHomeBatting: isHomeTeam)
        let batterEvents = events.filter { $0.batterId == batter.id }
        let event: AtBatEvent? = subIndex < batterEvents.count ? batterEvents[subIndex] : nil

        cell.configure(with: event)

        let isPitchingChange = event?.isPitchingChange ?? false
        cell.showPitchingChange(isPitchingChange)

        let isBeforeEntry = inningNum < (batter.inningEntered ?? 1)
        let exitInning = batter.inningExited ?? 99
        let isAfterExit = inningNum > exitInning

        let isPrimaryMerged = (isBeforeEntry && inningNum == 1 && subIndex == 0) ||
                             (isAfterExit && inningNum == exitInning + 1 && subIndex == 0)
        let isHiddenMerged = (isBeforeEntry && !isPrimaryMerged) || (isAfterExit && !isPrimaryMerged)

        if isBeforeEntry || isAfterExit {
            cell.backgroundColor = AppColors.inactive
            cell.setInactive(true)
        } else {
            cell.backgroundColor = rowBackgroundColor
            cell.setInactive(false)
        }

        let isCurrentInning = data.currentInning == inningNum
        let isCurrentHalf = data.isTopInning == !isHomeTeam
        let isCurrentBatter = data.currentBatterId == batter.id
        let isActiveSubColumn = subIndex == max(0, batterEvents.count - 1)
        let isCurrentCell = isLive && isCurrentInning && isCurrentHalf && isCurrentBatter && isActiveSubColumn

        if isCurrentCell {
            cell.contentView.layer.borderWidth = 3.0
            cell.contentView.layer.borderColor = UIColor.systemBlue.cgColor
            cell.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
        } else {
            cell.contentView.layer.borderWidth = isHiddenMerged ? 0 : 0.5
            cell.contentView.layer.borderColor = AppColors.grid.cgColor
        }
        cell.isAccessibilityElement = !isHiddenMerged
        if !isHiddenMerged {
            let totalSubColumns = columnLayout.layout(forInning: inningNum)?.subColumnCount ?? 1
            cell.setAccessibility(
                label: accessibilityProvider.inningAccessibilityLabel(
                    for: event, batter: batter, inningNum: inningNum,
                    subIndex: subIndex, totalSubColumns: totalSubColumns,
                    rowIndex: rowIndex, totalRows: totalRows,
                    isCurrentCell: isCurrentCell,
                    isBeforeEntry: isBeforeEntry, isAfterExit: isAfterExit
                ),
                hint: isCurrentCell ? "Double tap for the live at-bat." : (event != nil ? "Double tap for at-bat details." : nil),
                traits: (isCurrentCell || event != nil) ? .button : .staticText
            )
        }

        return cell
    }

    // MARK: - Compact Mode Helpers

    private func compactPAsByColumn(for batter: ScorecardBatter, data: ScorecardData, lineup: [ScorecardBatter]) -> [Int: AtBatEvent] {
        guard let slot = batter.battingOrderSlot else { return [:] }
        let eventsBySlot = layoutEngine.compactPlateAppearancesBySlot(data: data, lineup: lineup, isHomeTeam: isHomeTeam)
        return (eventsBySlot[slot] ?? [:]).filter { $0.value.batterId == batter.id }
    }

    private func firstCompactColumn(for batter: ScorecardBatter, data: ScorecardData, lineup: [ScorecardBatter]) -> Int? {
        let columns = compactPAsByColumn(for: batter, data: data, lineup: lineup).keys.sorted()
        return columns.first
    }

    private func compactEvent(for rowIndex: Int, paIndex: Int, lineup: [ScorecardBatter], data: ScorecardData) -> AtBatEvent? {
        guard lineup.indices.contains(rowIndex) else { return nil }
        return compactPAsByColumn(for: lineup[rowIndex], data: data, lineup: lineup)[paIndex]
    }

    private func compactColumnRowOrder(for paIndex: Int, lineupCount: Int) -> [Int] {
        guard lineupCount > 0 else { return [] }
        let startIndex = paIndex < compactColumns.count ? compactColumns[paIndex].leadoffLineupIndex : 0
        guard (0..<lineupCount).contains(startIndex) else { return Array(0..<lineupCount) }
        return Array(startIndex..<lineupCount) + Array(0..<startIndex)
    }

    private func compactInningChangeIndicator(rowIndex: Int, paIndex: Int, lineup: [ScorecardBatter], data: ScorecardData) -> Bool {
        guard rowIndex > 0 else { return false }
        guard let currentEvent = compactEvent(for: rowIndex, paIndex: paIndex, lineup: lineup, data: data) else { return false }

        var previousEvent: AtBatEvent?
        for column in 0...paIndex {
            let rowOrder = compactColumnRowOrder(for: column, lineupCount: lineup.count)
            for orderedRowIndex in rowOrder {
                let event = compactEvent(for: orderedRowIndex, paIndex: column, lineup: lineup, data: data)
                if column == paIndex && orderedRowIndex == rowIndex {
                    return previousEvent?.inning != currentEvent.inning
                }
                if let event {
                    previousEvent = event
                }
            }
        }

        return false
    }

    private func configureCompactCell(_ collectionView: UICollectionView, indexPath: IndexPath, data: ScorecardData, lineup: [ScorecardBatter], batter: ScorecardBatter, col: Int, rowIndex: Int, totalRows: Int, rowBackgroundColor: UIColor) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ScorecardCell.reuseIdentifier, for: indexPath) as! ScorecardCell
        cell.setAccentColor(data.teamAccentColor(isHomeTeam: isHomeTeam))

        guard columnLayout.inningInfo(forColumn: col) != nil else {
            cell.configure(with: nil)
            cell.setInactive(false)
            cell.showInningChangeIndicator(false)
            return cell
        }

        let paIndex = col
        let allPAs = compactPAsByColumn(for: batter, data: data, lineup: lineup)
        let event = allPAs[paIndex]

        cell.configure(with: event)

        let isPitchingChange = event?.isPitchingChange ?? false
        cell.showPitchingChange(isPitchingChange)

        let firstCompactColumn = firstCompactColumn(for: batter, data: data, lineup: lineup)
        let isInactiveByEvents = firstCompactColumn.map { paIndex < $0 } == true

        let inningEntered = batter.inningEntered ?? 1
        let exitInning = batter.inningExited ?? 99
        let compactColumn = paIndex < compactColumns.count ? compactColumns[paIndex] : nil
        let isBeforeEntryByInning = compactColumn.map { $0.inningEnd < inningEntered } ?? false
        let isAfterExitByInning = compactColumn.map { $0.inningStart > exitInning } ?? false

        let isInactive = event == nil && (isInactiveByEvents || isBeforeEntryByInning || isAfterExitByInning)

        if isInactive {
            cell.backgroundColor = AppColors.inactive
            cell.setInactive(true)
        } else {
            cell.backgroundColor = rowBackgroundColor
            cell.setInactive(false)
        }

        let showsInningChange = compactInningChangeIndicator(
            rowIndex: rowIndex,
            paIndex: paIndex,
            lineup: lineup,
            data: data
        )
        cell.showInningChangeIndicator(showsInningChange, color: data.teamAccentColor(isHomeTeam: isHomeTeam))

        let isCurrentBatter = data.currentBatterId == batter.id
        let isCurrentHalf = data.isTopInning == !isHomeTeam
        let isCurrentCell: Bool
        if isLive && isCurrentHalf && isCurrentBatter {
            if let event = event, event.result.isLive {
                isCurrentCell = true
            } else if event == nil {
                let maxPAIndex = allPAs.keys.max() ?? -1
                isCurrentCell = paIndex == maxPAIndex + 1
            } else {
                isCurrentCell = false
            }
        } else {
            isCurrentCell = false
        }

        if isCurrentCell {
            cell.contentView.layer.borderWidth = 3.0
            cell.contentView.layer.borderColor = UIColor.systemBlue.cgColor
            cell.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
        } else {
            cell.contentView.layer.borderWidth = 0.5
            cell.contentView.layer.borderColor = AppColors.grid.cgColor
        }

        cell.isAccessibilityElement = true

        if let event = event {
            let compactCol = paIndex < compactColumns.count ? compactColumns[paIndex] : nil
            let inningRange = compactCol.map { "\($0.inningStart)-\($0.inningEnd)" } ?? ""
            let baseLabel = "\(batter.abbreviation), plate appearance \(paIndex + 1), innings \(inningRange): \(event.result.displayText)"
            cell.accessibilityLabel = isCurrentCell ? "Live: \(baseLabel)" : baseLabel
            cell.accessibilityHint = isCurrentCell ? "Double tap for the live at-bat." : "Double tap for at-bat details."
            cell.accessibilityTraits = .button
        } else {
            let baseLabel = "\(batter.abbreviation), plate appearance \(paIndex + 1): no at-bat"
            cell.accessibilityLabel = isCurrentCell ? "Live: \(baseLabel)" : baseLabel
            cell.accessibilityHint = isCurrentCell ? "Double tap for the live at-bat." : nil
            cell.accessibilityTraits = isCurrentCell ? .button : .staticText
        }

        return cell
    }

    private func configureCompactTotalsCell(_ collectionView: UICollectionView, indexPath: IndexPath, data: ScorecardData, col: Int) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LabelCell.reuseIdentifier, for: indexPath) as! LabelCell
        cell.label.font = UIFont(name: AppFont.permanentMarker, size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        cell.label.textColor = AppColors.pencil

        guard columnLayout.inningInfo(forColumn: col) != nil else {
            cell.label.text = ""
            cell.contentView.layer.borderWidth = 0.5
            cell.backgroundColor = AppColors.header
            return cell
        }

        let paIndex = col
        guard paIndex < compactColumns.count else {
            cell.label.text = ""
            cell.contentView.layer.borderWidth = 0.5
            cell.backgroundColor = AppColors.header
            return cell
        }

        let compact = compactColumns[paIndex]
        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        let eventsBySlot = layoutEngine.compactPlateAppearancesBySlot(data: data, lineup: lineup, isHomeTeam: isHomeTeam)
        var runs = 0
        for events in eventsBySlot.values {
            if let event = events[paIndex], event.bases.home {
                runs += 1
            }
        }
        cell.label.text = runs > 0 ? "\(runs)" : ""
        cell.label.textColor = runs > 0 ? data.teamAccentColor(isHomeTeam: isHomeTeam) : AppColors.pencil
        cell.contentView.layer.borderWidth = 0.5
        cell.backgroundColor = AppColors.header
        cell.accessibilityLabel = "Innings \(compact.inningStart)-\(compact.inningEnd): \(runs) runs"
        cell.isAccessibilityElement = true
        cell.accessibilityTraits = .staticText
        return cell
    }
}
