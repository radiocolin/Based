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
    private let titleStack = UIStackView()
    private let batterLabel = UILabel()
    private let resultLabel = UILabel()
    private let subHeaderLabel = UILabel()
    
    private let atBatGraphicView = AtBatGraphicView()
    private let descriptionLabel = UILabel()
    private let pitchesTableView = UITableView()
    private let pitchTrackView = PitchTrackView()
    private let pitchSequenceHeaderLabel = UILabel()
    private var pitchTrackHeightConstraint: NSLayoutConstraint?
    private var atBatGraphicHeightConstraint: NSLayoutConstraint?
    private var pitchesTableHeightConstraint: NSLayoutConstraint?

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
        
        // intentional Title Layout (Stacked if needed)
        titleStack.axis = .vertical
        titleStack.alignment = .center
        titleStack.spacing = 4
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleStack)
        
        batterLabel.text = batterName
        batterLabel.font = AppFont.permanent(24, textStyle: .title1, compatibleWith: traitCollection)
        batterLabel.textColor = pencilColor
        batterLabel.textAlignment = .center
        batterLabel.numberOfLines = 0
        batterLabel.adjustsFontForContentSizeCategory = true
        batterLabel.isUserInteractionEnabled = true
        batterLabel.accessibilityTraits = .button
        batterLabel.accessibilityHint = "Double tap for player details."
        
        resultLabel.font = AppFont.permanent(32, textStyle: .largeTitle, compatibleWith: traitCollection)
        resultLabel.textColor = pencilColor
        resultLabel.adjustsFontForContentSizeCategory = true
        resultLabel.numberOfLines = 0
        resultLabel.textAlignment = .center
        
        titleStack.addArrangedSubview(batterLabel)
        titleStack.addArrangedSubview(resultLabel)
        
        // SubHeader (Pitcher Name)
        applyPitcherHeader()
        subHeaderLabel.textAlignment = .center
        subHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        subHeaderLabel.numberOfLines = 0
        subHeaderLabel.isUserInteractionEnabled = true
        subHeaderLabel.accessibilityTraits = .button
        subHeaderLabel.accessibilityHint = "Double tap for pitcher details."
        containerView.addSubview(subHeaderLabel)
        
        // Top Container Views
        pitchTrackView.translatesAutoresizingMaskIntoConstraints = false
        if let pitches = event.pitches {
            pitchTrackView.configure(with: pitches)
        }
        containerView.addSubview(pitchTrackView)
        
        atBatGraphicView.translatesAutoresizingMaskIntoConstraints = false
        atBatGraphicView.configure(with: event, accentColor: accentColor)
        containerView.addSubview(atBatGraphicView)
        
        // Description
        descriptionLabel.font = AppFont.patrick(18, textStyle: .body, compatibleWith: traitCollection)
        descriptionLabel.textColor = pencilColor.withAlphaComponent(0.8)
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.adjustsFontForContentSizeCategory = true
        containerView.addSubview(descriptionLabel)
        
        // Pitches Table
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
        
        // Layout
        let topHeight: CGFloat = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 140 : 180
        
        NSLayoutConstraint.activate([
            titleStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            subHeaderLabel.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 4),
            subHeaderLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subHeaderLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Top Section (Left: Pitch Track, Right: Result Graphic)
            pitchTrackView.topAnchor.constraint(equalTo: subHeaderLabel.bottomAnchor, constant: 16),
            pitchTrackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            pitchTrackView.trailingAnchor.constraint(equalTo: containerView.centerXAnchor, constant: -10),
            
            atBatGraphicView.topAnchor.constraint(equalTo: pitchTrackView.topAnchor),
            atBatGraphicView.leadingAnchor.constraint(equalTo: containerView.centerXAnchor, constant: 10),
            atBatGraphicView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Description
            descriptionLabel.topAnchor.constraint(equalTo: pitchTrackView.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            
            // Table
            pitchesTableView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            pitchesTableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            pitchesTableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            pitchesTableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
        pitchTrackHeightConstraint = pitchTrackView.heightAnchor.constraint(equalToConstant: topHeight)
        pitchTrackHeightConstraint?.isActive = true
        atBatGraphicHeightConstraint = atBatGraphicView.heightAnchor.constraint(equalToConstant: topHeight)
        atBatGraphicHeightConstraint?.isActive = true
        pitchesTableHeightConstraint = pitchesTableView.heightAnchor.constraint(equalToConstant: 0)
        pitchesTableHeightConstraint?.isActive = true
        
        containerView.layer.addSublayer(linesLayer)

        let batterTap = UITapGestureRecognizer(target: self, action: #selector(handleBatterTap))
        batterLabel.addGestureRecognizer(batterTap)

        let pitcherTap = UITapGestureRecognizer(target: self, action: #selector(handlePitcherTap))
        subHeaderLabel.addGestureRecognizer(pitcherTap)
    }

    private func applyEventPresentation() {
        let presentation = AtBatPresentation(event: event, teamAccentColor: accentColor)
        resultLabel.text = presentation.displayResult
        resultLabel.transform = presentation.resultTransform
        descriptionLabel.text = presentation.displayDescription
        resultLabel.accessibilityLabel = "Result, \(presentation.displayResult)"
        descriptionLabel.accessibilityLabel = "Play description, \(presentation.displayDescription)"
        view.accessibilityLabel = AccessibilitySupport.joined([
            batterLabel.text,
            resultLabel.accessibilityLabel,
            subHeaderLabel.accessibilityLabel,
            descriptionLabel.accessibilityLabel
        ])
    }

    private func applyPitcherHeader() {
        let prefixAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.patrick(16, textStyle: .headline, compatibleWith: traitCollection),
            .foregroundColor: pencilColor.withAlphaComponent(0.7)
        ]
        let pitcherAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.patrick(16, textStyle: .headline, compatibleWith: traitCollection),
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
        let path = UIBezierPath()
        
        // Line under Header
        let headerY = subHeaderLabel.frame.maxY + 10
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 20, y: headerY), to: CGPoint(x: containerView.bounds.width - 20, y: headerY)))
        
        // Line under Description
        let descY = descriptionLabel.frame.maxY + 10
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 20, y: descY), to: CGPoint(x: containerView.bounds.width - 20, y: descY)))
        
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
            batterLabel as Any,
            resultLabel as Any,
            subHeaderLabel as Any,
            descriptionLabel as Any,
            pitchesTableView as Any
        ]
    }

    private func applyTypography() {
        batterLabel.font = AppFont.permanent(24, textStyle: .title1, compatibleWith: traitCollection)
        resultLabel.font = AppFont.permanent(32, textStyle: .largeTitle, compatibleWith: traitCollection)
        descriptionLabel.font = AppFont.patrick(18, textStyle: .body, compatibleWith: traitCollection)
        pitchSequenceHeaderLabel.font = AppFont.patrick(16, textStyle: .headline, compatibleWith: traitCollection)
        let topHeight: CGFloat = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 140 : 180
        pitchTrackHeightConstraint?.constant = topHeight
        atBatGraphicHeightConstraint?.constant = topHeight
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
    private let speedLabel = UILabel()
    private let typeLabel = UILabel()
    private let outcomeLabel = UILabel()
    private var compactConstraints: [NSLayoutConstraint] = []
    private var accessibilityConstraints: [NSLayoutConstraint] = []
    
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
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        
        [numLabel, descLabel, speedLabel, typeLabel, outcomeLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
            $0.textColor = AppColors.pencil
            $0.font = AppFont.patrick(18, textStyle: .body)
            $0.isAccessibilityElement = false
            $0.adjustsFontForContentSizeCategory = true
        }
        
        numLabel.font = AppFont.permanent(16, textStyle: .headline)
        numLabel.textColor = .gray
        descLabel.font = AppFont.permanent(18, textStyle: .body)
        descLabel.numberOfLines = 0
        outcomeLabel.numberOfLines = 0
        
        speedLabel.textAlignment = .right
        speedLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        speedLabel.setContentHuggingPriority(.required, for: .horizontal)
        speedLabel.numberOfLines = 0
        speedLabel.font = AppFont.patrick(14, textStyle: .footnote)
        speedLabel.textColor = AppColors.pencil.withAlphaComponent(0.7)

        typeLabel.font = AppFont.permanent(18, textStyle: .body)
        typeLabel.textColor = AppColors.pencil
        typeLabel.textAlignment = .right
        typeLabel.numberOfLines = 0
        typeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        typeLabel.setContentHuggingPriority(.required, for: .horizontal)

        compactConstraints = [
            numLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            numLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            numLabel.widthAnchor.constraint(equalToConstant: 32),
            
            descLabel.leadingAnchor.constraint(equalTo: numLabel.trailingAnchor, constant: 8),
            descLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            descLabel.trailingAnchor.constraint(lessThanOrEqualTo: speedLabel.leadingAnchor, constant: -8),
            
            outcomeLabel.leadingAnchor.constraint(equalTo: descLabel.leadingAnchor),
            outcomeLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 2),
            outcomeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            speedLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            typeLabel.trailingAnchor.constraint(equalTo: speedLabel.trailingAnchor),
            typeLabel.topAnchor.constraint(equalTo: descLabel.topAnchor),
            typeLabel.widthAnchor.constraint(equalToConstant: 96),

            speedLabel.trailingAnchor.constraint(equalTo: typeLabel.trailingAnchor),
            speedLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 2),
            typeLabel.widthAnchor.constraint(equalTo: speedLabel.widthAnchor)
        ]

        accessibilityConstraints = [
            numLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            numLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            numLabel.widthAnchor.constraint(equalToConstant: 32),

            descLabel.leadingAnchor.constraint(equalTo: numLabel.trailingAnchor, constant: 8),
            descLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            descLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            outcomeLabel.leadingAnchor.constraint(equalTo: descLabel.leadingAnchor),
            outcomeLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 2),
            outcomeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            typeLabel.leadingAnchor.constraint(equalTo: descLabel.leadingAnchor),
            typeLabel.topAnchor.constraint(equalTo: outcomeLabel.bottomAnchor, constant: 4),
            typeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            speedLabel.leadingAnchor.constraint(equalTo: descLabel.leadingAnchor),
            speedLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 2),
            speedLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            speedLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ]

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: PitchCell, _) in
            self.updateLayoutForCurrentContentSizeCategory()
        }
        updateLayoutForCurrentContentSizeCategory()
    }
    
    func configure(with pitch: PitchEvent) {
        numLabel.text = "\(pitch.pitchNumber)."
        descLabel.text = pitch.description
        outcomeLabel.font = AppFont.patrick(14, textStyle: .footnote)
        outcomeLabel.textColor = .gray
        outcomeLabel.text = subtitleText(for: pitch)
        outcomeLabel.isHidden = outcomeLabel.text?.isEmpty ?? true
        
        speedLabel.text = speedText(for: pitch)
        typeLabel.text = pitch.pitchType?.trimmingCharacters(in: .whitespacesAndNewlines)
        typeLabel.isHidden = typeLabel.text?.isEmpty ?? true
        updateLayoutForCurrentContentSizeCategory()
        accessibilityLabel = AccessibilitySupport.pitchDescription(pitch)
    }

    private func updateLayoutForCurrentContentSizeCategory() {
        let isAccessibility = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        NSLayoutConstraint.deactivate(compactConstraints + accessibilityConstraints)
        if isAccessibility {
            speedLabel.textAlignment = .left
            typeLabel.textAlignment = .left
            NSLayoutConstraint.activate(accessibilityConstraints)
        } else {
            speedLabel.textAlignment = .right
            typeLabel.textAlignment = .right
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

    private func speedText(for pitch: PitchEvent) -> String {
        let speed = pitch.speed.map { String(format: "%.0f mph", $0) }

        switch speed {
        case let speed?:
            return speed
        default:
            return ""
        }
    }
}
