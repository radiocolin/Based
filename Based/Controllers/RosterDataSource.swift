import UIKit

class RosterDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    
    struct RosterSection {
        let title: String
        let players: [RosterEntry]
    }
    
    private(set) var rosterSections: [RosterSection] = []
    var onPlayerSelected: ((RosterEntry) -> Void)?
    
    private var pencilColor: UIColor { AppColors.pencil }
    
    func update(with entries: [RosterEntry]) {
        self.rosterSections = buildRosterSections(from: entries)
    }
    
    private func buildRosterSections(from entries: [RosterEntry]) -> [RosterSection] {
        var pitchers: [RosterEntry] = []
        var catchers: [RosterEntry] = []
        var infielders: [RosterEntry] = []
        var outfielders: [RosterEntry] = []
        var dhs: [RosterEntry] = []
        
        for entry in entries {
            let type = entry.position?.type?.lowercased() ?? ""
            if type == "pitcher" { pitchers.append(entry) }
            else if type == "catcher" { catchers.append(entry) }
            else if type == "infielder" { infielders.append(entry) }
            else if type == "outfielder" { outfielders.append(entry) }
            else { dhs.append(entry) }
        }
        
        var result: [RosterSection] = []
        if !pitchers.isEmpty { result.append(RosterSection(title: "Pitchers", players: pitchers)) }
        if !catchers.isEmpty { result.append(RosterSection(title: "Catchers", players: catchers)) }
        if !infielders.isEmpty { result.append(RosterSection(title: "Infielders", players: infielders)) }
        if !outfielders.isEmpty { result.append(RosterSection(title: "Outfielders", players: outfielders)) }
        if !dhs.isEmpty { result.append(RosterSection(title: "Designated Hitters", players: dhs)) }
        return result
    }
    
    // MARK: - Table View Data Source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return rosterSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rosterSections[section].players.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return rosterSections[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RosterPlayerCell.reuseIdentifier, for: indexPath) as! RosterPlayerCell
        let player = rosterSections[indexPath.section].players[indexPath.row]
        cell.configure(with: player)
        return cell
    }
    
    // MARK: - Table View Delegate
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = AppFont.ibmPlexCondensedBold(16, textStyle: .headline, compatibleWith: tableView.traitCollection)
        header.textLabel?.textColor = pencilColor.withAlphaComponent(0.6)
        header.contentView.backgroundColor = AppColors.paper
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let player = rosterSections[indexPath.section].players[indexPath.row]
        onPlayerSelected?(player)
    }
}

// MARK: - RosterPlayerCell

class RosterPlayerCell: UITableViewCell {
    static let reuseIdentifier = "RosterPlayerCell"

    private let nameLabel = UILabel()
    private let numberLabel = UILabel()
    private let positionLabel = UILabel()
    private let chevronView = UIImageView()
    private let linesLayer = CAShapeLayer()

    private var pencilColor: UIColor { AppColors.pencil }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        backgroundColor = AppColors.paper
    }

    private func setupUI() {
        backgroundColor = AppColors.paper
        contentView.layer.addSublayer(linesLayer)

        nameLabel.font = AppFont.patrick(20, textStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true

        numberLabel.font = AppFont.ibmPlexCondensedBold(14, textStyle: .caption1)
        numberLabel.textColor = pencilColor.withAlphaComponent(0.4)
        numberLabel.textAlignment = .center

        positionLabel.font = AppFont.ibmPlexCondensed(14, textStyle: .caption1)
        positionLabel.textColor = pencilColor.withAlphaComponent(0.6)

        chevronView.image = UIImage.pencilStyledIcon(
            named: "chevron.forward",
            color: pencilColor.withAlphaComponent(0.5),
            size: CGSize(width: 10, height: 10)
        )
        chevronView.contentMode = .center

        for v: UIView in [numberLabel, nameLabel, positionLabel, chevronView] {
            contentView.addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        let pad: CGFloat = 16
        NSLayoutConstraint.activate([
            numberLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            numberLabel.widthAnchor.constraint(equalToConstant: 30),
            numberLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 8),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -8),

            positionLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            positionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 0),
            positionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            chevronView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            chevronView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 10)
        ])
    }

    func configure(with entry: RosterEntry) {
        nameLabel.text = entry.person?.fullName
        numberLabel.text = entry.jerseyNumber
        positionLabel.text = entry.position?.name
    }

    func configure(with player: LeagueRosterPlayer) {
        nameLabel.text = player.fullName
        numberLabel.text = player.uniformNumber
        positionLabel.text = player.position
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = contentView.bounds
        let path = UIBezierPath()
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 16, y: b.maxY), to: CGPoint(x: b.maxX - 16, y: b.maxY), jitter: 0.3))
        linesLayer.path = path.cgPath
        linesLayer.strokeColor = pencilColor.withAlphaComponent(0.15).cgColor
        linesLayer.lineWidth = 0.5
        linesLayer.fillColor = UIColor.clear.cgColor
    }
}
