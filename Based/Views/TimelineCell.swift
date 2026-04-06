import UIKit

class TimelineCell: UITableViewCell {
    static let identifier = "TimelineCell"
    
    private let pitchTrackView = PitchTrackView()
    private let diamondView = DiamondView()
    private let resultLabel = UILabel()
    private let ballsLabel = UILabel()
    private let strikesLabel = UILabel()
    private let outsLabel = UILabel()
    
    private let infoStack = UIStackView()
    private let batterLabel = UILabel()
    private let pitcherLabel = UILabel()
    private let descriptionLabel = UILabel()
    
    private let leftContainer = UIStackView()
    private let diamondContainer = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        pitchTrackView.displayStyle = .compact
        
        leftContainer.axis = .vertical
        leftContainer.spacing = 12
        leftContainer.alignment = .center
        leftContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(leftContainer)
        
        pitchTrackView.translatesAutoresizingMaskIntoConstraints = false
        diamondContainer.translatesAutoresizingMaskIntoConstraints = false
        diamondView.translatesAutoresizingMaskIntoConstraints = false
        
        leftContainer.addArrangedSubview(pitchTrackView)
        leftContainer.addArrangedSubview(diamondContainer)
        diamondContainer.addSubview(diamondView)
        
        // Diamond Labels
        let pencilColor = AppColors.pencil
        let dataFont = "PermanentMarker-Regular"
        let legibilityFont = "PatrickHand-Regular"
        
        resultLabel.font = UIFont(name: dataFont, size: 20) ?? .systemFont(ofSize: 20, weight: .bold)
        resultLabel.textColor = pencilColor
        resultLabel.textAlignment = .center
        resultLabel.numberOfLines = 0
        resultLabel.adjustsFontSizeToFitWidth = true
        resultLabel.minimumScaleFactor = 0.5
        
        [ballsLabel, strikesLabel, outsLabel].forEach {
            $0.font = UIFont(name: legibilityFont, size: 12) ?? .systemFont(ofSize: 12)
            $0.textColor = pencilColor
            $0.textAlignment = .center
        }
        
        [resultLabel, ballsLabel, strikesLabel, outsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            diamondContainer.addSubview($0)
        }
        
        infoStack.axis = .vertical
        infoStack.spacing = 2
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(infoStack)
        
        batterLabel.font = UIFont(name: "PermanentMarker-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
        batterLabel.textColor = AppColors.pencil
        
        pitcherLabel.font = UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14)
        pitcherLabel.textColor = AppColors.pencil.withAlphaComponent(0.7)
        
        descriptionLabel.font = UIFont(name: "PatrickHand-Regular", size: 15) ?? .systemFont(ofSize: 15)
        descriptionLabel.textColor = AppColors.pencil
        descriptionLabel.numberOfLines = 0
        
        infoStack.addArrangedSubview(batterLabel)
        infoStack.addArrangedSubview(pitcherLabel)
        infoStack.addArrangedSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            leftContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            leftContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            leftContainer.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
            leftContainer.widthAnchor.constraint(equalToConstant: 88),
            
            pitchTrackView.widthAnchor.constraint(equalToConstant: 78),
            pitchTrackView.heightAnchor.constraint(equalToConstant: 92),
            
            diamondContainer.widthAnchor.constraint(equalToConstant: 88),
            diamondContainer.heightAnchor.constraint(equalToConstant: 80),
            
            diamondView.centerXAnchor.constraint(equalTo: diamondContainer.centerXAnchor),
            diamondView.centerYAnchor.constraint(equalTo: diamondContainer.centerYAnchor),
            diamondView.widthAnchor.constraint(equalTo: diamondContainer.widthAnchor),
            diamondView.heightAnchor.constraint(equalTo: diamondContainer.heightAnchor),
            
            resultLabel.centerXAnchor.constraint(equalTo: diamondView.centerXAnchor),
            resultLabel.centerYAnchor.constraint(equalTo: diamondView.centerYAnchor),
            resultLabel.widthAnchor.constraint(equalTo: diamondView.widthAnchor, multiplier: 0.6),
            
            ballsLabel.topAnchor.constraint(equalTo: diamondContainer.topAnchor, constant: 4),
            ballsLabel.leadingAnchor.constraint(equalTo: diamondContainer.leadingAnchor, constant: 4),
            
            strikesLabel.topAnchor.constraint(equalTo: diamondContainer.topAnchor, constant: 4),
            strikesLabel.trailingAnchor.constraint(equalTo: diamondContainer.trailingAnchor, constant: -4),
            
            outsLabel.bottomAnchor.constraint(equalTo: diamondContainer.bottomAnchor, constant: -4),
            outsLabel.trailingAnchor.constraint(equalTo: diamondContainer.trailingAnchor, constant: -4),
            
            infoStack.leadingAnchor.constraint(equalTo: leftContainer.trailingAnchor, constant: 16),
            infoStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            infoStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            infoStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with event: AtBatEvent) {
        pitchTrackView.configure(with: event.pitches ?? [])
        diamondView.configure(with: event.bases, style: .scorecard, isRun: event.result == "HR")
        
        let isCalledK = event.result == "Ʞ"
        let displayResult = isCalledK ? "K" : event.result
        resultLabel.text = displayResult
        resultLabel.transform = isCalledK ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        
        ballsLabel.text = "\(event.balls)B"
        strikesLabel.text = "\(event.strikes)S"
        outsLabel.text = event.outs > 0 ? "\(event.outs)" : ""
        
        batterLabel.text = event.batterName.uppercased()
        pitcherLabel.text = "vs \(event.pitcherName)"
        
        descriptionLabel.text = event.description
    }
}
