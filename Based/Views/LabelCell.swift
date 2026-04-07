import UIKit

class LabelCell: UICollectionViewCell {
    static let reuseIdentifier = "LabelCell"
    
    let label: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16)
        label.textColor = AppColors.pencil
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.numberOfLines = 2
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let leading = label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6)
        let trailing = label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6)
        // Set priority to 999 to avoid conflicts with system-imposed zero width during cell layout
        leading.priority = UILayoutPriority(999)
        trailing.priority = UILayoutPriority(999)
        
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            leading,
            trailing
        ])
        // Subtle grid line instead of border
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = AppColors.grid.cgColor
        contentView.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.layer.borderWidth = 0.5
        label.text = nil
        label.attributedText = nil
        label.font = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16)
        label.textColor = AppColors.pencil
        label.textAlignment = .center
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layer.borderColor = AppColors.grid.cgColor
    }
}
