import UIKit

class TimelineCell: UITableViewCell {
    static let identifier = "TimelineCell"
    
    private let pitchTrackView = PitchTrackView()
    private let diamondView = DiamondView()
    private let resultLabel = UILabel()
    private let ballsLabel = UILabel()
    private let strikesLabel = UILabel()
    private let outsLabel = UILabel()
    
    private let topRow = UIStackView()
    private let bottomRow = UIStackView()
    private let matchupStack = UIStackView()
    private let batterLabel = UILabel()
    private let pitcherLabel = UILabel()
    private let descriptionLabel = UILabel()
    
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
        
        topRow.axis = .horizontal
        topRow.spacing = 16
        topRow.alignment = .top
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.isAccessibilityElement = false
        contentView.addSubview(topRow)

        bottomRow.axis = .horizontal
        bottomRow.spacing = 16
        bottomRow.alignment = .top
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        bottomRow.isAccessibilityElement = false
        contentView.addSubview(bottomRow)
        
        pitchTrackView.translatesAutoresizingMaskIntoConstraints = false
        diamondContainer.translatesAutoresizingMaskIntoConstraints = false
        diamondContainer.isAccessibilityElement = false
        diamondView.translatesAutoresizingMaskIntoConstraints = false
        
        topRow.addArrangedSubview(pitchTrackView)
        bottomRow.addArrangedSubview(diamondContainer)
        diamondContainer.addSubview(diamondView)
        
        // Diamond Labels
        let pencilColor = AppColors.pencil
        
        resultLabel.font = AppFont.permanent(20, textStyle: .title3, compatibleWith: traitCollection)
        resultLabel.textColor = pencilColor
        resultLabel.textAlignment = .center
        resultLabel.numberOfLines = 0
        resultLabel.adjustsFontSizeToFitWidth = true
        resultLabel.minimumScaleFactor = 0.5
        resultLabel.adjustsFontForContentSizeCategory = true
        
        [ballsLabel, strikesLabel, outsLabel].forEach {
            $0.font = AppFont.patrick(12, textStyle: .caption2, compatibleWith: traitCollection)
            $0.textColor = pencilColor
            $0.textAlignment = .center
            $0.adjustsFontForContentSizeCategory = true
        }
        
        [resultLabel, ballsLabel, strikesLabel, outsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isAccessibilityElement = false
            diamondContainer.addSubview($0)
        }
        
        matchupStack.axis = .vertical
        matchupStack.spacing = 2
        matchupStack.alignment = .fill
        matchupStack.translatesAutoresizingMaskIntoConstraints = false
        matchupStack.isAccessibilityElement = false
        
        batterLabel.font = AppFont.permanent(16, textStyle: .headline, compatibleWith: traitCollection)
        batterLabel.textColor = AppColors.pencil
        batterLabel.adjustsFontForContentSizeCategory = true
        batterLabel.numberOfLines = 0
        
        pitcherLabel.font = AppFont.patrick(14, textStyle: .subheadline, compatibleWith: traitCollection)
        pitcherLabel.textColor = AppColors.pencil.withAlphaComponent(0.7)
        pitcherLabel.adjustsFontForContentSizeCategory = true
        pitcherLabel.numberOfLines = 0
        
        descriptionLabel.font = AppFont.patrick(15, textStyle: .body, compatibleWith: traitCollection)
        descriptionLabel.textColor = AppColors.pencil
        descriptionLabel.numberOfLines = 0
        descriptionLabel.adjustsFontForContentSizeCategory = true
        [batterLabel, pitcherLabel, descriptionLabel].forEach { $0.isAccessibilityElement = false }

        batterLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        batterLabel.setContentHuggingPriority(.required, for: .vertical)
        pitcherLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        pitcherLabel.setContentHuggingPriority(.required, for: .vertical)
        matchupStack.setContentCompressionResistancePriority(.required, for: .vertical)
        matchupStack.setContentHuggingPriority(.required, for: .vertical)
        descriptionLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        descriptionLabel.setContentHuggingPriority(.required, for: .vertical)

        matchupStack.addArrangedSubview(batterLabel)
        matchupStack.addArrangedSubview(pitcherLabel)
        topRow.addArrangedSubview(matchupStack)
        bottomRow.addArrangedSubview(descriptionLabel)

        matchupStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        descriptionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pitchTrackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        diamondContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            topRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            topRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            topRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            
            pitchTrackView.widthAnchor.constraint(equalTo: diamondContainer.widthAnchor),
            pitchTrackView.heightAnchor.constraint(equalToConstant: 92),
            
            diamondContainer.widthAnchor.constraint(equalToConstant: 88),
            diamondContainer.heightAnchor.constraint(equalToConstant: 80),

            bottomRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            bottomRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 12),
            bottomRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            bottomRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
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
            outsLabel.trailingAnchor.constraint(equalTo: diamondContainer.trailingAnchor, constant: -4)
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
