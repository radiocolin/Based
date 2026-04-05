import UIKit

class ScorecardCell: UICollectionViewCell {
    static let reuseIdentifier = "ScorecardCell"
    
    // UI Components
    private let diamondView = DiamondView()
    private let resultLabel = UILabel()
    private let ballsLabel = UILabel()
    private let strikesLabel = UILabel()
    private let outsLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.backgroundColor = .clear
        
        // Add Diamond
        diamondView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(diamondView)
        
        // Add Labels
        let pencilColor = AppColors.pencil
        let dataFont = "PermanentMarker-Regular"
        let legibilityFont = "PatrickHand-Regular"
        
        [resultLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont(name: dataFont, size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
            $0.textColor = pencilColor
            $0.textAlignment = .center
            contentView.addSubview($0)
        }
        
        [ballsLabel, strikesLabel, outsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont(name: legibilityFont, size: 12) ?? .systemFont(ofSize: 12)
            $0.textColor = pencilColor
            $0.textAlignment = .center
            contentView.addSubview($0)
        }
        
        resultLabel.numberOfLines = 0
        resultLabel.adjustsFontSizeToFitWidth = true
        resultLabel.minimumScaleFactor = 0.5
        
        // Constraints
        NSLayoutConstraint.activate([
            diamondView.topAnchor.constraint(equalTo: contentView.topAnchor),
            diamondView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            diamondView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            diamondView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            resultLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            resultLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            ballsLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            ballsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            
            strikesLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            strikesLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            
            outsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            outsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4)
        ])
    }
    
    func configure(with event: AtBatEvent?) {
        guard let event = event, event.result != "LIVE" else {
            resultLabel.text = ""
            resultLabel.attributedText = nil
            ballsLabel.text = ""
            strikesLabel.text = ""
            outsLabel.text = ""
            // Pass empty bases to clear diamond
            diamondView.configure(with: BasesReached(first: false, second: false, third: false, home: false, outAtFirst: false, outAtSecond: false, outAtThird: false, outAtHome: false, annotations: nil), style: .scorecard)
            diamondView.alpha = 0.3 // Make it faint when empty
            return
        }
        
        diamondView.alpha = 1.0
        
        // Use attributed string to reduce line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 0.75
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .font: resultLabel.font ?? .systemFont(ofSize: 18)
        ]
        let isCalledK = event.result == "Ʞ"
        let displayResult = isCalledK ? "K" : event.result
        resultLabel.attributedText = NSAttributedString(string: displayResult, attributes: attributes)
        resultLabel.transform = isCalledK ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        
        ballsLabel.text = "\(event.balls)B"
        strikesLabel.text = "\(event.strikes)S"
        outsLabel.text = event.outs > 0 ? "\(event.outs)" : ""
        
        diamondView.configure(with: event.bases, style: .scorecard, isRun: event.result == "HR")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        resultLabel.transform = .identity
        resultLabel.text = ""
        ballsLabel.text = ""
        strikesLabel.text = ""
        outsLabel.text = ""
        diamondView.configure(with: BasesReached(first: false, second: false, third: false, home: false, outAtFirst: false, outAtSecond: false, outAtThird: false, outAtHome: false, annotations: nil), style: .scorecard, isRun: false)
        diamondView.alpha = 1.0
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = AppColors.grid.cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Refresh CGColor-based properties for dark mode changes
        if contentView.layer.borderWidth == 0.5 {
            contentView.layer.borderColor = AppColors.grid.cgColor
        }
    }
}
