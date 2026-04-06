import UIKit

protocol TimelineViewDelegate: AnyObject {
    func didSelectTimelineAtBat(_ event: AtBatEvent)
}

struct InningGroup {
    let inning: Int
    let isTop: Bool
    let events: [AtBatEvent]
    
    var title: String {
        let side = isTop ? "TOP" : "BOTTOM"
        return "\(side) \(inning)"
    }
}

class TimelineView: UIView {
    weak var delegate: TimelineViewDelegate?
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var groups: [InningGroup] = []
    
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
        tableView.sectionHeaderTopPadding = 0
        
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
        // Group by inning and half-inning
        var grouped: [InningGroup] = []
        var currentInning: Int?
        var currentIsTop: Bool?
        var currentEvents: [AtBatEvent] = []
        
        // Input timeline is already newest-to-oldest.
        // We iterate and group as long as inning/half-inning matches.
        for event in timeline {
            if event.inning != currentInning || event.isTop != currentIsTop {
                if let inn = currentInning, let top = currentIsTop {
                    grouped.append(InningGroup(inning: inn, isTop: top, events: currentEvents))
                }
                currentInning = event.inning
                currentIsTop = event.isTop
                currentEvents = [event]
            } else {
                currentEvents.append(event)
            }
        }
        
        if let inn = currentInning, let top = currentIsTop {
            grouped.append(InningGroup(inning: inn, isTop: top, events: currentEvents))
        }
        
        self.groups = grouped
        tableView.reloadData()
    }
}

extension TimelineView: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return groups.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups[section].events.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TimelineCell.identifier, for: indexPath) as? TimelineCell else {
            return UITableViewCell()
        }
        cell.configure(with: groups[indexPath.section].events[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        container.backgroundColor = AppColors.header.withAlphaComponent(0.95)
        
        let label = UILabel()
        label.text = groups[section].title
        label.font = UIFont(name: "PermanentMarker-Regular", size: 14) ?? .systemFont(ofSize: 14, weight: .bold)
        label.textColor = AppColors.pencil.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        let line = UIView()
        line.backgroundColor = AppColors.grid.withAlphaComponent(0.4)
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
        return container
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 32
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.didSelectTimelineAtBat(groups[indexPath.section].events[indexPath.row])
    }
}
