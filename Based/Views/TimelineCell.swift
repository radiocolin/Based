import UIKit

class TimelineCell: UITableViewCell {
    static let identifier = "TimelineCell"
    
    private let pitchTrackView = PitchTrackView()
    private let diamondView = DiamondView()
    private let infoStack = UIStackView()
    private let batterLabel = UILabel()
    private let pitcherLabel = UILabel()
    private let descriptionLabel = UILabel()
    
    private let leftContainer = UIStackView()
    
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
        
        leftContainer.axis = .vertical
        leftContainer.spacing = 8
        leftContainer.alignment = .center
        leftContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(leftContainer)
        
        pitchTrackView.translatesAutoresizingMaskIntoConstraints = false
        diamondView.translatesAutoresizingMaskIntoConstraints = false
        
        leftContainer.addArrangedSubview(pitchTrackView)
        leftContainer.addArrangedSubview(diamondView)
        
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
            leftContainer.widthAnchor.constraint(equalToConstant: 80),
            
            pitchTrackView.widthAnchor.constraint(equalToConstant: 70),
            pitchTrackView.heightAnchor.constraint(equalToConstant: 80),
            
            diamondView.widthAnchor.constraint(equalToConstant: 80),
            diamondView.heightAnchor.constraint(equalToConstant: 80),
            
            infoStack.leadingAnchor.constraint(equalTo: leftContainer.trailingAnchor, constant: 16),
            infoStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            infoStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            infoStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with event: AtBatEvent) {
        pitchTrackView.configure(with: event.pitches ?? [])
        diamondView.configure(with: event.bases, style: .scorecard, isRun: event.result == "HR")
        
        batterLabel.text = event.batterName.uppercased()
        pitcherLabel.text = "vs \(event.pitcherName)"
        
        descriptionLabel.text = event.description
    }
}
