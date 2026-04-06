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
    private let teamStatusLabel = UILabel()
    private let weatherLabel = UILabel()
    
    // Graphics
    private let linesLayer = CAShapeLayer()
    private let topSeparatorLayer = CAShapeLayer()
    
    var tapAction: (() -> Void)?
    var longPressAction: (() -> Void)?
    
    // Constants
    private let paperColor = AppColors.paper
    private var pencilColor: UIColor { AppColors.pencil }
    private let headerFont = "PermanentMarker-Regular"
    private let bodyFont = "PatrickHand-Regular"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        
        let long = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        addGestureRecognizer(long)
    }
    
    @objc private func handleTap() {
        tapAction?()
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            longPressAction?()
        }
    }
    
    private func setupUI() {
        backgroundColor = paperColor
        pitchTrackView.displayStyle = .compact
        
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

        inningLabel.font = UIFont(name: bodyFont, size: 14) ?? .systemFont(ofSize: 14, weight: .bold)
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

        teamStatusLabel.font = UIFont(name: bodyFont, size: 12) ?? .systemFont(ofSize: 12)
        teamStatusLabel.textColor = pencilColor.withAlphaComponent(0.6)
        teamStatusLabel.textAlignment = .left

        weatherLabel.font = UIFont(name: bodyFont, size: 13) ?? .systemFont(ofSize: 13)
        weatherLabel.textColor = pencilColor.withAlphaComponent(0.6)
        weatherLabel.textAlignment = .left
        weatherLabel.numberOfLines = 1
        weatherLabel.adjustsFontSizeToFitWidth = true
        weatherLabel.minimumScaleFactor = 0.7

        // Add Subviews
        [diamondView, pitchTrackView, inningContainer, countLabel, batterLabel, pitcherLabel, pitchCountLabel, teamStatusLabel, weatherLabel].forEach {
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

            // Col 2: Strike Zone (Center)
            pitchTrackView.leadingAnchor.constraint(equalTo: diamondView.trailingAnchor, constant: 8),
            pitchTrackView.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 4),
            pitchTrackView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -4),
            pitchTrackView.widthAnchor.constraint(equalToConstant: 82),

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
            pitchCountLabel.trailingAnchor.constraint(equalTo: batterLabel.trailingAnchor),

            teamStatusLabel.topAnchor.constraint(equalTo: pitchCountLabel.bottomAnchor, constant: 2),
            teamStatusLabel.leadingAnchor.constraint(equalTo: batterLabel.leadingAnchor),
            teamStatusLabel.trailingAnchor.constraint(equalTo: batterLabel.trailingAnchor),

            weatherLabel.topAnchor.constraint(equalTo: teamStatusLabel.bottomAnchor, constant: 2),
            weatherLabel.leadingAnchor.constraint(equalTo: batterLabel.leadingAnchor),
            weatherLabel.trailingAnchor.constraint(equalTo: batterLabel.trailingAnchor)
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
        
        // Vertical dividers follow the actual subview layout so compact sizing stays aligned.
        let div1X = diamondView.frame.maxX + 7
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: div1X, y: 0), to: CGPoint(x: div1X, y: b.height)))

        let div2X = pitchTrackView.frame.maxX + 4
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: div2X, y: 0), to: CGPoint(x: div2X, y: b.height)))
        
        linesLayer.path = path.cgPath
        linesLayer.strokeColor = pencilColor.cgColor
        linesLayer.lineWidth = 1.2
        linesLayer.fillColor = UIColor.clear.cgColor
    }
    
    func configure(with linescore: Linescore, pitches: [PitchEvent]? = nil, gameData: GameData? = nil) {
        let state = linescore.inningState?.lowercased() ?? "---"
        let isBreak = state == "mid" || state == "end"
        
        let outs = linescore.outs ?? 0
        let outsText = outs == 1 ? "OUT" : "OUTS"
        let ordinal = linescore.currentInningOrdinal?.uppercased() ?? "---"
        let side = linescore.inningHalf?.uppercased() ?? ""
        
        inningLabel.text = "\(side) \(ordinal) • \(outs) \(outsText)"
        
        if isBreak {
            batterLabel.text = ""
            pitcherLabel.text = ""
            countLabel.text = ""
            pitchCountLabel.text = ""
            teamStatusLabel.text = ""
            weatherLabel.text = ""
        } else {
            batterLabel.text = linescore.offense?.batter?.fullName?.uppercased() ?? "---"
            pitcherLabel.text = "vs \(linescore.defense?.pitcher?.fullName ?? "---")"
            countLabel.text = "\(linescore.balls ?? 0)-\(linescore.strikes ?? 0)"
            
            if let count = linescore.currentPitchCount {
                pitchCountLabel.text = "\(count) pitches"
            } else {
                pitchCountLabel.text = ""
            }
            
            // Extract MVR and Challenges from gameData (live feed)
            let isTop = linescore.isTopInning ?? true
            var statusParts: [String] = []
            
            if let gameData = gameData {
                let mvr = isTop ? (gameData.moundVisits?.home?.remaining ?? 0) : (gameData.moundVisits?.away?.remaining ?? 0)
                let homeChl = gameData.absChallenges?.home?.remaining ?? 0
                let awayChl = gameData.absChallenges?.away?.remaining ?? 0
                statusParts.append("MVR: \(mvr)")
                statusParts.append("CHL: H\(homeChl) A\(awayChl)")
            }
            
            teamStatusLabel.text = statusParts.joined(separator: " • ")
            
            // Weather and wind on dedicated row
            var weatherParts: [String] = []
            if let weather = gameData?.weather {
                if let temp = weather.temp, let cond = weather.condition {
                    weatherParts.append("\(temp)° \(cond)")
                }
                if let wind = weather.wind {
                    weatherParts.append(wind)
                }
            }
            weatherLabel.text = weatherParts.isEmpty ? "" : weatherParts.joined(separator: " • ")
        }
        
        let bases = BasesReached(
            first: linescore.offense?.first != nil,
            second: linescore.offense?.second != nil,
            third: linescore.offense?.third != nil,
            home: false,
            outAtFirst: false,
            outAtSecond: false,
            outAtThird: false,
            outAtHome: false,
            annotations: nil
        )
        diamondView.configure(with: bases, style: .liveStatus, isRun: false)
        
        if isBreak {
            pitchTrackView.configure(with: [])
        } else if let providedPitches = pitches, !providedPitches.isEmpty {
            pitchTrackView.configure(with: providedPitches)
        } else if let linescorePitches = linescore.currentPitches {
            pitchTrackView.configure(with: linescorePitches)
        } else {
            pitchTrackView.configure(with: [])
        }
    }
}
