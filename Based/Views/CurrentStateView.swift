import UIKit

class CurrentStateView: UIView {
    
    // MARK: - UI Elements
    private let contentContainer = UIView()
    
    // Column 1: Diamond & Count (Left)
    private let diamondView = DiamondView()
    private let countLabel = UILabel()
    
    // Column 2: Strike Zone (Center)
    private let pitchTrackView = PitchTrackView()
    
    // Column 3: Stats (Right)
    private let inningContainer = UIView()
    private let inningLabel = UILabel()
    private let batterLabel = UILabel()
    private let pitcherLabel = UILabel()
    private let pitchCountLabel = UILabel()
    
    // Graphics
    private let linesLayer = CAShapeLayer()
    private let topSeparatorLayer = CAShapeLayer()
    
    // Constants
    private let paperColor = UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)
    private let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
    private let headerFont = "PermanentMarker-Regular"
    private let bodyFont = "PatrickHand-Regular"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = paperColor
        
        addSubview(contentContainer)
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        
        contentContainer.layer.addSublayer(linesLayer)
        layer.addSublayer(topSeparatorLayer)
        topSeparatorLayer.strokeColor = pencilColor.cgColor
        topSeparatorLayer.lineWidth = 2.0
        
        // --- Configure Views ---
        
        // Left Column
        countLabel.font = UIFont(name: headerFont, size: 22) ?? .systemFont(ofSize: 22, weight: .bold)
        countLabel.textColor = pencilColor
        countLabel.textAlignment = .center
        
        // Right Column - Inning header with shading
        inningContainer.backgroundColor = pencilColor.withAlphaComponent(0.08)
        inningContainer.layer.cornerRadius = 4

        inningLabel.font = UIFont(name: headerFont, size: 12) ?? .systemFont(ofSize: 12, weight: .bold)
        inningLabel.textColor = pencilColor.withAlphaComponent(0.9)
        inningLabel.textAlignment = .center

        batterLabel.font = UIFont(name: headerFont, size: 20) ?? .systemFont(ofSize: 20, weight: .bold)
        batterLabel.textColor = pencilColor
        batterLabel.textAlignment = .left
        batterLabel.numberOfLines = 1
        batterLabel.adjustsFontSizeToFitWidth = true
        batterLabel.minimumScaleFactor = 0.6

        pitcherLabel.font = UIFont(name: bodyFont, size: 16) ?? .systemFont(ofSize: 16)
        pitcherLabel.textColor = pencilColor.withAlphaComponent(0.8)
        pitcherLabel.textAlignment = .left

        pitchCountLabel.font = UIFont(name: bodyFont, size: 13) ?? .systemFont(ofSize: 13)
        pitchCountLabel.textColor = pencilColor.withAlphaComponent(0.5)
        pitchCountLabel.textAlignment = .left

        // Add Subviews
        [diamondView, pitchTrackView, inningContainer, countLabel, batterLabel, pitcherLabel, pitchCountLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview($0)
        }

        inningLabel.translatesAutoresizingMaskIntoConstraints = false
        inningContainer.addSubview(inningLabel)
        
        // --- Constraints ---
        
        NSLayoutConstraint.activate([
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            contentContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -4),
            contentContainer.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            
            // Col 1: Diamond & Count (Left ~100pts)
            diamondView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 8),
            diamondView.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 8),
            diamondView.widthAnchor.constraint(equalToConstant: 85),
            diamondView.heightAnchor.constraint(equalToConstant: 85),

            countLabel.topAnchor.constraint(equalTo: diamondView.bottomAnchor, constant: 2),
            countLabel.centerXAnchor.constraint(equalTo: diamondView.centerXAnchor),
            countLabel.widthAnchor.constraint(equalTo: diamondView.widthAnchor),

            // Col 2: Strike Zone (Center ~70pts, narrower)
            pitchTrackView.leadingAnchor.constraint(equalTo: diamondView.trailingAnchor, constant: 8),
            pitchTrackView.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 4),
            pitchTrackView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -4),
            pitchTrackView.widthAnchor.constraint(equalToConstant: 70),

            // Col 3: Stats (Right - improved layout)
            // Inning header with shading
            inningContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            inningContainer.leadingAnchor.constraint(equalTo: pitchTrackView.trailingAnchor, constant: 8),
            inningContainer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),

            inningLabel.topAnchor.constraint(equalTo: inningContainer.topAnchor, constant: 6),
            inningLabel.bottomAnchor.constraint(equalTo: inningContainer.bottomAnchor, constant: -6),
            inningLabel.leadingAnchor.constraint(equalTo: inningContainer.leadingAnchor, constant: 8),
            inningLabel.trailingAnchor.constraint(equalTo: inningContainer.trailingAnchor, constant: -8),

            batterLabel.topAnchor.constraint(equalTo: inningContainer.bottomAnchor, constant: 8),
            batterLabel.leadingAnchor.constraint(equalTo: inningContainer.leadingAnchor, constant: 8),
            batterLabel.trailingAnchor.constraint(equalTo: inningContainer.trailingAnchor, constant: -8),

            pitcherLabel.topAnchor.constraint(equalTo: batterLabel.bottomAnchor, constant: 2),
            pitcherLabel.leadingAnchor.constraint(equalTo: batterLabel.leadingAnchor),
            pitcherLabel.trailingAnchor.constraint(equalTo: batterLabel.trailingAnchor),

            pitchCountLabel.topAnchor.constraint(equalTo: pitcherLabel.bottomAnchor, constant: 2),
            pitchCountLabel.leadingAnchor.constraint(equalTo: batterLabel.leadingAnchor),
            pitchCountLabel.trailingAnchor.constraint(equalTo: batterLabel.trailingAnchor)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentContainer.layoutIfNeeded()
        
        let fullWidth = bounds.width
        topSeparatorLayer.path = UIBezierPath.pencilLine(from: CGPoint(x: 0, y: 0), to: CGPoint(x: fullWidth, y: 0)).cgPath
        
        drawLayoutLines()
    }
    
    private func drawLayoutLines() {
        let b = contentContainer.bounds
        let path = UIBezierPath()
        
        // Outer Box
        path.append(UIBezierPath.pencilLine(from: .zero, to: CGPoint(x: b.width, y: 0)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: b.width, y: 0), to: CGPoint(x: b.width, y: b.height)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: b.width, y: b.height), to: CGPoint(x: 0, y: b.height)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: b.height), to: .zero))
        
        // Vertical Dividers
        // Left Column Width ~ 100 (diamond 85 + padding)
        let div1X: CGFloat = 100
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: div1X, y: 0), to: CGPoint(x: div1X, y: b.height)))

        // Divider after center column (left col + center col width)
        let div2X: CGFloat = 100 + 78 // Left column + center column (70 + padding)
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: div2X, y: 0), to: CGPoint(x: div2X, y: b.height)))
        
        linesLayer.path = path.cgPath
        linesLayer.strokeColor = pencilColor.cgColor
        linesLayer.lineWidth = 1.2
        linesLayer.fillColor = UIColor.clear.cgColor
    }
    
    func configure(with linescore: Linescore, pitches: [PitchEvent]? = nil) {
        let outs = linescore.outs ?? 0
        let outsText = outs == 1 ? "OUT" : "OUTS"
        let state = linescore.inningState?.uppercased() ?? "---"
        let ordinal = linescore.currentInningOrdinal?.uppercased() ?? "---"
        
        inningLabel.text = "\(state) \(ordinal) • \(outs) \(outsText)"
        batterLabel.text = linescore.offense?.batter?.fullName?.uppercased() ?? "---"
        pitcherLabel.text = "vs \(linescore.defense?.pitcher?.fullName ?? "---")"
        countLabel.text = "\(linescore.balls ?? 0)-\(linescore.strikes ?? 0)"

        if let count = linescore.currentPitchCount {
            pitchCountLabel.text = "\(count) pitches"
        } else {
            pitchCountLabel.text = ""
        }
        
        let bases = BasesReached(
            first: linescore.offense?.first != nil,
            second: linescore.offense?.second != nil,
            third: linescore.offense?.third != nil,
            home: false,
            outAtFirst: false,
            outAtSecond: false,
            outAtThird: false,
            outAtHome: false
        )
        diamondView.configure(with: bases, style: .liveStatus)
        
        if let providedPitches = pitches, !providedPitches.isEmpty {
            pitchTrackView.configure(with: providedPitches)
        } else if let linescorePitches = linescore.currentPitches {
            pitchTrackView.configure(with: linescorePitches)
        } else {
            pitchTrackView.configure(with: [])
        }
    }
}
