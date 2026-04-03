import UIKit

class TeamHeroCell: UICollectionViewCell {
    static let reuseIdentifier = "TeamHeroCell"
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private let statsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = .lightGray
        label.textAlignment = .center
        return label
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue // Placeholder color, dynamic later
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(nameLabel)
        containerView.addSubview(statsLabel)
        
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            nameLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -12),
            
            statsLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            statsLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])
    }
    
    func configure(with teamStats: TeamGameStats, isHome: Bool) {
        nameLabel.text = teamStats.team?.name ?? "Unknown Team"
        statsLabel.text = "R: \(teamStats.runs ?? 0)  H: \(teamStats.hits ?? 0)  E: \(teamStats.errors ?? 0)"
        containerView.backgroundColor = isHome ? .systemRed : .systemBlue // Basic colors for Phillies/Braves
    }
}
