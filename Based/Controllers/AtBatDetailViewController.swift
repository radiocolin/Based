import UIKit

class AtBatDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // Data
    private var event: AtBatEvent
    private let batterName: String
    private let pitcherName: String
    
    // UI Elements
    private let containerView = UIView()
    private let titleStack = UIStackView()
    private let batterLabel = UILabel()
    private let resultLabel = UILabel()
    private let subHeaderLabel = UILabel()
    
    private let atBatGraphicView = AtBatGraphicView()
    private let descriptionLabel = UILabel()
    private let pitchesTableView = UITableView()
    private let pitchTrackView = PitchTrackView()
    
    // Graphics
    private let linesLayer = CAShapeLayer()
    
    // Constants
    private let paperColor = UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)
    private let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
    private let headerFont = "PermanentMarker-Regular"
    private let bodyFont = "PatrickHand-Regular"
    
    init(event: AtBatEvent, batterName: String, pitcherName: String) {
        self.event = event
        self.batterName = batterName
        self.pitcherName = pitcherName
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(event: AtBatEvent) {
        self.event = event
        
        // Update UI components
        let isLive = event.result == "LIVE"
        resultLabel.text = isLive ? "LIVE" : event.result
        descriptionLabel.text = isLive ? "Current at bat" : event.description
        
        if let pitches = event.pitches {
            pitchTrackView.configure(with: pitches)
        }
        atBatGraphicView.configure(with: event)
        pitchesTableView.reloadData()
        
        view.setNeedsLayout()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Initial setup for LIVE state if needed
        let isLive = event.result == "LIVE"
        resultLabel.text = isLive ? "LIVE" : event.result
        descriptionLabel.text = isLive ? "Current at bat" : event.description
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        drawPencilLines()
    }
    
    private func setupUI() {
        view.backgroundColor = paperColor
        
        // intentional Title Layout (Stacked if needed)
        titleStack.axis = .vertical
        titleStack.alignment = .center
        titleStack.spacing = 2
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleStack)
        
        batterLabel.text = batterName.uppercased()
        batterLabel.font = UIFont(name: headerFont, size: 24) ?? .systemFont(ofSize: 24, weight: .bold)
        batterLabel.textColor = pencilColor
        batterLabel.textAlignment = .center
        batterLabel.numberOfLines = 0
        
        resultLabel.text = event.result
        resultLabel.font = UIFont(name: "PermanentMarker-Regular", size: 32) ?? .systemFont(ofSize: 32, weight: .bold)
        resultLabel.textColor = pencilColor
        
        titleStack.addArrangedSubview(batterLabel)
        titleStack.addArrangedSubview(resultLabel)
        
        // SubHeader (Pitcher Name)
        subHeaderLabel.text = "VS. \(pitcherName.uppercased())"
        subHeaderLabel.font = UIFont(name: bodyFont, size: 16) ?? .systemFont(ofSize: 16)
        subHeaderLabel.textColor = pencilColor.withAlphaComponent(0.7)
        subHeaderLabel.textAlignment = .center
        subHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subHeaderLabel)
        
        // Top Container Views
        pitchTrackView.translatesAutoresizingMaskIntoConstraints = false
        if let pitches = event.pitches {
            pitchTrackView.configure(with: pitches)
        }
        view.addSubview(pitchTrackView)
        
        atBatGraphicView.translatesAutoresizingMaskIntoConstraints = false
        atBatGraphicView.configure(with: event)
        view.addSubview(atBatGraphicView)
        
        // Description
        descriptionLabel.text = event.description
        descriptionLabel.font = UIFont(name: bodyFont, size: 18) ?? .systemFont(ofSize: 18)
        descriptionLabel.textColor = pencilColor.withAlphaComponent(0.8)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(descriptionLabel)
        
        // Pitches Table
        pitchesTableView.backgroundColor = .clear
        pitchesTableView.separatorStyle = .none
        pitchesTableView.dataSource = self
        pitchesTableView.delegate = self
        pitchesTableView.register(PitchCell.self, forCellReuseIdentifier: "PitchCell")
        pitchesTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pitchesTableView)
        
        // Layout
        let topHeight: CGFloat = 180
        
        NSLayoutConstraint.activate([
            titleStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            subHeaderLabel.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 4),
            subHeaderLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            subHeaderLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Top Section (Left: Pitch Track, Right: Result Graphic)
            pitchTrackView.topAnchor.constraint(equalTo: subHeaderLabel.bottomAnchor, constant: 16),
            pitchTrackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            pitchTrackView.heightAnchor.constraint(equalToConstant: topHeight),
            pitchTrackView.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -10),
            
            atBatGraphicView.topAnchor.constraint(equalTo: pitchTrackView.topAnchor),
            atBatGraphicView.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10),
            atBatGraphicView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            atBatGraphicView.heightAnchor.constraint(equalToConstant: topHeight),
            
            // Description
            descriptionLabel.topAnchor.constraint(equalTo: pitchTrackView.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            // Table
            pitchesTableView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            pitchesTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            pitchesTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            pitchesTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
        
        view.layer.addSublayer(linesLayer)
    }
    
    private func drawPencilLines() {
        let path = UIBezierPath()
        
        // Line under Header
        let headerY = subHeaderLabel.frame.maxY + 10
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 20, y: headerY), to: CGPoint(x: view.bounds.width - 20, y: headerY)))
        
        // Line under Description
        let descY = descriptionLabel.frame.maxY + 10
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 20, y: descY), to: CGPoint(x: view.bounds.width - 20, y: descY)))
        
        linesLayer.path = path.cgPath
        linesLayer.strokeColor = pencilColor.cgColor
        linesLayer.lineWidth = 1.0
        linesLayer.fillColor = UIColor.clear.cgColor
        linesLayer.lineCap = .round
        linesLayer.lineJoin = .round
    }
    
    // MARK: - TableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return event.pitches?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PitchCell", for: indexPath) as? PitchCell else {
            return UITableViewCell()
        }
        if let pitch = event.pitches?[indexPath.row] {
            cell.configure(with: pitch)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = paperColor
        let l = UILabel()
        l.text = "PITCH SEQUENCE"
        l.font = UIFont(name: headerFont, size: 16)
        l.textColor = pencilColor
        l.frame = CGRect(x: 0, y: 0, width: 200, height: 30)
        v.addSubview(l)
        return v
    }
}

class PitchCell: UITableViewCell {
    
    private let numLabel = UILabel()
    private let descLabel = UILabel()
    private let speedLabel = UILabel()
    private let outcomeLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none
        
        [numLabel, descLabel, speedLabel, outcomeLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
            $0.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
            $0.font = UIFont(name: "PatrickHand-Regular", size: 18)
        }
        
        numLabel.font = UIFont(name: "PermanentMarker-Regular", size: 16)
        numLabel.textColor = .gray
        
        speedLabel.textAlignment = .right
        
        NSLayoutConstraint.activate([
            numLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            numLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            numLabel.widthAnchor.constraint(equalToConstant: 24),
            
            descLabel.leadingAnchor.constraint(equalTo: numLabel.trailingAnchor, constant: 8),
            descLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            
            outcomeLabel.leadingAnchor.constraint(equalTo: descLabel.leadingAnchor),
            outcomeLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 2),
            outcomeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            speedLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            speedLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            speedLabel.widthAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    func configure(with pitch: PitchEvent) {
        numLabel.text = "\(pitch.pitchNumber)."
        descLabel.text = pitch.description
        outcomeLabel.text = pitch.outcome.uppercased()
        outcomeLabel.font = UIFont(name: "PatrickHand-Regular", size: 14)
        outcomeLabel.textColor = .gray
        
        if let speed = pitch.speed {
            speedLabel.text = String(format: "%.0f mph", speed)
        } else {
            speedLabel.text = ""
        }
    }
}
