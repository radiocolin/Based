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
    private var accentColor: UIColor = AppColors.pencil
    
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
        isAccessibilityElement = true
        accessibilityTraits = .button
        pitchTrackView.displayStyle = .compact
        pitchTrackView.isAccessibilityElement = false
        diamondView.isAccessibilityElement = false
        
        leftContainer.axis = .vertical
        leftContainer.spacing = 12
        leftContainer.alignment = .center
        leftContainer.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.isAccessibilityElement = false
        contentView.addSubview(leftContainer)
        
        pitchTrackView.translatesAutoresizingMaskIntoConstraints = false
        diamondContainer.translatesAutoresizingMaskIntoConstraints = false
        diamondContainer.isAccessibilityElement = false
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
            $0.isAccessibilityElement = false
            diamondContainer.addSubview($0)
        }
        
        infoStack.axis = .vertical
        infoStack.spacing = 2
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoStack.isAccessibilityElement = false
        contentView.addSubview(infoStack)
        
        batterLabel.font = UIFont(name: "PermanentMarker-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
        batterLabel.textColor = AppColors.pencil
        
        pitcherLabel.font = UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14)
        pitcherLabel.textColor = AppColors.pencil.withAlphaComponent(0.7)
        
        descriptionLabel.font = UIFont(name: "PatrickHand-Regular", size: 15) ?? .systemFont(ofSize: 15)
        descriptionLabel.textColor = AppColors.pencil
        descriptionLabel.numberOfLines = 0
        [batterLabel, pitcherLabel, descriptionLabel].forEach { $0.isAccessibilityElement = false }
        
        infoStack.addArrangedSubview(batterLabel)
        infoStack.addArrangedSubview(pitcherLabel)
        infoStack.addArrangedSubview(descriptionLabel)
        
        let infoTrailing = infoStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        infoTrailing.priority = UILayoutPriority(999)

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
            resultLabel.widthAnchor.constraint(equalTo: diamondView.widthAnchor, multiplier: 0.8),
            
            ballsLabel.topAnchor.constraint(equalTo: diamondContainer.topAnchor, constant: 4),
            ballsLabel.leadingAnchor.constraint(equalTo: diamondContainer.leadingAnchor, constant: 4),
            
            strikesLabel.topAnchor.constraint(equalTo: diamondContainer.topAnchor, constant: 4),
            strikesLabel.trailingAnchor.constraint(equalTo: diamondContainer.trailingAnchor, constant: -4),
            
            outsLabel.bottomAnchor.constraint(equalTo: diamondContainer.bottomAnchor, constant: -4),
            outsLabel.trailingAnchor.constraint(equalTo: diamondContainer.trailingAnchor, constant: -4),
            
            infoStack.leadingAnchor.constraint(equalTo: leftContainer.trailingAnchor, constant: 16),
            infoTrailing,
            infoStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            infoStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with event: AtBatEvent, accentColor: UIColor? = nil) {
        self.accentColor = accentColor ?? AppColors.pencil
        let presentation = AtBatPresentation(event: event, teamAccentColor: self.accentColor)

        pitchTrackView.configure(with: event.pitches ?? [])
        diamondView.configure(
            with: event.bases,
            style: presentation.diamondStyle,
            isRun: event.result == "HR",
            accentColor: presentation.diamondAccentColor
        )
        
        resultLabel.text = presentation.displayResult
        resultLabel.textColor = presentation.primaryColor
        resultLabel.transform = presentation.resultTransform
        
        ballsLabel.text = presentation.ballsText
        ballsLabel.textColor = presentation.primaryColor
        strikesLabel.text = presentation.strikesText
        strikesLabel.textColor = presentation.primaryColor
        outsLabel.text = presentation.outsText
        outsLabel.textColor = presentation.primaryColor
        
        batterLabel.text = event.batterName
        pitcherLabel.text = "vs \(event.pitcherName)"
        
        descriptionLabel.text = event.description
        accessibilityLabel = AccessibilitySupport.eventDescription(event, includeMatchup: true)
        accessibilityHint = "Double tap for at-bat details."
    }
}
