import UIKit

protocol ScorecardViewDelegate: AnyObject {
    func didSelectAtBat(_ event: AtBatEvent, batter: ScorecardBatter, pitcherName: String)
    func didSelectPlayer(_ batter: ScorecardBatter)
}

class ScorecardView: UIView {
    
    weak var delegate: ScorecardViewDelegate?
    
    // MARK: - UI Components
    private let topLeftLabel: UILabel = {
        let label = UILabel()
        label.text = "BATTER"
        label.font = UIFont(name: "PermanentMarker-Regular", size: 14) ?? .systemFont(ofSize: 14, weight: .bold)
        label.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        label.textAlignment = .center
        label.backgroundColor = UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1.0)
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
    
    // Data
    private var scorecardData: ScorecardData?
    private var isHomeTeam = false
    private var areHeadersVisible = true
    
    // Constants
    private let nameWidth: CGFloat = 90
    private let inningWidth: CGFloat = 60
    private let headerHeight: CGFloat = 32
    private let rowHeight: CGFloat = 70
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupCollectionViews()
        backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)
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
        rightHeaderStack.distribution = .fillEqually
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
        rightCollectionView.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.addSubview(rightCollectionView)
        
        headerHeightConstraint = topLeftLabel.heightAnchor.constraint(equalToConstant: headerHeight)
        leftTopConstraint = leftCollectionView.topAnchor.constraint(equalTo: topLeftLabel.bottomAnchor)
        rightTopConstraint = rightCollectionView.topAnchor.constraint(equalTo: rightHeaderStack.bottomAnchor)
        
        NSLayoutConstraint.activate([
            topLeftLabel.topAnchor.constraint(equalTo: topAnchor),
            topLeftLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            topLeftLabel.widthAnchor.constraint(equalToConstant: nameWidth),
            headerHeightConstraint!,
            
            leftTopConstraint!,
            leftCollectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            leftCollectionView.widthAnchor.constraint(equalToConstant: nameWidth),
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
        
        updateContentWidth(inningCount: 9)
    }

    private var rightContentWidthConstraint: NSLayoutConstraint?
    private func updateContentWidth(inningCount: Int) {
        rightContentWidthConstraint?.isActive = false
        rightContentWidthConstraint = rightCollectionView.widthAnchor.constraint(equalToConstant: inningWidth * CGFloat(inningCount))
        rightContentWidthConstraint?.isActive = true
        rightHeaderStack.widthAnchor.constraint(equalTo: rightCollectionView.widthAnchor).isActive = true
    }
    
    private func setupCollectionViews() {
        leftCollectionView.dataSource = self
        leftCollectionView.delegate = self
        rightCollectionView.dataSource = self
        rightCollectionView.delegate = self
        rightScrollView.delegate = self // CRITICAL: Fixes scroll sync
        updateHeaderLabels(inningCount: 9)
    }

    private func updateHeaderLabels(inningCount: Int) {
        rightHeaderStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        for i in 1...inningCount {
            let label = UILabel()
            label.text = "\(i)"
            label.textAlignment = .center
            label.font = UIFont(name: "PermanentMarker-Regular", size: 14) ?? .systemFont(ofSize: 14, weight: .bold)
            label.textColor = pencilColor
            label.backgroundColor = UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1.0)
            label.layer.borderWidth = 0.5
            label.layer.borderColor = UIColor(white: 0.6, alpha: 0.5).cgColor
            rightHeaderStack.addArrangedSubview(label)
        }
    }
    
    func configure(with data: ScorecardData) {
        self.scorecardData = data
        let inningCount = max(data.innings.count, 9)
        updateHeaderLabels(inningCount: inningCount)
        updateContentWidth(inningCount: inningCount)
        leftCollectionView.reloadData()
        rightCollectionView.reloadData()
        invalidateIntrinsicContentSize()
    }
    
    func setTeam(isHome: Bool) {
        self.isHomeTeam = isHome
        leftCollectionView.reloadData()
        rightCollectionView.reloadData()
        invalidateIntrinsicContentSize()
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
    
    func scrollToActiveCell() {
        guard let data = scorecardData,
              let inningNum = data.currentInning,
              let batterId = data.currentBatterId,
              let isTop = data.isTopInning else { return }
        
        // Determine if we are looking at the team currently at bat
        let viewingTeamAtBat = (isTop && !isHomeTeam) || (!isTop && isHomeTeam)
        if !viewingTeamAtBat { return }
        
        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        guard lineup.firstIndex(where: { $0.id == batterId }) != nil else { return }
        
        let colIndex = inningNum - 1
        
        // Horizontal Scroll
        let hOffset = max(0, CGFloat(colIndex) * inningWidth - (rightScrollView.bounds.width / 2) + (inningWidth / 2))
        let maxHOffset = max(0, rightScrollView.contentSize.width - rightScrollView.bounds.width)
        syncHorizontalOffset(min(hOffset, maxHOffset))
        
        // Vertical Scroll (This is a bit tricky since ScorecardView is inside a mainStackView/mainScrollView)
        // We need to notify the controller to scroll the mainScrollView
    }

    var currentHorizontalOffset: CGFloat {
        return rightScrollView.contentOffset.x
    }

    var horizontalScrollCallback: ((CGFloat) -> Void)?

    func syncHorizontalOffset(_ offset: CGFloat) {
        rightScrollView.contentOffset.x = offset
    }

    override var intrinsicContentSize: CGSize {
        guard let data = scorecardData else { return CGSize(width: UIView.noIntrinsicMetric, height: 200) }
        let lineupCount = isHomeTeam ? data.lineups.home.count : data.lineups.away.count
        let h = areHeadersVisible ? headerHeight : 0
        let totalHeight = h + (CGFloat(lineupCount) * rowHeight)
        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }
}

extension ScorecardView: UICollectionViewDataSource, UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == rightScrollView {
            horizontalScrollCallback?(scrollView.contentOffset.x)
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let data = scorecardData else { return 0 }
        let lineupCount = isHomeTeam ? data.lineups.home.count : data.lineups.away.count
        let inningCount = max(data.innings.count, 9)
        return collectionView == leftCollectionView ? lineupCount : lineupCount * inningCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let data = scorecardData else { return UICollectionViewCell() }
        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        let inningCount = max(data.innings.count, 9)
        let rowIndex = (collectionView == leftCollectionView) ? indexPath.item : indexPath.item / inningCount
        
        if rowIndex >= lineup.count { return UICollectionViewCell() }
        let batter = lineup[rowIndex]
        let rowBackgroundColor = rowIndex % 2 == 0 ? UIColor.clear : UIColor(red: 0.95, green: 0.95, blue: 0.9, alpha: 0.3)
        
        if collectionView == leftCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NameCell", for: indexPath) as! LabelCell
            let nameAttrs: [NSAttributedString.Key: Any] = [.font: UIFont(name: "PatrickHand-Regular", size: 18) ?? .systemFont(ofSize: 18), .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)]
            let posAttrs: [NSAttributedString.Key: Any] = [.font: UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14), .foregroundColor: UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)]
            
            let text = NSMutableAttributedString(string: "\(batter.abbreviation)\n", attributes: nameAttrs)
            var posText = batter.position
            if let entryInning = batter.inningEntered { posText += " (\(entryInning))" }
            text.append(NSAttributedString(string: posText, attributes: posAttrs))
            
            cell.label.attributedText = text
            cell.label.textAlignment = .center
            cell.backgroundColor = rowBackgroundColor
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ScorecardCell.reuseIdentifier, for: indexPath) as! ScorecardCell
            let col = indexPath.item % inningCount
            let inningNum = col + 1
            let inningObj = data.innings.first { $0.num == inningNum }
            let events = isHomeTeam ? inningObj?.home : inningObj?.away
            let event = events?.first { $0.batterId == batter.id }
            
            let isBeforeEntry = inningNum < (batter.inningEntered ?? 1)
            let isAfterExit = batter.inningExited != nil && inningNum > (batter.inningExited ?? 99)
            
            if isBeforeEntry || isAfterExit {
                cell.backgroundColor = UIColor(white: 0.9, alpha: 0.6)
            } else {
                cell.backgroundColor = rowBackgroundColor
            }
            
            // Highlight current active cell
            let isCurrentInning = data.currentInning == inningNum
            let isCurrentHalf = data.isTopInning == !isHomeTeam
            let isCurrentBatter = data.currentBatterId == batter.id
            
            if isCurrentInning && isCurrentHalf && isCurrentBatter {
                cell.contentView.layer.borderWidth = 3.0
                cell.contentView.layer.borderColor = UIColor.systemBlue.cgColor
                cell.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
            } else {
                cell.contentView.layer.borderWidth = 0.5
                cell.contentView.layer.borderColor = UIColor(white: 0.6, alpha: 0.5).cgColor
            }
            
            cell.configure(with: event)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let data = scorecardData else { return }
        let lineup = isHomeTeam ? data.lineups.home : data.lineups.away
        let inningCount = max(data.innings.count, 9)
        let rowIndex = (collectionView == leftCollectionView) ? indexPath.item : indexPath.item / inningCount
        if rowIndex >= lineup.count { return }
        let batter = lineup[rowIndex]
        
        if collectionView == leftCollectionView {
            delegate?.didSelectPlayer(batter)
        } else {
            let col = indexPath.item % inningCount
            let inningNum = col + 1
            let inningObj = data.innings.first { $0.num == inningNum }
            let events = isHomeTeam ? inningObj?.home : inningObj?.away
            if let event = events?.first(where: { $0.batterId == batter.id }) {
                delegate?.didSelectAtBat(event, batter: batter, pitcherName: "Pitcher")
            }
        }
    }
}
