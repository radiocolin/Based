import UIKit

protocol ScorecardViewDelegate: AnyObject {
    func didSelectAtBat(_ event: AtBatEvent, batter: ScorecardBatter, pitcherName: String)
    func didSelectPlayer(_ batter: ScorecardBatter)
    func didSelectActiveAtBat()
}

class ScorecardView: UIView {
    
    weak var delegate: ScorecardViewDelegate? {
        didSet {
            dataSource.delegate = delegate
        }
    }
    
    // MARK: - UI Components
    private let topLeftLabel: UILabel = {
        let label = UILabel()
        label.text = "BATTER"
        label.font = AppFont.ibmPlexCondensed(18, textStyle: .headline)
        label.textColor = AppColors.pencil
        label.textAlignment = .center
        label.backgroundColor = AppColors.header
        return label
    }()
    
    var leftCollectionView: UICollectionView!
    private let rightScrollView = UIScrollView()
    private let rightHeaderStack = UIStackView()
    var rightCollectionView: UICollectionView!
    
    private var leftTopConstraint: NSLayoutConstraint?
    private var rightTopConstraint: NSLayoutConstraint?
    private var headerHeightConstraint: NSLayoutConstraint?
    private var rightHeaderHeightConstraint: NSLayoutConstraint?
    private var nameWidthConstraint: NSLayoutConstraint?
    private var headerNameWidthConstraint: NSLayoutConstraint?
    
    private var rightContentWidthConstraint: NSLayoutConstraint?
    private var rightHeaderWidthConstraint: NSLayoutConstraint?
    
    // Engine & DataSource
    private let layoutEngine = ScorecardLayoutEngine()
    private let accessibilityProvider = ScorecardAccessibilityProvider()
    private let dataSource: ScorecardViewDataSource
    
    // Data
    private var scorecardData: ScorecardData?
    private var isHomeTeam = false
    private var areHeadersVisible = true
    private var isLive = false
    private var isCompact = false
    private var compactColumns: [CompactColumn] = []
    
    // Constants
    private var nameWidth: CGFloat = 90
    private let inningWidth: CGFloat = 56
    private let statWidth: CGFloat = 38
    private let headerHeight: CGFloat = 32
    private let rowHeight: CGFloat = 64
    
    override init(frame: CGRect) {
        let initialLayout = ColumnLayout(innings: (1...9).map { InningColumnLayout(inningNum: $0, subColumnCount: 1, startColumn: $0 - 1) })
        self.dataSource = ScorecardViewDataSource(columnLayout: initialLayout, layoutEngine: layoutEngine, accessibilityProvider: accessibilityProvider)
        
        super.init(frame: frame)
        setupUI()
        setupCollectionViews()
        backgroundColor = AppColors.paper
        layer.cornerRadius = 16
        clipsToBounds = true
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: ScorecardView, _) in
            self.topLeftLabel.textColor = AppColors.pencil
            self.topLeftLabel.backgroundColor = AppColors.header
            for view in self.rightHeaderStack.arrangedSubviews {
                if let label = view as? UILabel {
                    label.textColor = AppColors.pencil
                    label.backgroundColor = AppColors.header
                    label.layer.borderColor = AppColors.grid.cgColor
                }
            }
            self.leftCollectionView.reloadData()
            self.rightCollectionView.reloadData()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        isAccessibilityElement = false
        addSubview(topLeftLabel)
        topLeftLabel.translatesAutoresizingMaskIntoConstraints = false
        topLeftLabel.isAccessibilityElement = false
        
        let leftLayout = UICollectionViewFlowLayout()
        leftLayout.itemSize = CGSize(width: nameWidth, height: rowHeight)
        leftLayout.minimumLineSpacing = 0
        leftLayout.minimumInteritemSpacing = 0
        leftCollectionView = UICollectionView(frame: .zero, collectionViewLayout: leftLayout)
        leftCollectionView.backgroundColor = .clear
        leftCollectionView.isScrollEnabled = false
        leftCollectionView.isAccessibilityElement = false
        leftCollectionView.register(LabelCell.self, forCellWithReuseIdentifier: "NameCell")
        leftCollectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftCollectionView)
        
        rightScrollView.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.showsHorizontalScrollIndicator = false
        rightScrollView.bounces = false
        rightScrollView.isAccessibilityElement = false
        addSubview(rightScrollView)
        
        rightHeaderStack.axis = .horizontal
        rightHeaderStack.distribution = .fill
        rightHeaderStack.spacing = 0
        rightHeaderStack.translatesAutoresizingMaskIntoConstraints = false
        rightHeaderStack.isAccessibilityElement = false
        rightScrollView.addSubview(rightHeaderStack)
        
        let rightLayout = UICollectionViewFlowLayout()
        rightLayout.itemSize = CGSize(width: inningWidth, height: rowHeight)
        rightLayout.minimumLineSpacing = 0
        rightLayout.minimumInteritemSpacing = 0
        rightCollectionView = UICollectionView(frame: .zero, collectionViewLayout: rightLayout)
        rightCollectionView.backgroundColor = .clear
        rightCollectionView.isScrollEnabled = false
        rightCollectionView.isAccessibilityElement = false
        rightCollectionView.register(ScorecardCell.self, forCellWithReuseIdentifier: ScorecardCell.reuseIdentifier)
        rightCollectionView.register(LabelCell.self, forCellWithReuseIdentifier: LabelCell.reuseIdentifier)
        rightCollectionView.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.addSubview(rightCollectionView)
        
        headerHeightConstraint = topLeftLabel.heightAnchor.constraint(equalToConstant: headerHeight)
        headerHeightConstraint?.priority = .init(999)
        
        rightHeaderHeightConstraint = rightHeaderStack.heightAnchor.constraint(equalToConstant: headerHeight)
        rightHeaderHeightConstraint?.priority = .init(999)
        
        leftTopConstraint = leftCollectionView.topAnchor.constraint(equalTo: topLeftLabel.bottomAnchor)
        rightTopConstraint = rightCollectionView.topAnchor.constraint(equalTo: rightHeaderStack.bottomAnchor)
        
        headerNameWidthConstraint = topLeftLabel.widthAnchor.constraint(equalToConstant: nameWidth)
        headerNameWidthConstraint?.priority = .init(999)
        
        nameWidthConstraint = leftCollectionView.widthAnchor.constraint(equalToConstant: nameWidth)
        nameWidthConstraint?.priority = .init(999)
        
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
            rightHeaderHeightConstraint!,
            
            rightTopConstraint!,
            rightCollectionView.leadingAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.leadingAnchor),
            rightCollectionView.trailingAnchor.constraint(equalTo: rightScrollView.contentLayoutGuide.trailingAnchor),
            rightCollectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        updateContentWidth()
    }

    private func updateContentWidth() {
        let totalWidth = layoutEngine.calculateContentWidth(columnLayout: dataSource.columnLayout)
        
        if let constraint = rightContentWidthConstraint {
            constraint.constant = totalWidth
        } else {
            rightContentWidthConstraint = rightCollectionView.widthAnchor.constraint(equalToConstant: totalWidth)
            rightContentWidthConstraint?.isActive = true
        }
        
        if rightHeaderWidthConstraint == nil {
            rightHeaderWidthConstraint = rightHeaderStack.widthAnchor.constraint(equalTo: rightCollectionView.widthAnchor)
            rightHeaderWidthConstraint?.isActive = true
        }
    }
    
    private func setupCollectionViews() {
        leftCollectionView.dataSource = dataSource
        leftCollectionView.delegate = dataSource
        rightCollectionView.dataSource = dataSource
        rightCollectionView.delegate = dataSource
        rightScrollView.delegate = dataSource // CRITICAL: Fixes scroll sync
        
        dataSource.horizontalScrollCallback = { [weak self] offset in
            self?.horizontalScrollCallback?(offset)
        }
        
        updateHeaderLabels()
    }

    private var lastColumnLayout: ColumnLayout?
    
    private func updateHeaderLabels() {
        let columnLayout = dataSource.columnLayout
        if let last = lastColumnLayout, last.totalColumns == columnLayout.totalColumns, 
           last.innings.count == columnLayout.innings.count {
            let countsChanged = zip(last.innings, columnLayout.innings).contains { $0.subColumnCount != $1.subColumnCount }
            if !countsChanged { return }
        }
        lastColumnLayout = columnLayout
        
        rightHeaderStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if isCompact {
            for compact in compactColumns {
                let label = UILabel()
                label.translatesAutoresizingMaskIntoConstraints = false
                if compact.inningStart == compact.inningEnd {
                    label.text = "\(compact.inningStart)"
                } else {
                    label.text = "\(compact.inningStart)-\(compact.inningEnd)"
                }
                label.textAlignment = .center
                label.font = AppFont.ibmPlexCondensed(14, textStyle: .caption1)
                label.textColor = AppColors.pencil
                label.backgroundColor = AppColors.header
                label.isAccessibilityElement = false
                label.layer.borderWidth = 0.5
                label.layer.borderColor = AppColors.grid.cgColor

                let widthConstraint = label.widthAnchor.constraint(equalToConstant: inningWidth)
                widthConstraint.priority = .init(999)
                widthConstraint.isActive = true

                rightHeaderStack.addArrangedSubview(label)
            }
        } else {
            for inningLayout in columnLayout.innings {
                let label = UILabel()
                label.translatesAutoresizingMaskIntoConstraints = false
                label.text = "\(inningLayout.inningNum)"
                label.textAlignment = .center
                label.font = AppFont.ibmPlexCondensed(16, textStyle: .caption1)
                label.textColor = AppColors.pencil
                label.backgroundColor = AppColors.header
                label.isAccessibilityElement = false
                label.layer.borderWidth = 0.5
                label.layer.borderColor = AppColors.grid.cgColor

                let width = inningWidth * CGFloat(inningLayout.subColumnCount)
                let widthConstraint = label.widthAnchor.constraint(equalToConstant: width)
                widthConstraint.priority = .init(999)
                widthConstraint.isActive = true

                rightHeaderStack.addArrangedSubview(label)
            }
        }
        for stat in columnLayout.statColumns {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = stat
            label.textAlignment = .center
            label.font = AppFont.ibmPlexCondensed(16, textStyle: .caption1)
            label.textColor = AppColors.pencil
            label.backgroundColor = AppColors.header
            label.isAccessibilityElement = false
            label.layer.borderWidth = 0.5
            label.layer.borderColor = AppColors.grid.cgColor
            
            let widthConstraint = label.widthAnchor.constraint(equalToConstant: statWidth)
            widthConstraint.priority = .init(999)
            widthConstraint.isActive = true
            
            rightHeaderStack.addArrangedSubview(label)
        }
    }
    
    func configure(with data: ScorecardData) {
        let oldData = scorecardData
        let hasChanges = data != oldData
        
        let oldLeftCount = leftCollectionView.numberOfItems(inSection: 0)
        let oldRightCount = rightCollectionView.numberOfItems(inSection: 0)
        let oldColumns = dataSource.columnLayout.totalColumns
        
        self.scorecardData = data
        dataSource.scorecardData = data
        applyColumnLayout(for: data)
        
        updateNameColumnWidth()
        updateHeaderLabels()
        updateContentWidth()
        
        if hasChanges {
            let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
            let newLeftCount = lineup.count + 1
            let newRightCount = newLeftCount * dataSource.columnLayout.totalColumns
            let structureChanged = oldLeftCount != newLeftCount || oldRightCount != newRightCount || oldColumns != dataSource.columnLayout.totalColumns
            
            if structureChanged {
                leftCollectionView.reloadData()
                rightCollectionView.reloadData()
            } else {
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
        dataSource.isHomeTeam = isHome
        applyColumnLayout(for: scorecardData)
        
        updateNameColumnWidth()
        updateHeaderLabels()
        updateContentWidth()
        leftCollectionView.reloadData()
        rightCollectionView.reloadData()
        invalidateIntrinsicContentSize()
    }

    private func updateNameColumnWidth() {
        let newWidth = layoutEngine.computeNameWidth(data: scorecardData, isHomeTeam: isHomeTeam)
        guard newWidth != nameWidth else { return }
        nameWidth = newWidth
        dataSource.nameWidth = newWidth
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
        
        let h = visible ? headerHeight : 0
        headerHeightConstraint?.constant = h
        rightHeaderHeightConstraint?.constant = h
        
        invalidateIntrinsicContentSize()
    }
    
    func setCompact(_ compact: Bool) {
        guard compact != isCompact else { return }
        isCompact = compact
        dataSource.isCompact = compact
        applyColumnLayout(for: scorecardData)
        updateNameColumnWidth()
        updateHeaderLabels()
        updateContentWidth()
        leftCollectionView.reloadData()
        rightCollectionView.reloadData()
        invalidateIntrinsicContentSize()
    }

    private func applyColumnLayout(for data: ScorecardData?) {
        if isCompact {
            let compact = layoutEngine.computeCompactColumnLayout(data: data, isHomeTeam: isHomeTeam)
            dataSource.columnLayout = compact.columnLayout
            dataSource.compactColumns = compact.columns
            compactColumns = compact.columns
        } else {
            let newColumnLayout = layoutEngine.computeColumnLayout(data: data, isHomeTeam: isHomeTeam)
            dataSource.columnLayout = newColumnLayout
            dataSource.compactColumns = []
            compactColumns = []
        }
    }

    func setIsLive(_ live: Bool) {
        let changed = self.isLive != live
        self.isLive = live
        dataSource.isLive = live
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
        guard let batter = lineup.first(where: { $0.id == batterId }) else { return }

        let colIndex: Int
        if isCompact {
            let allPAs = layoutEngine.compactPlateAppearancesBySlot(data: data, lineup: lineup, isHomeTeam: isHomeTeam)
            let batterSlot = batter.battingOrderSlot ?? 0
            let batterPAs = allPAs[batterSlot] ?? [:]
            if let livePA = batterPAs.first(where: { $0.value.result.isLive })?.key {
                colIndex = livePA
            } else {
                colIndex = (batterPAs.keys.max() ?? -1) + 1
            }
        } else {
            guard let inningLayout = dataSource.columnLayout.layout(forInning: inningNum) else { return }
            colIndex = inningLayout.startColumn + inningLayout.subColumnCount - 1
        }

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

    var currentColumnLayout: ColumnLayout { dataSource.columnLayout }
    var currentCompactColumns: [CompactColumn] { compactColumns }
    var currentIsCompact: Bool { isCompact }
    var currentNameWidth: CGFloat { nameWidth }

    private func isViewingCurrentBattingTeam(_ data: ScorecardData) -> Bool {
        (data.isTopInning == true && !isHomeTeam) || (data.isTopInning == false && isHomeTeam)
    }

    override var intrinsicContentSize: CGSize {
        guard let data = scorecardData else { return CGSize(width: UIView.noIntrinsicMetric, height: 200) }
        let lineupCount = isHomeTeam ? data.lineups.home.count : data.lineups.away.count
        let h = areHeadersVisible ? headerHeight : 0
        let totalHeight = h + (CGFloat(lineupCount + 1) * rowHeight)
        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }
}
