import UIKit

class AtBatDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // Data
    private var event: AtBatEvent
    private var batterName: String
    private var pitcherName: String
    private var accentColor: UIColor?
    
    // UI Elements
    private let scrollView = UIScrollView()
    private let containerView = UIView()
    private let matchupStack = UIStackView()
    private let batterLabel = UILabel()
    private let subHeaderLabel = UILabel()

    private let atBatGraphicView = AtBatGraphicView()
    private let descriptionLabel = UILabel()
    private let pitchesTableView = UITableView()
    private let pitchTrackView = PitchTrackView()
    private let pitchSequenceHeaderLabel = UILabel()
    private var pitchTrackHeightConstraint: NSLayoutConstraint?
    private var atBatGraphicHeightConstraint: NSLayoutConstraint?
    private var atBatGraphicWidthConstraint: NSLayoutConstraint?
    private var pitchTrackWidthConstraint: NSLayoutConstraint?
    private var pitchesTableHeightConstraint: NSLayoutConstraint?

    private var regularConstraints: [NSLayoutConstraint] = []
    private var accessibilityLayoutConstraints: [NSLayoutConstraint] = []

    var onBatterTap: (() -> Void)?
    var onPitcherTap: (() -> Void)?
    
    // Graphics
    private let linesLayer = CAShapeLayer()
    
    // Constants
    private let paperColor = AppColors.paper
    private var pencilColor: UIColor { AppColors.pencil }
    private let headerFont = "PermanentMarker-Regular"
    private let bodyFont = "PatrickHand-Regular"
    
    init(event: AtBatEvent, batterName: String, pitcherName: String, accentColor: UIColor? = nil) {
        self.event = event
        self.batterName = batterName
        self.pitcherName = pitcherName
        self.accentColor = accentColor
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(event: AtBatEvent, batterName: String? = nil, pitcherName: String? = nil, accentColor: UIColor? = nil) {
        self.event = event
        if let batterName {
            self.batterName = batterName
        }
        if let pitcherName {
            self.pitcherName = pitcherName
        }
        if let accentColor {
            self.accentColor = accentColor
        }
        batterLabel.text = self.batterName
        applyPitcherHeader()
        applyEventPresentation()

        if let pitches = event.pitches {
            pitchTrackView.configure(with: pitches)
        } else {
            pitchTrackView.configure(with: [])
        }
        atBatGraphicView.configure(with: event, accentColor: self.accentColor)
        pitchesTableView.reloadData()
        updatePitchesTableHeight()

        view.setNeedsLayout()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        applyEventPresentation()
        view.accessibilityViewIsModal = true
        updateAccessibilityOrder()

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: AtBatDetailViewController, _) in
            self.pitchesTableView.reloadData()
            self.view.setNeedsLayout()
        }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: AtBatDetailViewController, _) in
            self.applyTypography()
            self.updateLayoutForCurrentSettings()
            self.pitchesTableView.reloadData()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: batterLabel)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePitchesTableHeight()
        drawPencilLines()
    }
    
    private func setupUI() {
        view.backgroundColor = paperColor
        pitchTrackView.isAccessibilityElement = false
        atBatGraphicView.isAccessibilityElement = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(containerView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // --- Matchup ---
        matchupStack.axis = .vertical
        matchupStack.alignment = .leading
        matchupStack.spacing = 2
        matchupStack.translatesAutoresizingMaskIntoConstraints = false
        matchupStack.isAccessibilityElement = true
        matchupStack.accessibilityTraits = .header
        containerView.addSubview(matchupStack)

        batterLabel.text = batterName
        batterLabel.font = AppFont.permanent(32, textStyle: .title1, compatibleWith: traitCollection)
        batterLabel.textColor = pencilColor
        batterLabel.numberOfLines = 0
        batterLabel.adjustsFontForContentSizeCategory = true
        batterLabel.isUserInteractionEnabled = true
        batterLabel.isAccessibilityElement = false // Container handles it

        applyPitcherHeader()
        subHeaderLabel.numberOfLines = 0
        subHeaderLabel.isUserInteractionEnabled = true
        subHeaderLabel.isAccessibilityElement = false // Container handles it

        matchupStack.addArrangedSubview(batterLabel)
        matchupStack.addArrangedSubview(subHeaderLabel)

        descriptionLabel.font = AppFont.patrick(18, textStyle: .body, compatibleWith: traitCollection)
        descriptionLabel.textColor = pencilColor.withAlphaComponent(0.8)
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.adjustsFontForContentSizeCategory = true
        descriptionLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        containerView.addSubview(descriptionLabel)

        // --- Right Column / Stacked Graphics ---
        atBatGraphicView.translatesAutoresizingMaskIntoConstraints = false
        atBatGraphicView.configure(with: event, accentColor: accentColor)
        containerView.addSubview(atBatGraphicView)

        pitchTrackView.translatesAutoresizingMaskIntoConstraints = false
        if let pitches = event.pitches {
            pitchTrackView.configure(with: pitches)
        }
        containerView.addSubview(pitchTrackView)

        // --- Pitch Sequence Table ---
        pitchesTableView.backgroundColor = .clear
        pitchesTableView.separatorStyle = .none
        pitchesTableView.dataSource = self
        pitchesTableView.delegate = self
        pitchesTableView.register(PitchCell.self, forCellReuseIdentifier: "PitchCell")
        pitchesTableView.rowHeight = UITableView.automaticDimension
        pitchesTableView.estimatedRowHeight = 56
        pitchesTableView.isScrollEnabled = false
        pitchesTableView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pitchesTableView)

        pitchSequenceHeaderLabel.text = "PITCH SEQUENCE"
        pitchSequenceHeaderLabel.font = AppFont.patrick(16, textStyle: .headline, compatibleWith: traitCollection)
        pitchSequenceHeaderLabel.textColor = pencilColor
        pitchSequenceHeaderLabel.adjustsFontForContentSizeCategory = true
        pitchSequenceHeaderLabel.accessibilityTraits = .header

        let sideColumnWidth: CGFloat = 160
        let horizontalSpacing: CGFloat = 20
        let verticalSpacing: CGFloat = 12

        // Initialize reusable constraints
        atBatGraphicWidthConstraint = atBatGraphicView.widthAnchor.constraint(equalToConstant: sideColumnWidth)
        atBatGraphicHeightConstraint = atBatGraphicView.heightAnchor.constraint(equalToConstant: sideColumnWidth)
        pitchTrackWidthConstraint = pitchTrackView.widthAnchor.constraint(equalToConstant: sideColumnWidth)
        pitchTrackHeightConstraint = pitchTrackView.heightAnchor.constraint(equalToConstant: 180)
        pitchesTableHeightConstraint = pitchesTableView.heightAnchor.constraint(equalToConstant: 0)
        pitchesTableHeightConstraint?.isActive = true

        // Regular 2-Column Constraints
        let descriptionCenterY = descriptionLabel.centerYAnchor.constraint(equalTo: pitchTrackView.centerYAnchor)
        descriptionCenterY.priority = .defaultHigh

        regularConstraints = [
            atBatGraphicView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            atBatGraphicView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            atBatGraphicWidthConstraint!,
            atBatGraphicHeightConstraint!,

            matchupStack.centerYAnchor.constraint(equalTo: atBatGraphicView.centerYAnchor),
            matchupStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            matchupStack.trailingAnchor.constraint(equalTo: atBatGraphicView.leadingAnchor, constant: -horizontalSpacing),

            pitchTrackView.topAnchor.constraint(greaterThanOrEqualTo: matchupStack.bottomAnchor, constant: verticalSpacing),
            pitchTrackView.topAnchor.constraint(greaterThanOrEqualTo: atBatGraphicView.bottomAnchor, constant: verticalSpacing),
            pitchTrackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            pitchTrackWidthConstraint!,
            pitchTrackHeightConstraint!,

            descriptionCenterY,
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: pitchTrackView.leadingAnchor, constant: -horizontalSpacing),
            descriptionLabel.topAnchor.constraint(greaterThanOrEqualTo: matchupStack.bottomAnchor, constant: verticalSpacing),
            descriptionLabel.topAnchor.constraint(greaterThanOrEqualTo: atBatGraphicView.bottomAnchor, constant: verticalSpacing),

            pitchesTableView.topAnchor.constraint(greaterThanOrEqualTo: descriptionLabel.bottomAnchor, constant: 12),
            pitchesTableView.topAnchor.constraint(greaterThanOrEqualTo: pitchTrackView.bottomAnchor, constant: 12)
        ]

        // Accessibility Single-Column Constraints
        accessibilityLayoutConstraints = [
            matchupStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            matchupStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            matchupStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            atBatGraphicView.topAnchor.constraint(equalTo: matchupStack.bottomAnchor, constant: verticalSpacing),
            atBatGraphicView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            atBatGraphicWidthConstraint!,
            atBatGraphicHeightConstraint!,

            descriptionLabel.topAnchor.constraint(equalTo: atBatGraphicView.bottomAnchor, constant: verticalSpacing),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            pitchTrackView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: verticalSpacing),
            pitchTrackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            pitchTrackWidthConstraint!,
            pitchTrackHeightConstraint!,

            pitchesTableView.topAnchor.constraint(equalTo: pitchTrackView.bottomAnchor, constant: 16)
        ]

        NSLayoutConstraint.activate([
            pitchesTableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            pitchesTableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            pitchesTableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])

        updateLayoutForCurrentSettings()
        containerView.layer.addSublayer(linesLayer)

        let batterTap = UITapGestureRecognizer(target: self, action: #selector(handleBatterTap))
        matchupStack.addGestureRecognizer(batterTap)
    }

    private func updateLayoutForCurrentSettings() {
        let isAccessibility = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        NSLayoutConstraint.deactivate(regularConstraints + accessibilityLayoutConstraints)
        
        if isAccessibility {
            NSLayoutConstraint.activate(accessibilityLayoutConstraints)
        } else {
            NSLayoutConstraint.activate(regularConstraints)
        }
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
        updateAccessibilityOrder()
    }

    private func applyEventPresentation() {
        let presentation = AtBatPresentation(event: event, teamAccentColor: accentColor)
        descriptionLabel.text = presentation.displayDescription
        descriptionLabel.accessibilityLabel = "Play description, \(presentation.displayDescription)"
        
        matchupStack.accessibilityLabel = "\(batterName) versus \(pitcherName.capitalized)"
        matchupStack.accessibilityHint = "Double tap for player details."
    }

    private func applyPitcherHeader() {
        let prefixAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.patrick(20, textStyle: .headline, compatibleWith: traitCollection),
            .foregroundColor: pencilColor.withAlphaComponent(0.7)
        ]
        let pitcherAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.patrick(20, textStyle: .headline, compatibleWith: traitCollection),
            .foregroundColor: pencilColor
        ]
        let text = NSMutableAttributedString(string: "vs. ", attributes: prefixAttributes)
        text.append(NSAttributedString(string: pitcherName.capitalized, attributes: pitcherAttributes))
        subHeaderLabel.attributedText = text
        subHeaderLabel.accessibilityLabel = "Pitcher, \(pitcherName.capitalized)"
    }

    @objc private func handleBatterTap() {
        onBatterTap?()
    }

    @objc private func handlePitcherTap() {
        onPitcherTap?()
    }
    
    private func drawPencilLines() {
        // Separators removed for cleaner layout as requested
        linesLayer.path = nil
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
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = paperColor
        pitchSequenceHeaderLabel.removeFromSuperview()
        pitchSequenceHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        pitchSequenceHeaderLabel.numberOfLines = 0
        v.addSubview(pitchSequenceHeaderLabel)
        NSLayoutConstraint.activate([
            pitchSequenceHeaderLabel.topAnchor.constraint(equalTo: v.topAnchor, constant: 4),
            pitchSequenceHeaderLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            pitchSequenceHeaderLabel.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            pitchSequenceHeaderLabel.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -4)
        ])
        return v
    }

    private func updateAccessibilityOrder() {
        view.accessibilityElements = [
            matchupStack as Any,
            descriptionLabel as Any,
            pitchesTableView as Any
        ]
    }

    private func applyTypography() {
        batterLabel.font = AppFont.permanent(32, textStyle: .title1, compatibleWith: traitCollection)
        descriptionLabel.font = AppFont.patrick(18, textStyle: .body, compatibleWith: traitCollection)
        pitchSequenceHeaderLabel.font = AppFont.patrick(16, textStyle: .headline, compatibleWith: traitCollection)
        
        let sideColumnWidth: CGFloat = 160
        atBatGraphicWidthConstraint?.constant = sideColumnWidth
        atBatGraphicHeightConstraint?.constant = sideColumnWidth
        pitchTrackWidthConstraint?.constant = sideColumnWidth
        pitchTrackHeightConstraint?.constant = 180
        
        applyPitcherHeader()
        updatePitchesTableHeight()
    }

    private func updatePitchesTableHeight() {
        pitchesTableView.layoutIfNeeded()
        pitchesTableHeightConstraint?.constant = pitchesTableView.contentSize.height + 48
    }
}

class PitchCell: UITableViewCell {

    private let numLabel = UILabel()
    private let descLabel = UILabel()
    private let detailLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let separatorLayer = CAShapeLayer()
    private var compactConstraints: [NSLayoutConstraint] = []
    private var accessibilityConstraints: [NSLayoutConstraint] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let y = contentView.bounds.maxY
        let inset: CGFloat = 0
        separatorLayer.path = UIBezierPath.pencilLine(
            from: CGPoint(x: inset, y: y),
            to: CGPoint(x: contentView.bounds.width - inset, y: y),
            jitter: 0.4
        ).cgPath
        separatorLayer.strokeColor = AppColors.pencil.withAlphaComponent(0.15).cgColor
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none
        isAccessibilityElement = true
        accessibilityTraits = .staticText

        separatorLayer.lineWidth = 0.75
        separatorLayer.fillColor = UIColor.clear.cgColor
        contentView.layer.addSublayer(separatorLayer)

        [numLabel, descLabel, detailLabel, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
            $0.textColor = AppColors.pencil
            $0.isAccessibilityElement = false
            $0.adjustsFontForContentSizeCategory = true
        }

        numLabel.font = AppFont.permanent(16, textStyle: .headline)
        numLabel.textColor = .gray

        descLabel.font = AppFont.permanent(18, textStyle: .body)
        descLabel.numberOfLines = 0
        descLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        detailLabel.font = AppFont.patrick(16, textStyle: .subheadline)
        detailLabel.textColor = AppColors.pencil.withAlphaComponent(0.7)
        detailLabel.textAlignment = .right
        detailLabel.numberOfLines = 0
        detailLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        detailLabel.setContentHuggingPriority(.required, for: .horizontal)

        subtitleLabel.font = AppFont.patrick(14, textStyle: .footnote)
        subtitleLabel.textColor = .gray
        subtitleLabel.numberOfLines = 0

        compactConstraints = [
            numLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            numLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            numLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 32),

            descLabel.leadingAnchor.constraint(equalTo: numLabel.trailingAnchor, constant: 8),
            descLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            descLabel.trailingAnchor.constraint(lessThanOrEqualTo: detailLabel.leadingAnchor, constant: -8),

            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            detailLabel.firstBaselineAnchor.constraint(equalTo: descLabel.firstBaselineAnchor),

            subtitleLabel.leadingAnchor.constraint(equalTo: descLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ]

        accessibilityConstraints = [
            numLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            numLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            numLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),

            descLabel.leadingAnchor.constraint(equalTo: numLabel.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: numLabel.bottomAnchor, constant: 4),
            descLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),

            detailLabel.leadingAnchor.constraint(equalTo: descLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 8),
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),

            subtitleLabel.leadingAnchor.constraint(equalTo: descLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ]

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: PitchCell, _) in
            self.updateLayoutForCurrentContentSizeCategory()
        }
        updateLayoutForCurrentContentSizeCategory()
    }

    func configure(with pitch: PitchEvent) {
        numLabel.text = "\(pitch.pitchNumber)."
        descLabel.text = pitch.description

        // Build detail string: "Type • Speed" or just one
        var detailParts: [String] = []
        if let type = pitch.pitchType?.trimmingCharacters(in: .whitespacesAndNewlines), !type.isEmpty {
            detailParts.append(type)
        }
        if let speed = pitch.speed {
            detailParts.append(String(format: "%.0f mph", speed))
        }
        detailLabel.text = detailParts.joined(separator: " • ")
        detailLabel.isHidden = detailParts.isEmpty

        let subtitle = subtitleText(for: pitch)
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle.isEmpty

        updateLayoutForCurrentContentSizeCategory()
        accessibilityLabel = AccessibilitySupport.pitchDescription(pitch)
    }

    private func updateLayoutForCurrentContentSizeCategory() {
        let isAccessibility = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        NSLayoutConstraint.deactivate(compactConstraints + accessibilityConstraints)
        if isAccessibility {
            detailLabel.textAlignment = .left
            NSLayoutConstraint.activate(accessibilityConstraints)
        } else {
            detailLabel.textAlignment = .right
            NSLayoutConstraint.activate(compactConstraints)
        }
    }

    private func subtitleText(for pitch: PitchEvent) -> String {
        if let balls = pitch.balls, let strikes = pitch.strikes {
            return "Count \(balls)-\(strikes)"
        }

        let normalizedDescription = pitch.description.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedOutcome = pitch.outcome.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedOutcome.isEmpty, normalizedOutcome != normalizedDescription else {
            return ""
        }

        return pitch.outcome
    }
}
