import UIKit

class ScorecardCell: UICollectionViewCell {
    static let reuseIdentifier = "ScorecardCell"
    
    // UI Components
    private let diamondView = DiamondView()
    private let resultLabel = UILabel()
    private let ballsLabel = UILabel()
    private let strikesLabel = UILabel()
    private let outsLabel = UILabel()
    private var accentColor: UIColor = AppColors.pencil
    
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
        
        // Constraints — inset the diamond slightly so corner labels have breathing room
        NSLayoutConstraint.activate([
            diamondView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            diamondView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            diamondView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            diamondView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            resultLabel.centerXAnchor.constraint(equalTo: diamondView.centerXAnchor),
            resultLabel.centerYAnchor.constraint(equalTo: diamondView.centerYAnchor),
            
            ballsLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            ballsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            
            strikesLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            strikesLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            
            outsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            outsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2)
        ])
    }
    
    func configure(with event: AtBatEvent?) {
        guard let event = event, event.result != "LIVE" else {
            resultLabel.text = ""
            resultLabel.attributedText = nil
            resultLabel.textColor = AppColors.pencil
            ballsLabel.text = ""
            ballsLabel.textColor = AppColors.pencil
            strikesLabel.text = ""
            strikesLabel.textColor = AppColors.pencil
            outsLabel.text = ""
            outsLabel.textColor = AppColors.pencil
            // Pass empty bases to clear diamond
            diamondView.configure(with: BasesReached(first: false, second: false, third: false, home: false, outAtFirst: false, outAtSecond: false, outAtThird: false, outAtHome: false, annotations: nil), style: .scorecard)
            diamondView.alpha = 0.3 // Make it faint when empty
            return
        }
        
        diamondView.alpha = 1.0
        let presentation = AtBatPresentation(event: event, teamAccentColor: accentColor)
        resultLabel.textColor = presentation.primaryColor
        ballsLabel.textColor = presentation.primaryColor
        strikesLabel.textColor = presentation.primaryColor
        outsLabel.textColor = presentation.primaryColor
        resultLabel.attributedText = presentation.resultAttributedString(
            font: resultLabel.font ?? .systemFont(ofSize: 18)
        )
        resultLabel.transform = presentation.resultTransform
        
        ballsLabel.text = presentation.ballsText
        strikesLabel.text = presentation.strikesText
        outsLabel.text = presentation.outsText
        
        diamondView.configure(
            with: event.bases,
            style: presentation.diamondStyle,
            isRun: event.result == "HR",
            accentColor: presentation.diamondAccentColor
        )
    }

    func setAccentColor(_ color: UIColor) {
        accentColor = color
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        resultLabel.transform = .identity
        resultLabel.text = ""
        resultLabel.textColor = AppColors.pencil
        ballsLabel.text = ""
        ballsLabel.textColor = AppColors.pencil
        strikesLabel.text = ""
        strikesLabel.textColor = AppColors.pencil
        outsLabel.text = ""
        outsLabel.textColor = AppColors.pencil
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
