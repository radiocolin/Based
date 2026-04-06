import UIKit

protocol TimelineViewDelegate: AnyObject {
    func didSelectTimelineAtBat(_ event: AtBatEvent)
}

class TimelineView: UIView {
    weak var delegate: TimelineViewDelegate?
    private let tableView = UITableView()
    private var timeline: [AtBatEvent] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = AppColors.grid.withAlphaComponent(0.3)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TimelineCell.self, forCellReuseIdentifier: TimelineCell.identifier)
        tableView.estimatedRowHeight = 150
        tableView.rowHeight = UITableView.automaticDimension
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(with timeline: [AtBatEvent]) {
        self.timeline = timeline
        tableView.reloadData()
    }
}

extension TimelineView: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return timeline.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TimelineCell.identifier, for: indexPath) as? TimelineCell else {
            return UITableViewCell()
        }
        cell.configure(with: timeline[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.didSelectTimelineAtBat(timeline[indexPath.row])
    }
}
