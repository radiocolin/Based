import UIKit

class LabelCell: UICollectionViewCell {
    static let reuseIdentifier = "LabelCell"
    
    let label: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16)
        label.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.numberOfLines = 2
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4)
        ])
        // Subtle grid line instead of border
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = UIColor(white: 0.6, alpha: 0.5).cgColor
        contentView.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
