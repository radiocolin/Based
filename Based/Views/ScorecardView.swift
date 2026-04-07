import UIKit

protocol ScorecardViewDelegate: AnyObject {
    func didSelectAtBat(_ event: AtBatEvent, batter: ScorecardBatter, pitcherName: String)
    func didSelectPlayer(_ batter: ScorecardBatter)
    func didSelectActiveAtBat()
}

class ScorecardView: UIView {
    
    weak var delegate: ScorecardViewDelegate?
    
    // MARK: - UI Components
    private let topLeftLabel: UILabel = {
        let label = UILabel()
        label.text = "BATTER"
        label.font = UIFont(name: "PatrickHand-Regular", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        label.textColor = AppColors.pencil
        label.textAlignment = .center
        label.backgroundColor = AppColors.header
        return label
    }()
    
    private var leftCollectionView: UICollectionView!
    private let rightScrollView = UIScrollView()
    private let rightHeaderStack = UIStackView()
    private var rightCollectionView: UICollectionView!
    
    // Constraints
    private var leftTopConstraint: NSLayoutConstraint?
    private var rightTopConstraint: NSLayoutConstraint?
    private var headerHeightConstraint: NSLayoutConstraint?
    private var nameWidthConstraint: NSLayoutConstraint?
    private var headerNameWidthConstraint: NSLayoutConstraint?
    
    // Data
    private var scorecardData: ScorecardData?
    private var isHomeTeam = false
    private var areHeadersVisible = true
    private var isLive = false
    private var columnLayout = ColumnLayout(innings: (1...9).map { InningColumnLayout(inningNum: $0, subColumnCount: 1, startColumn: $0 - 1) })
    
    // Constants
    private var nameWidth: CGFloat = 90
    private let inningWidth: CGFloat = 56
    private let statWidth: CGFloat = 38
    private let headerHeight: CGFloat = 32
    private let rowHeight: CGFloat = 64
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupCollectionViews()
        backgroundColor = AppColors.paper
        layer.cornerRadius = 16
        clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(topLeftLabel)
        topLeftLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let leftLayout = UICollectionViewFlowLayout()
        leftLayout.itemSize = CGSize(width: nameWidth, height: rowHeight)
        leftLayout.minimumLineSpacing = 0
        leftLayout.minimumInteritemSpacing = 0
        leftCollectionView = UICollectionView(frame: .zero, collectionViewLayout: leftLayout)
        leftCollectionView.backgroundColor = .clear
        leftCollectionView.isScrollEnabled = false
        leftCollectionView.register(LabelCell.self, forCellWithReuseIdentifier: "NameCell")
        leftCollectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftCollectionView)
        
        rightScrollView.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.showsHorizontalScrollIndicator = false
        rightScrollView.bounces = false
        addSubview(rightScrollView)
        
        rightHeaderStack.axis = .horizontal
        rightHeaderStack.distribution = .fill
        rightHeaderStack.spacing = 0
        rightHeaderStack.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.addSubview(rightHeaderStack)
        
        let rightLayout = UICollectionViewFlowLayout()
        rightLayout.itemSize = CGSize(width: inningWidth, height: rowHeight)
        rightLayout.minimumLineSpacing = 0
        rightLayout.minimumInteritemSpacing = 0
        rightCollectionView = UICollectionView(frame: .zero, collectionViewLayout: rightLayout)
        rightCollectionView.backgroundColor = .clear
        rightCollectionView.isScrollEnabled = false
        rightCollectionView.register(ScorecardCell.self, forCellWithReuseIdentifier: ScorecardCell.reuseIdentifier)
        rightCollectionView.register(LabelCell.self, forCellWithReuseIdentifier: LabelCell.reuseIdentifier)
        rightCollectionView.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.addSubview(rightCollectionView)
        
        headerHeightConstraint = topLeftLabel.heightAnchor.constraint(equalToConstant: headerHeight)
        leftTopConstraint = leftCollectionView.topAnchor.constraint(equalTo: topLeftLabel.bottomAnchor)
        rightTopConstraint = rightCollectionView.topAnchor.constraint(equalTo: rightHeaderStack.bottomAnchor)
        
        headerNameWidthConstraint = topLeftLabel.widthAnchor.constraint(equalToConstant: nameWidth)
        nameWidthConstraint = leftCollectionView.widthAnchor.constraint(equalToConstant: nameWidth)
        
        NSLayoutConstraint.activate([
            topLeftLabel.topAnchor.constraint(equalTo: topAnchor),
            topLeftLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerNameWidthConstraint!,
            headerHeightConstraint!,
            
            leftTopConstraint!,
            leftCollectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameWidthConstraint!,
            leftCollectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            rightScrollView.topAnchor.constraint(equalTo: topAnchor),
            rightScrollView.leadingAnchor.constraint(equalTo: leftCollectionView.trailingAnchor),
            rightScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            rightHeaderStack.topAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.topAnchor),
            rightHeaderStack.leadingAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.leadingAnchor),
            rightHeaderStack.trailingAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.trailingAnchor),
            rightHeaderStack.heightAnchor.constraint(equalToConstant: headerHeight),
            
            rightTopConstraint!,
            rightCollectionView.leadingAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.leadingAnchor),
            rightCollectionView.trailingAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.trailingAnchor),
            rightCollectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        updateContentWidth()
    }

    private var rightContentWidthConstraint: NSLayoutConstraint?
    private func updateContentWidth() {
        rightContentWidthConstraint?.isActive = false
        let inningsWidth = inningWidth * CGFloat(columnLayout.innings.map { $0.subColumnCount }.reduce(0, +))
        let statsWidthTotal = statWidth * CGFloat(columnLayout.statColumns.count)
        rightContentWidthConstraint = rightCollectionView.widthAnchor.constraint(equalToConstant: inningsWidth + statsWidthTotal)
        rightContentWidthConstraint?.isActive = true
        rightHeaderStack.widthAnchor.constraint(equalTo: rightCollectionView.widthAnchor).isActive = true
    }
    
    private func setupCollectionViews() {
        leftCollectionView.dataSource = self
        leftCollectionView.delegate = self
        rightCollectionView.dataSource = self
        rightCollectionView.delegate = self
        rightScrollView.delegate = self // CRITICAL: Fixes scroll sync
        updateHeaderLabels()
    }

    private var lastColumnLayout: ColumnLayout?
    
    private func updateHeaderLabels() {
        if let last = lastColumnLayout, last.totalColumns == columnLayout.totalColumns, 
           last.innings.count == columnLayout.innings.count {
            // Check if subcolumn counts changed
            let countsChanged = zip(last.innings, columnLayout.innings).contains { $0.subColumnCount != $1.subColumnCount }
            if !countsChanged { return }
        }
        lastColumnLayout = columnLayout
        
        rightHeaderStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for inningLayout in columnLayout.innings {
            let label = UILabel()
            label.text = "\(inningLayout.inningNum)"
            label.textAlignment = .center
            label.font = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
            label.textColor = AppColors.pencil
            label.backgroundColor = AppColors.header
            label.layer.borderWidth = 0.5
            label.layer.borderColor = AppColors.grid.cgColor
            label.widthAnchor.constraint(equalToConstant: inningWidth * CGFloat(inningLayout.subColumnCount)).isActive = true
            rightHeaderStack.addArrangedSubview(label)
        }
        for stat in columnLayout.statColumns {
            let label = UILabel()
            label.text = stat
            label.textAlignment = .center
            label.font = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
            label.textColor = AppColors.pencil
            label.backgroundColor = AppColors.header
            label.layer.borderWidth = 0.5
            label.layer.borderColor = AppColors.grid.cgColor
            label.widthAnchor.constraint(equalToConstant: statWidth).isActive = true
            rightHeaderStack.addArrangedSubview(label)
        }
    }
    
    func configure(with data: ScorecardData) {
        let oldData = scorecardData
        let hasChanges = data != oldData
        
        // Capture the old item counts BEFORE updating data, since numberOfItems reads scorecardData
        let oldLeftCount = leftCollectionView.numberOfItems(inSection: 0)
        let oldRightCount = rightCollectionView.numberOfItems(inSection: 0)
        let oldColumns = columnLayout.totalColumns
        
        self.scorecardData = data
        self.columnLayout = computeColumnLayout()
        updateNameColumnWidth()
        updateHeaderLabels()
        updateContentWidth()
        
        if hasChanges {
            // Compare what the collection view currently has vs what the new data produces
            let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
            let newLeftCount = lineup.count + 1
            let newRightCount = newLeftCount * columnLayout.totalColumns
            let structureChanged = oldLeftCount != newLeftCount || oldRightCount != newRightCount || oldColumns != columnLayout.totalColumns
            
            if structureChanged {
                leftCollectionView.reloadData()
                rightCollectionView.reloadData()
            } else {
                // If only data changed, reconfigure visible cells for smoothness
                let visibleLeft = leftCollectionView.indexPathsForVisibleItems
                let visibleRight = rightCollectionView.indexPathsForVisibleItems
                leftCollectionView.reconfigureItems(at: visibleLeft)
                rightCollectionView.reconfigureItems(at: visibleRight)
            }
        }
        invalidateIntrinsicContentSize()
    }
    
    func setTeam(isHome: Bool) {
        self.isHomeTeam = isHome
        self.columnLayout = computeColumnLayout()
        updateNameColumnWidth()
        updateHeaderLabels()
        updateContentWidth()
        leftCollectionView.reloadData()
        rightCollectionView.reloadData()
        invalidateIntrinsicContentSize()
    }

    private func updateNameColumnWidth() {
        let newWidth = computeNameWidth()
        guard newWidth != nameWidth else { return }
        nameWidth = newWidth
        nameWidthConstraint?.constant = newWidth
        headerNameWidthConstraint?.constant = newWidth
        if let layout = leftCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = CGSize(width: newWidth, height: rowHeight)
            layout.invalidateLayout()
        }
    }

    func setHeadersVisible(_ visible: Bool) {
        areHeadersVisible = visible
        topLeftLabel.isHidden = !visible
        rightHeaderStack.isHidden = !visible
        
        headerHeightConstraint?.constant = visible ? headerHeight : 0
        
        // When not visible, we want collection views to jump to the top
        if !visible {
            leftTopConstraint?.isActive = false
            rightTopConstraint?.isActive = false
            leftCollectionView.topAnchor.constraint(equalTo: topAnchor).isActive = true
            rightCollectionView.topAnchor.constraint(equalTo: rightScrollView.topAnchor).isActive = true
        }
        
        invalidateIntrinsicContentSize()
    }
    
    func setIsLive(_ live: Bool) {
        let changed = self.isLive != live
        self.isLive = live
        if changed {
            rightCollectionView.reconfigureItems(at: rightCollectionView.indexPathsForVisibleItems)
        }
    }
    
    func scrollToActiveCell() {
        guard let data = scorecardData,
              let inningNum = data.currentInning,
              let batterId = data.currentBatterId,
              data.isTopInning != nil else { return }

        guard isViewingCurrentBattingTeam(data) else { return }

        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        guard lineup.firstIndex(where: { $0.id == batterId }) != nil else { return }

        guard let inningLayout = columnLayout.layout(forInning: inningNum) else { return }
        let colIndex = inningLayout.startColumn + inningLayout.subColumnCount - 1

        // Horizontal Scroll
        let hOffset = max(0, CGFloat(colIndex) * inningWidth - (rightScrollView.bounds.width / 2) + (inningWidth / 2))
        let maxHOffset = max(0, rightScrollView.contentSize.width - rightScrollView.bounds.width)
        syncHorizontalOffset(min(hOffset, maxHOffset))
    }

    var currentHorizontalOffset: CGFloat {
        return rightScrollView.contentOffset.x
    }

    var horizontalScrollCallback: ((CGFloat) -> Void)?

    func syncHorizontalOffset(_ offset: CGFloat) {
        rightScrollView.contentOffset.x = offset
    }

    var horizontalContentWidth: CGFloat { rightScrollView.contentSize.width }
    var horizontalVisibleWidth: CGFloat { rightScrollView.bounds.width }

    var currentColumnLayout: ColumnLayout { columnLayout }
    var currentNameWidth: CGFloat { nameWidth }

    private func isViewingCurrentBattingTeam(_ data: ScorecardData) -> Bool {
        (data.isTopInning == true && !isHomeTeam) || (data.isTopInning == false && isHomeTeam)
    }

    private func activeSubcolumnIndex(for batterEvents: [AtBatEvent]) -> Int {
        max(0, batterEvents.count - 1)
    }

    private func computeNameWidth() -> CGFloat {
        guard let data = scorecardData else { return 90 }
        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        
        let nameFont = UIFont(name: "PatrickHand-Regular", size: 18) ?? .systemFont(ofSize: 18)
        let posFont = UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14)
        
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

    private func computeColumnLayout() -> ColumnLayout {
        guard let data = scorecardData else {
            let innings = (1...9).map { InningColumnLayout(inningNum: $0, subColumnCount: 1, startColumn: $0 - 1) }
            return ColumnLayout(innings: innings)
        }
        
        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        let inningCount = max(data.innings.count, 9)
        var layouts: [InningColumnLayout] = []
        var runningColumn = 0
        
        for i in 1...inningCount {
            let inningObj = data.innings.first { $0.num == i }
            let events = isHomeTeam ? (inningObj?.home ?? []) : (inningObj?.away ?? [])
            
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

    override var intrinsicContentSize: CGSize {
        guard let data = scorecardData else { return CGSize(width: UIView.noIntrinsicMetric, height: 200) }
        let lineupCount = isHomeTeam ? data.lineups.home.count : data.lineups.away.count
        let h = areHeadersVisible ? headerHeight : 0
        let totalHeight = h + (CGFloat(lineupCount + 1) * rowHeight)
        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }
    
    private func calculatePlayerStats(for batterId: Int) -> PlayerGameStats {
        guard let data = scorecardData else { return PlayerGameStats(atBats: 0, hits: 0, runs: 0, rbi: 0, walks: 0, strikeouts: 0) }
        return data.calculatePlayerStats(for: batterId, isHome: isHomeTeam)
    }

    private var teamAccentColor: UIColor {
        guard let data = scorecardData else { return AppColors.pencil }
        return data.teamAccentColor(isHomeTeam: isHomeTeam)
    }
}

extension ScorecardView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == rightScrollView {
            horizontalScrollCallback?(scrollView.contentOffset.x)
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let data = scorecardData else { return 0 }
        let lineupCount = (isHomeTeam ? data.lineups.home.count : data.lineups.away.count) + 1 // +1 for totals
        return collectionView == leftCollectionView ? lineupCount : lineupCount * columnLayout.totalColumns
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == leftCollectionView {
            return CGSize(width: nameWidth, height: rowHeight)
        } else {
            let totalCols = columnLayout.totalColumns
            let col = indexPath.item % totalCols
            
            // For the totals row, if an inning has multiple sub-columns (batting around),
            // make the first sub-column span all of them and subsequent ones zero width.
            let rowIndex = indexPath.item / totalCols
            guard let data = scorecardData else { return .zero }
            let lineupCount = (isHomeTeam ? data.lineups.home.count : data.lineups.away.count)
            let isTotalsRow = rowIndex == lineupCount
            
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
            }
            
            let width = columnLayout.statInfo(forColumn: col) != nil ? statWidth : inningWidth
            return CGSize(width: width, height: rowHeight)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let data = scorecardData else { return UICollectionViewCell() }
        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        let totalCols = columnLayout.totalColumns
        let rowIndex = (collectionView == leftCollectionView) ? indexPath.item : indexPath.item / totalCols
        
        let isTotalsRow = rowIndex == lineup.count
        let rowBackgroundColor = rowIndex % 2 == 0 ? UIColor.clear : AppColors.alternateRow
        
        if collectionView == leftCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NameCell", for: indexPath) as! LabelCell
            if isTotalsRow {
                cell.label.text = "TOTALS"
                cell.label.font = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
                cell.label.textAlignment = .center
                cell.backgroundColor = AppColors.header
                return cell
            }
            
            let batter = lineup[rowIndex]
            let nameAttrs: [NSAttributedString.Key: Any] = [.font: UIFont(name: "PermanentMarker-Regular", size: 16) ?? .systemFont(ofSize: 16), .foregroundColor: AppColors.pencil]
            let posAttrs: [NSAttributedString.Key: Any] = [.font: UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14), .foregroundColor: AppColors.pencil.withAlphaComponent(0.5)]
            
            let text = NSMutableAttributedString(string: "\(batter.abbreviation)\n", attributes: nameAttrs)
            var posText = batter.position
            if let num = batter.jerseyNumber { posText += " #\(num)" }
            if let entryInning = batter.inningEntered { posText += " (\(entryInning))" }
            text.append(NSAttributedString(string: posText, attributes: posAttrs))
            
            cell.label.attributedText = text
            cell.label.textAlignment = .left
            cell.backgroundColor = rowBackgroundColor
            return cell
        } else {
            let col = indexPath.item % totalCols
            
            // Handle Stat Columns
            if let statType = columnLayout.statInfo(forColumn: col) {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LabelCell.reuseIdentifier, for: indexPath) as! LabelCell
                cell.label.font = UIFont(name: "PermanentMarker-Regular", size: 16) ?? .systemFont(ofSize: 16)
                cell.label.textColor = AppColors.pencil
                
                if isTotalsRow {
                    var totalValue = 0
                    for batter in lineup {
                        let stats = calculatePlayerStats(for: batter.id)
                        switch statType {
                        case "AB": totalValue += stats.atBats
                        case "R": totalValue += stats.runs
                        case "H": totalValue += stats.hits
                        case "RBI": totalValue += stats.rbi
                        default: break
                        }
                    }
                    cell.label.text = "\(totalValue)"
                    cell.label.font = UIFont(name: "PermanentMarker-Regular", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
                    if statType == "R", totalValue > 0 {
                        cell.label.textColor = teamAccentColor
                    }
                    cell.backgroundColor = AppColors.header
                } else {
                    let batter = lineup[rowIndex]
                    let stats = calculatePlayerStats(for: batter.id)
                    let value: Int
                    switch statType {
                    case "AB":
                        value = stats.atBats
                        cell.label.text = "\(value)"
                    case "R":
                        value = stats.runs
                        cell.label.text = "\(value)"
                        if value > 0 {
                            cell.label.textColor = teamAccentColor
                        }
                    case "H":
                        value = stats.hits
                        cell.label.text = "\(value)"
                    case "RBI":
                        value = stats.rbi
                        cell.label.text = "\(value)"
                    default:
                        cell.label.text = "-"
                    }
                    cell.backgroundColor = rowBackgroundColor
                }
                return cell
            }
            
            // Handle Inning Columns
            if isTotalsRow {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LabelCell.reuseIdentifier, for: indexPath) as! LabelCell
                cell.label.font = UIFont(name: "PermanentMarker-Regular", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
                cell.label.textColor = AppColors.pencil
                if let (inningNum, subIndex) = columnLayout.inningInfo(forColumn: col) {
                    if subIndex == 0 {
                        let inningObj = data.innings.first { $0.num == inningNum }
                        let events = isHomeTeam ? (inningObj?.home ?? []) : (inningObj?.away ?? [])
                        let runs = events.filter { $0.bases.home }.count
                        cell.label.text = runs > 0 ? "\(runs)" : ""
                        cell.label.textColor = (runs > 0) ? teamAccentColor : AppColors.pencil
                        cell.contentView.layer.borderWidth = 0.5
                    } else {
                        cell.label.text = ""
                        cell.contentView.layer.borderWidth = 0
                    }
                } else {
                    cell.label.text = ""
                    cell.contentView.layer.borderWidth = 0.5
                }
                cell.backgroundColor = AppColors.header
                return cell
            }
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ScorecardCell.reuseIdentifier, for: indexPath) as! ScorecardCell
            cell.setAccentColor(teamAccentColor)
            let batter = lineup[rowIndex]
            
            guard let (inningNum, subIndex) = columnLayout.inningInfo(forColumn: col) else {
                cell.configure(with: nil)
                return cell
            }
            
            let inningObj = data.innings.first { $0.num == inningNum }
            let events = isHomeTeam ? inningObj?.home : inningObj?.away
            let batterEvents = events?.filter { $0.batterId == batter.id } ?? []
            let event: AtBatEvent? = subIndex < batterEvents.count ? batterEvents[subIndex] : nil
            
            let isBeforeEntry = inningNum < (batter.inningEntered ?? 1)
            let isAfterExit = batter.inningExited != nil && inningNum > (batter.inningExited ?? 99)
            
            if isBeforeEntry || isAfterExit {
                cell.backgroundColor = AppColors.inactive
            } else {
                cell.backgroundColor = rowBackgroundColor
            }
            
            // Highlight current active cell
            let isCurrentInning = data.currentInning == inningNum
            let isCurrentHalf = data.isTopInning == !isHomeTeam
            let isCurrentBatter = data.currentBatterId == batter.id
            let isActiveSubColumn = subIndex == activeSubcolumnIndex(for: batterEvents)
            
            if isLive && isCurrentInning && isCurrentHalf && isCurrentBatter && isActiveSubColumn {
                cell.contentView.layer.borderWidth = 3.0
                cell.contentView.layer.borderColor = UIColor.systemBlue.cgColor
                cell.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
            } else {
                cell.contentView.layer.borderWidth = 0.5
                cell.contentView.layer.borderColor = AppColors.grid.cgColor
            }
            
            cell.configure(with: event)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let data = scorecardData else { return }
        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        let totalCols = columnLayout.totalColumns
        let rowIndex = (collectionView == leftCollectionView) ? indexPath.item : indexPath.item / totalCols
        if rowIndex >= lineup.count { return } // Totals row not selectable
        let batter = lineup[rowIndex]
        
        if collectionView == leftCollectionView {
            delegate?.didSelectPlayer(batter)
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
            
            let inningObj = data.innings.first { $0.num == inningNum }
            let events = isHomeTeam ? inningObj?.home : inningObj?.away
            let batterEvents = events?.filter { $0.batterId == batter.id } ?? []
            if subIndex < batterEvents.count {
                let event = batterEvents[subIndex]
                delegate?.didSelectAtBat(event, batter: batter, pitcherName: event.pitcherName)
            }
        }
    }
}
