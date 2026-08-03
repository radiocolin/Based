import UIKit

@MainActor
class HighlightsPickerViewController: UIViewController {

    static let maxSelection: Int = 6

    private let scorecard: ScorecardData
    private let linescore: Linescore?
    private let selectedStyle: UIUserInterfaceStyle

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No plays to choose from yet.\nCheck back once the game is underway."
        label.font = UIFont(name: AppFont.patrickHand, size: 20) ?? .systemFont(ofSize: 20)
        label.textColor = AppColors.pencil.withAlphaComponent(0.55)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private var groups: [InningGroup] = []
    private var selectedPaths: Set<IndexPath> = []
    private var awayAccentColor: UIColor = AppColors.pencil
    private var homeAccentColor: UIColor = AppColors.pencil
    private var nextButton: UIBarButtonItem!

    init(scorecard: ScorecardData, linescore: Linescore?, style: UIUserInterfaceStyle) {
        self.scorecard = scorecard
        self.linescore = linescore
        self.selectedStyle = style
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = selectedStyle
        view.backgroundColor = AppColors.paper
        awayAccentColor = scorecard.teams.away.name.map(TeamColorProvider.color(for:)) ?? AppColors.pencil
        homeAccentColor = scorecard.teams.home.name.map(TeamColorProvider.color(for:)) ?? AppColors.pencil
        setupNavBar()
        setupTable()
        groups = InningGroup.build(from: scorecard.timeline)
        emptyStateLabel.isHidden = !groups.isEmpty
        tableView.isHidden = groups.isEmpty
        tableView.reloadData()
        updateNavTitle()
    }

    private func setupNavBar() {
        nextButton = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(nextTapped))
        nextButton.isEnabled = false
        navigationItem.rightBarButtonItem = nextButton

        let titleFont = UIFont(name: AppFont.ibmPlexBold, size: 20) ?? .systemFont(ofSize: 20, weight: .bold)
        let buttonFont = UIFont(name: AppFont.patrickHand, size: 18) ?? .systemFont(ofSize: 18)
        let pencilColor = AppColors.pencil

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.paper
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.font: titleFont, .foregroundColor: pencilColor]
        BarAppearanceSupport.applyPlainBarButtonAppearance(appearance.buttonAppearance, font: buttonFont, color: pencilColor)
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = pencilColor
    }

    private func setupTable() {
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
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyStateLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])
    }

    private func updateNavTitle() {
        title = "Choose Plays  \(selectedPaths.count)/\(Self.maxSelection)"
        nextButton.isEnabled = !selectedPaths.isEmpty
    }

    private func selectedEventsInTimelineOrder() -> [AtBatEvent] {
        var out: [AtBatEvent] = []
        for (sectionIndex, group) in groups.enumerated() {
            for (rowIndex, event) in group.events.enumerated() {
                if selectedPaths.contains(IndexPath(row: rowIndex, section: sectionIndex)) {
                    out.append(event)
                }
            }
        }
        return out
    }

    @objc private func nextTapped() {
        let plays = selectedEventsInTimelineOrder()
        guard !plays.isEmpty else { return }
        let preview = HighlightsPreviewViewController(
            scorecard: scorecard,
            linescore: linescore,
            plays: plays,
            style: selectedStyle
        )
        navigationController?.pushViewController(preview, animated: true)
    }
}

extension HighlightsPickerViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        groups.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groups[section].events.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TimelineCell.identifier, for: indexPath) as? TimelineCell else {
            return UITableViewCell()
        }
        let group = groups[indexPath.section]
        let event = group.events[indexPath.row]
        let accentColor = group.isTop ? awayAccentColor : homeAccentColor
        cell.configure(with: event, accentColor: accentColor)
        cell.tintColor = accentColor
        applySelectionState(to: cell, at: indexPath)
        return cell
    }

    /// TimelineCell's own `configure(with:)` sets an accessibilityHint aimed at its normal
    /// read-only context ("Double tap for at-bat details") — here a tap selects the play for the
    /// highlights card instead, so both the hint and selection state need overriding after
    /// configure() runs.
    private func applySelectionState(to cell: TimelineCell, at indexPath: IndexPath) {
        let isSelected = selectedPaths.contains(indexPath)
        cell.accessoryType = isSelected ? .checkmark : .none
        cell.accessibilityValue = isSelected ? "Selected" : nil
        cell.accessibilityHint = isSelected
            ? "Double tap to remove this play from your highlights selection."
            : "Double tap to add this play to your highlights selection."
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        container.backgroundColor = AppColors.header.withAlphaComponent(0.95)

        let label = UILabel()
        label.text = groups[section].title
        label.font = AppFont.ibmPlexCondensed(14, textStyle: .headline, compatibleWith: traitCollection)
        label.textColor = AppColors.pencil.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
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
            line.heightAnchor.constraint(equalToConstant: 0.5),
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        32
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        if selectedPaths.contains(indexPath) {
            selectedPaths.remove(indexPath)
        } else {
            guard selectedPaths.count < Self.maxSelection else {
                let alert = UIAlertController(
                    title: "Up to \(Self.maxSelection) Plays",
                    message: "Deselect one of your picks to swap in this play.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
            selectedPaths.insert(indexPath)
        }
        if let cell = tableView.cellForRow(at: indexPath) as? TimelineCell {
            applySelectionState(to: cell, at: indexPath)
        }
        updateNavTitle()
    }
}
