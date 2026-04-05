import UIKit

class AtBatGraphicView: UIView {

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
        backgroundColor = .clear
        
        diamondView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(diamondView)
        
        let pencilColor = AppColors.pencil
        let bodyFont = "PatrickHand-Regular"
        let headerFont = "PermanentMarker-Regular"
        
        [resultLabel, ballsLabel, strikesLabel, outsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont(name: bodyFont, size: 14) ?? .systemFont(ofSize: 14)
            $0.textColor = pencilColor
            $0.textAlignment = .center
            addSubview($0)
        }
        
        resultLabel.font = UIFont(name: headerFont, size: 36) ?? .systemFont(ofSize: 36, weight: .bold)
        resultLabel.numberOfLines = 0
        resultLabel.adjustsFontSizeToFitWidth = true
        resultLabel.minimumScaleFactor = 0.5
        
        NSLayoutConstraint.activate([
            diamondView.topAnchor.constraint(equalTo: topAnchor),
            diamondView.leadingAnchor.constraint(equalTo: leadingAnchor),
            diamondView.trailingAnchor.constraint(equalTo: trailingAnchor),
            diamondView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            resultLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            resultLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            ballsLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            ballsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            
            strikesLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            strikesLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            
            outsLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            outsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)
        ])
    }
    
    func configure(with event: AtBatEvent) {
        let isLive = event.result == "LIVE"
        
        if isLive {
            resultLabel.attributedText = nil
        } else {
            // Use attributed string to reduce line spacing
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineHeightMultiple = 0.75
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .paragraphStyle: paragraphStyle,
                .font: resultLabel.font ?? .systemFont(ofSize: 36)
            ]
            resultLabel.attributedText = NSAttributedString(string: event.result, attributes: attributes)
        }
        
        ballsLabel.text = "\(event.balls)B"
        strikesLabel.text = "\(event.strikes)S"
        outsLabel.text = event.outs > 0 ? "\(event.outs)" : ""

        diamondView.configure(with: event.bases, style: isLive ? .liveStatus : .scorecard, isRun: event.result == "HR")
    }
}
