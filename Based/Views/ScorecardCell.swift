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
        let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        let bodyFont = "PatrickHand-Regular"
        let headerFont = "PermanentMarker-Regular"
        
        [resultLabel, ballsLabel, strikesLabel, outsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont(name: bodyFont, size: 12) ?? .systemFont(ofSize: 12)
            $0.textColor = pencilColor
            $0.textAlignment = .center
            contentView.addSubview($0)
        }
        
        resultLabel.font = UIFont(name: headerFont, size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        
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
        guard let event = event else {
            resultLabel.text = ""
            ballsLabel.text = ""
            strikesLabel.text = ""
            outsLabel.text = ""
            // Pass empty bases to clear diamond
            diamondView.configure(with: BasesReached(first: false, second: false, third: false, home: false, outAtFirst: false, outAtSecond: false, outAtThird: false, outAtHome: false), style: .scorecard)
            diamondView.alpha = 0.3 // Make it faint when empty
            return
        }
        
        diamondView.alpha = 1.0
        resultLabel.text = event.result
        ballsLabel.text = "\(event.balls)B"
        strikesLabel.text = "\(event.strikes)S"
        outsLabel.text = event.outs > 0 ? "\(event.outs)" : ""
        
        diamondView.configure(with: event.bases, style: .scorecard, isRun: event.result == "HR")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        resultLabel.text = ""
        ballsLabel.text = ""
        strikesLabel.text = ""
        outsLabel.text = ""
        diamondView.configure(with: BasesReached(first: false, second: false, third: false, home: false, outAtFirst: false, outAtSecond: false, outAtThird: false, outAtHome: false), style: .scorecard, isRun: false)
        diamondView.alpha = 1.0
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = UIColor(white: 0.6, alpha: 0.5).cgColor
    }
}
