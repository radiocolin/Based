import UIKit

final class ScorecardHelpViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.paper
        setupNavBar()
        setupLayout()
        populateContent()
    }

    private func setupNavBar() {
        title = "How to Read a Scorecard"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )

        let titleFont = AppFont.ibmPlexCondensedBold(20, textStyle: .headline)
        let buttonFont = AppFont.patrick(18, textStyle: .body)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.paper
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: AppColors.pencil
        ]
        BarAppearanceSupport.applyPlainBarButtonAppearance(
            appearance.buttonAppearance,
            font: buttonFont,
            color: AppColors.pencil
        )
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = AppColors.pencil
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func populateContent() {
        contentStack.addArrangedSubview(makeIntroCard())
        contentStack.addArrangedSubview(makeExampleCard())
        contentStack.addArrangedSubview(makeRosterCard())
    }

    private func makeIntroCard() -> UIView {
        let card = LegendCardView(title: "Reading the Box")
        card.addBody("""
        Each square is one plate appearance. The center tells you what happened, the diamond shows how far runners moved, and the corners hold the count and out state for that play.
        """)
        card.addBody("""
        There are a few app-specific marks so you can spot inning breaks, pitching changes, scoring plays, and runner annotations without opening the at-bat detail sheet.
        """)
        return card
    }

    private func makeExampleCard() -> UIView {
        let card = LegendCardView(title: "Examples")
        card.addCustomView(ScorecardPlayPagerView())
        return card
    }

    private func makeRosterCard() -> UIView {
        let card = LegendCardView(title: "Names and Grid Conventions")
        card.addCustomView(ScorecardRosterLegendView())
        return card
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }
}

private final class LegendCardView: UIView {
    private let stack = UIStackView()

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppFont.ibmPlexCondensedBold(20, textStyle: .headline)
        titleLabel.textColor = AppColors.pencil
        titleLabel.numberOfLines = 0
        stack.addArrangedSubview(titleLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addBody(_ text: String) {
        let label = makeBodyLabel(text)
        stack.addArrangedSubview(label)
    }

    func addBullet(_ text: String) {
        let label = makeBodyLabel("• \(text)")
        stack.addArrangedSubview(label)
    }

    func addCustomView(_ view: UIView) {
        stack.addArrangedSubview(view)
    }

    private func makeBodyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppFont.ibmPlexCondensed(16, textStyle: .body)
        label.textColor = AppColors.pencil.withAlphaComponent(0.88)
        label.numberOfLines = 0
        return label
    }
}

private struct ScorecardExample {
    let title: String
    let code: String
    let highlight: String
    let event: AtBatEvent
    let flipsCodeLabel: Bool

    init(title: String, code: String, highlight: String, event: AtBatEvent, flipsCodeLabel: Bool = false) {
        self.title = title
        self.code = code
        self.highlight = highlight
        self.event = event
        self.flipsCodeLabel = flipsCodeLabel
    }
}

private final class ScorecardPlayPagerView: UIView, UIScrollViewDelegate {
    private let examples: [ScorecardExample] = ScorecardExamples.all
    private let pageControl = UIPageControl()
    private let scrollView = UIScrollView()
    private let pagesStack = UIStackView()
    private var pageViews: [ScorecardPlayPageView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isPagingEnabled = true
        scrollView.decelerationRate = .fast
        scrollView.delegate = self
        stack.addArrangedSubview(scrollView)

        pagesStack.axis = .horizontal
        pagesStack.spacing = 0
        pagesStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(pagesStack)

        pageViews = examples.map { example in
            let page = ScorecardPlayPageView()
            page.configure(with: example)
            return page
        }
        pageViews.forEach { pagesStack.addArrangedSubview($0) }

        pageControl.numberOfPages = examples.count
        pageControl.currentPage = 0
        pageControl.currentPageIndicatorTintColor = AppColors.pencil
        pageControl.pageIndicatorTintColor = AppColors.grid
        pageControl.isUserInteractionEnabled = false
        stack.addArrangedSubview(pageControl)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 344),

            pagesStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            pagesStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            pagesStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            pagesStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            pagesStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        pageViews.forEach { page in
            page.translatesAutoresizingMaskIntoConstraints = false
            page.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let width = max(scrollView.bounds.width, 1)
        let page = Int(round(scrollView.contentOffset.x / width))
        pageControl.currentPage = max(0, min(examples.count - 1, page))
    }
}

private final class ScorecardPlayPageView: UIView {
    private let scorecardGraphic = AtBatGraphicView()
    private let titleLabel = UILabel()
    private let codeLabel = UILabel()
    private let highlightLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        scorecardGraphic.translatesAutoresizingMaskIntoConstraints = false
        scorecardGraphic.layer.borderWidth = 0.5
        scorecardGraphic.layer.borderColor = AppColors.grid.cgColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = AppFont.patrick(24, textStyle: .title3)
        titleLabel.textColor = AppColors.pencil
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        codeLabel.translatesAutoresizingMaskIntoConstraints = false
        codeLabel.font = AppFont.ibmPlexCondensedBold(15, textStyle: .headline)
        codeLabel.textColor = AppColors.pencil.withAlphaComponent(0.72)
        codeLabel.textAlignment = .center
        codeLabel.numberOfLines = 0

        highlightLabel.translatesAutoresizingMaskIntoConstraints = false
        highlightLabel.font = AppFont.ibmPlexCondensed(16, textStyle: .body)
        highlightLabel.textColor = AppColors.pencil.withAlphaComponent(0.86)
        highlightLabel.textAlignment = .center
        highlightLabel.numberOfLines = 3

        [scorecardGraphic, titleLabel, codeLabel, highlightLabel].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            scorecardGraphic.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            scorecardGraphic.centerXAnchor.constraint(equalTo: centerXAnchor),
            scorecardGraphic.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            scorecardGraphic.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            scorecardGraphic.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.62),
            scorecardGraphic.heightAnchor.constraint(equalTo: scorecardGraphic.widthAnchor),
            titleLabel.topAnchor.constraint(equalTo: scorecardGraphic.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            codeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            codeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            codeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            highlightLabel.topAnchor.constraint(equalTo: codeLabel.bottomAnchor, constant: 8),
            highlightLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            highlightLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            highlightLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with example: ScorecardExample) {
        scorecardGraphic.configure(with: example.event)
        titleLabel.text = example.title
        codeLabel.text = example.code
        codeLabel.transform = example.flipsCodeLabel ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        highlightLabel.text = example.highlight
    }
}

private enum ScorecardExamples {
    static let scoringExampleEvent = makeEvent(
        result: .homeRun,
        description: "Home run to left.",
        balls: 3,
        strikes: 2,
        outs: 1,
        rbi: 1,
        bases: .init(first: false, second: false, third: false, home: true, lineToFirst: true, lineToSecond: true, lineToThird: true, lineToHome: true, outAtFirst: nil, outAtSecond: nil, outAtThird: nil, outAtHome: nil, annotations: nil)
    )

    static let pitchingChangeExampleEvent = makeEvent(
        result: .walk,
        description: "Walk.",
        balls: 4,
        strikes: 1,
        outs: 1,
        bases: .init(first: true, second: false, third: false, home: false, lineToFirst: true, lineToSecond: false, lineToThird: false, lineToHome: false, outAtFirst: nil, outAtSecond: nil, outAtThird: nil, outAtHome: nil, annotations: nil)
    )

    static let inningBreakExampleEvent = makeEvent(
        result: .single,
        description: "Single to center.",
        balls: 1,
        strikes: 2,
        outs: 0,
        bases: .init(first: true, second: false, third: false, home: false, lineToFirst: true, lineToSecond: false, lineToThird: false, lineToHome: false, outAtFirst: nil, outAtSecond: nil, outAtThird: nil, outAtHome: nil, annotations: nil)
    )

    static let all: [ScorecardExample] = [
        ScorecardExample(
            title: "Single",
            code: "1B",
            highlight: "Path stops at first.",
            event: makeEvent(result: .single, description: "Single to left.", balls: 1, strikes: 1, outs: 0, bases: .init(first: true, second: false, third: false, home: false, lineToFirst: true, lineToSecond: false, lineToThird: false, lineToHome: false, outAtFirst: nil, outAtSecond: nil, outAtThird: nil, outAtHome: nil, annotations: nil))
        ),
        ScorecardExample(
            title: "Walk",
            code: "BB",
            highlight: "Free pass, same first-base path.",
            event: makeEvent(result: .walk, description: "Walk.", balls: 4, strikes: 1, outs: 1, bases: .init(first: true, second: false, third: false, home: false, lineToFirst: true, lineToSecond: false, lineToThird: false, lineToHome: false, outAtFirst: nil, outAtSecond: nil, outAtThird: nil, outAtHome: nil, annotations: nil))
        ),
        ScorecardExample(
            title: "Called Strikeout",
            code: "K",
            highlight: "A mirrored K means strike three looking.",
            event: makeEvent(result: .strikeoutLooking, description: "Called out on strikes.", balls: 2, strikes: 3, outs: 1, bases: .init(first: false, second: false, third: false, home: false, lineToFirst: false, lineToSecond: false, lineToThird: false, lineToHome: false, outAtFirst: nil, outAtSecond: nil, outAtThird: nil, outAtHome: nil, annotations: nil)),
            flipsCodeLabel: true
        ),
        ScorecardExample(
            title: "Groundout",
            code: "6-3",
            highlight: "Shortstop to first; no base advance.",
            event: makeEvent(result: .groundout(sequence: "6-3"), description: "Groundout, shortstop to first.", balls: 0, strikes: 2, outs: 2, bases: .init(first: false, second: false, third: false, home: false, lineToFirst: false, lineToSecond: false, lineToThird: false, lineToHome: false, outAtFirst: nil, outAtSecond: nil, outAtThird: nil, outAtHome: nil, annotations: nil))
        ),
        ScorecardExample(
            title: "Home Run",
            code: "HR",
            highlight: "Full path and color tint mean a run scored.",
            event: scoringExampleEvent
        ),
        ScorecardExample(
            title: "Error",
            code: "E6",
            highlight: "Error note sits by the base reached.",
            event: makeEvent(result: .fieldError, description: "Reached on shortstop's error.", balls: 0, strikes: 1, outs: 2, bases: .init(first: true, second: false, third: false, home: false, lineToFirst: true, lineToSecond: false, lineToThird: false, lineToHome: false, outAtFirst: nil, outAtSecond: nil, outAtThird: nil, outAtHome: nil, annotations: [BaseAnnotation(kind: .error, base: 1, label: "E6")]))
        ),
        ScorecardExample(
            title: "Stolen Base",
            code: "1B + SB",
            highlight: "The steal note stays on the runner's original box.",
            event: makeEvent(result: .single, description: "Single to center; later stole second.", balls: 1, strikes: 2, outs: 1, bases: .init(first: true, second: true, third: false, home: false, lineToFirst: true, lineToSecond: true, lineToThird: false, lineToHome: false, outAtFirst: nil, outAtSecond: nil, outAtThird: nil, outAtHome: nil, annotations: [BaseAnnotation(kind: .stolenBase, base: 2, label: "SB")]))
        ),
        ScorecardExample(
            title: "Caught Stealing",
            code: "2B + CS",
            highlight: "The slash and CS mark the runner getting erased at the next base.",
            event: makeEvent(result: .double, description: "Double to left; later caught stealing third.", balls: 2, strikes: 1, outs: 2, bases: .init(first: true, second: true, third: false, home: false, lineToFirst: true, lineToSecond: true, lineToThird: true, lineToHome: false, outAtFirst: nil, outAtSecond: nil, outAtThird: true, outAtHome: nil, annotations: [BaseAnnotation(kind: .caughtStealing, base: 3, label: "CS")]))
        )
    ]

    private static func makeEvent(
        result: ScorecardResult,
        description: String,
        balls: Int,
        strikes: Int,
        outs: Int,
        rbi: Int = 0,
        isRunnerOnly: Bool = false,
        bases: BasesReached
    ) -> AtBatEvent {
        AtBatEvent(
            atBatIndex: 0,
            batterId: 1,
            batterName: "Example Batter",
            pinchRunnerName: nil,
            pitcherId: 2,
            pitcherName: "Example Pitcher",
            previousPitcherName: nil,
            inning: 1,
            isTop: true,
            result: result,
            description: description,
            balls: balls,
            strikes: strikes,
            outs: outs,
            rbi: rbi,
            isRunnerOnly: isRunnerOnly,
            isPitchingChange: false,
            bases: bases,
            pitches: nil
        )
    }
}

private final class ScorecardRosterLegendView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        stack.addArrangedSubview(makeSectionTitle("Name Column"))
        stack.addArrangedSubview(makeNameCellVisual(name: "TURNER", detail: "SS #7"))
        stack.addArrangedSubview(makeCaption("The scorecard shows the player's last name, then position and jersey number on the second line."))
        stack.addArrangedSubview(makeDivider())

        stack.addArrangedSubview(makeSectionTitle("Late Entry"))
        stack.addArrangedSubview(makeNameCellVisual(name: "MARSH", detail: "LF #16 (8)"))
        stack.addArrangedSubview(makeCaption("A player who enters later keeps the same format, with the inning entered appended in parentheses."))
        stack.addArrangedSubview(makeDivider())

        stack.addArrangedSubview(makeSectionTitle("Pitching Change"))
        stack.addArrangedSubview(makeInlineMarkedExampleRow(
            style: .pitchingChange,
            event: ScorecardExamples.pitchingChangeExampleEvent,
            detail: "A solid line above the box marks the first batter faced by a new pitcher."
        ))
        stack.addArrangedSubview(makeDivider())

        stack.addArrangedSubview(makeSectionTitle("Inning Headers"))
        stack.addArrangedSubview(makeHeaderVisual())
        stack.addArrangedSubview(makeCaption("If an inning needs multiple plate-appearance columns, that inning gets wider instead of creating a new header label."))
        stack.addArrangedSubview(makeDivider())

        stack.addArrangedSubview(makeSectionTitle("Compact Columns"))
        stack.addArrangedSubview(makeCompactColumnsVisual())
        stack.addArrangedSubview(makeCaption("In compact view, a new column is only added when the order bats around. The header shows the inning range covered by that compact column."))
        stack.addArrangedSubview(makeInlineMarkedExampleRow(
            style: .inningBreak,
            event: ScorecardExamples.inningBreakExampleEvent,
            detail: "In compact view, a dashed line marks an inning break before the next box."
        ))

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeNameCellVisual(name: String, detail: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let topLine = UIView()
        topLine.translatesAutoresizingMaskIntoConstraints = false
        topLine.backgroundColor = AppColors.grid

        let bottomLine = UIView()
        bottomLine.translatesAutoresizingMaskIntoConstraints = false
        bottomLine.backgroundColor = AppColors.grid

        let scoreboxDivider = UIView()
        scoreboxDivider.translatesAutoresizingMaskIntoConstraints = false
        scoreboxDivider.backgroundColor = AppColors.grid

        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = UIFont(name: AppFont.permanentMarker, size: 16) ?? .systemFont(ofSize: 16)
        nameLabel.textColor = AppColors.pencil

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = UIFont(name: AppFont.patrickHand, size: 14) ?? .systemFont(ofSize: 14)
        detailLabel.textColor = AppColors.pencil.withAlphaComponent(0.5)

        [topLine, bottomLine, scoreboxDivider, nameLabel, detailLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 62),
            topLine.topAnchor.constraint(equalTo: row.topAnchor),
            topLine.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            topLine.heightAnchor.constraint(equalToConstant: 1),
            bottomLine.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            bottomLine.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            bottomLine.heightAnchor.constraint(equalToConstant: 1),
            scoreboxDivider.topAnchor.constraint(equalTo: row.topAnchor),
            scoreboxDivider.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            scoreboxDivider.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 118),
            scoreboxDivider.widthAnchor.constraint(equalToConstant: 1),
            nameLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            nameLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -14),
            detailLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -14)
        ])

        return row
    }

    private func makeHeaderVisual() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 0
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        var labels: [UILabel] = []
        ["1", "2", "3", "4", "5"].forEach { text in
            let label = UILabel()
            label.text = text
            label.font = AppFont.ibmPlexCondensedBold(16, textStyle: .caption1)
            label.textColor = AppColors.pencil
            label.textAlignment = .center
            label.backgroundColor = AppColors.paper
            label.layer.borderWidth = 0.5
            label.layer.borderColor = AppColors.grid.cgColor
            label.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(label)
            labels.append(label)
        }

        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.layer.cornerRadius = 12
        wrap.clipsToBounds = true
        wrap.addSubview(stack)

        NSLayoutConstraint.activate([
            wrap.heightAnchor.constraint(equalToConstant: 34),
            stack.topAnchor.constraint(equalTo: wrap.topAnchor),
            stack.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: wrap.bottomAnchor)
        ])

        if let first = labels.first {
            labels.dropFirst().dropLast().forEach { label in
                label.widthAnchor.constraint(equalTo: first.widthAnchor).isActive = true
            }
            if let last = labels.last {
                last.widthAnchor.constraint(equalTo: first.widthAnchor, multiplier: 2).isActive = true
            }
        }

        return wrap
    }

    private func makeCompactColumnsVisual() -> UIView {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false

        let caption = UILabel()
        caption.font = AppFont.ibmPlexCondensed(14, textStyle: .caption1)
        caption.textColor = AppColors.pencil.withAlphaComponent(0.72)
        caption.textAlignment = .left
        caption.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(caption)

        let header = UIStackView()
        header.axis = .horizontal
        header.spacing = 0
        header.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(header)

        let body = UIStackView()
        body.axis = .horizontal
        body.spacing = 0
        body.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(body)

        let headerSpecs: [String] = ["1-3", "3-6", "7-8"]
        var headerLabels: [UILabel] = []
        headerSpecs.forEach { text in
            let label = UILabel()
            label.text = text
            label.font = AppFont.ibmPlexCondensedBold(15, textStyle: .caption1)
            label.textColor = AppColors.pencil
            label.textAlignment = .center
            label.backgroundColor = AppColors.paper
            label.layer.borderWidth = 0.5
            label.layer.borderColor = AppColors.grid.cgColor
            label.translatesAutoresizingMaskIntoConstraints = false
            header.addArrangedSubview(label)
            headerLabels.append(label)
        }

        let bodySpecs: [String] = ["First trip", "Second trip", "Third trip"]
        var bodyLabels: [UILabel] = []
        bodySpecs.forEach { text in
            let label = UILabel()
            label.text = text
            label.font = AppFont.patrick(16, textStyle: .body)
            label.textColor = AppColors.pencil.withAlphaComponent(0.88)
            label.textAlignment = .center
            label.backgroundColor = AppColors.header.withAlphaComponent(0.2)
            label.layer.borderWidth = 0.5
            label.layer.borderColor = AppColors.grid.cgColor
            label.translatesAutoresizingMaskIntoConstraints = false
            body.addArrangedSubview(label)
            bodyLabels.append(label)
        }

        NSLayoutConstraint.activate([
            caption.topAnchor.constraint(equalTo: wrap.topAnchor),
            caption.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            caption.trailingAnchor.constraint(lessThanOrEqualTo: wrap.trailingAnchor),
            header.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 32),
            body.topAnchor.constraint(equalTo: header.bottomAnchor),
            body.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            body.bottomAnchor.constraint(equalTo: wrap.bottomAnchor)
        ])

        if let firstHeader = headerLabels.first, let firstBody = bodyLabels.first {
            headerLabels.dropFirst().forEach { $0.widthAnchor.constraint(equalTo: firstHeader.widthAnchor).isActive = true }
            bodyLabels.dropFirst().forEach { $0.widthAnchor.constraint(equalTo: firstBody.widthAnchor).isActive = true }
            zip(headerLabels, bodyLabels).forEach { headerLabel, bodyLabel in
                headerLabel.widthAnchor.constraint(equalTo: bodyLabel.widthAnchor).isActive = true
            }
        }

        return wrap
    }

    private func makeMarkedExampleCell(style: DashedGuideLineView.Style, event: AtBatEvent, size: CGFloat = 132) -> UIView {
        let cell = ScorecardPreviewView()
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.configure(with: event)
        switch style {
        case .inningBreak:
            cell.showInningBreak(true)
        case .pitchingChange:
            cell.showPitchingChange(true)
        }
        NSLayoutConstraint.activate([
            cell.widthAnchor.constraint(equalToConstant: size),
            cell.heightAnchor.constraint(equalToConstant: size)
        ])
        return cell
    }

    private func makeInlineMarkedExampleRow(style: DashedGuideLineView.Style, event: AtBatEvent, detail: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false

        let cell = makeMarkedExampleCell(style: style, event: event, size: 52)
        row.addArrangedSubview(cell)
        cell.setContentHuggingPriority(.required, for: .horizontal)
        cell.setContentCompressionResistancePriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = detail
        label.font = AppFont.ibmPlexCondensed(14, textStyle: .caption1)
        label.textColor = AppColors.pencil.withAlphaComponent(0.82)
        label.numberOfLines = 0
        row.addArrangedSubview(label)

        return row
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppFont.patrick(18, textStyle: .body)
        label.textColor = AppColors.pencil
        return label
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = AppColors.grid.withAlphaComponent(0.5)
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return divider
    }

    private func makeCaption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppFont.ibmPlexCondensed(14, textStyle: .caption1)
        label.textColor = AppColors.pencil.withAlphaComponent(0.82)
        label.numberOfLines = 0
        return label
    }
}

private final class ScorecardMarkerLegendView: UIView {
    init(title: String, detail: String, style: MarkerPreviewView.Style) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        let cell = MarkerPreviewView(style: style)
        cell.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cell.widthAnchor.constraint(equalToConstant: 64),
            cell.heightAnchor.constraint(equalToConstant: 64)
        ])
        row.addArrangedSubview(cell)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppFont.patrick(18, textStyle: .body)
        titleLabel.textColor = AppColors.pencil
        titleLabel.numberOfLines = 0

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = AppFont.ibmPlexCondensed(15, textStyle: .body)
        detailLabel.textColor = AppColors.pencil.withAlphaComponent(0.85)
        detailLabel.numberOfLines = 0

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(detailLabel)
        row.addArrangedSubview(textStack)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ScorecardPreviewView: UIView {
    private let diamondView = DiamondView()
    private let resultLabel = UILabel()
    private let ballsLabel = UILabel()
    private let strikesLabel = UILabel()
    private let outsLabel = UILabel()
    private let pitchingChangeLayer = CAShapeLayer()
    private let inningBreakLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        layer.borderWidth = 0.5
        layer.borderColor = AppColors.grid.cgColor
        clipsToBounds = false

        diamondView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(diamondView)

        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.font = UIFont(name: AppFont.permanentMarker, size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        resultLabel.textColor = AppColors.pencil
        resultLabel.textAlignment = .center
        resultLabel.numberOfLines = 0
        resultLabel.adjustsFontSizeToFitWidth = true
        resultLabel.minimumScaleFactor = 0.5
        addSubview(resultLabel)

        [ballsLabel, strikesLabel, outsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont(name: AppFont.patrickHand, size: 12) ?? .systemFont(ofSize: 12)
            $0.textColor = AppColors.pencil
            $0.textAlignment = .center
            addSubview($0)
        }

        pitchingChangeLayer.strokeColor = AppColors.pencil.cgColor
        pitchingChangeLayer.lineWidth = 2.5
        pitchingChangeLayer.lineCap = .round
        pitchingChangeLayer.fillColor = nil
        pitchingChangeLayer.isHidden = true
        layer.addSublayer(pitchingChangeLayer)

        inningBreakLayer.strokeColor = AppColors.pencil.cgColor
        inningBreakLayer.lineWidth = 2.5
        inningBreakLayer.lineCap = .round
        inningBreakLayer.lineDashPattern = [5, 4]
        inningBreakLayer.fillColor = nil
        inningBreakLayer.isHidden = true
        layer.addSublayer(inningBreakLayer)

        NSLayoutConstraint.activate([
            diamondView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            diamondView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            diamondView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            diamondView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            resultLabel.centerXAnchor.constraint(equalTo: diamondView.centerXAnchor),
            resultLabel.centerYAnchor.constraint(equalTo: diamondView.centerYAnchor),

            ballsLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            ballsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),

            strikesLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            strikesLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),

            outsLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            outsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with event: AtBatEvent) {
        let presentation = AtBatPresentation(event: event)
        resultLabel.attributedText = presentation.resultAttributedString(
            font: resultLabel.font ?? .systemFont(ofSize: 18)
        )
        resultLabel.transform = presentation.resultTransform
        ballsLabel.text = presentation.ballsText
        strikesLabel.text = presentation.strikesText
        outsLabel.text = presentation.outsText
        ballsLabel.textColor = presentation.primaryColor
        strikesLabel.textColor = presentation.primaryColor
        outsLabel.textColor = presentation.primaryColor

        diamondView.configure(
            with: event.bases,
            style: .scorecard,
            isRun: event.result.isHomeRun,
            accentColor: presentation.diamondAccentColor
        )
    }

    func showPitchingChange(_ show: Bool) {
        pitchingChangeLayer.isHidden = !show
        setNeedsLayout()
    }

    func showInningBreak(_ show: Bool) {
        inningBreakLayer.isHidden = !show
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.borderColor = AppColors.grid.cgColor
        let topY: CGFloat = -1

        if !pitchingChangeLayer.isHidden {
            let pitchPath = UIBezierPath.pencilLine(
                from: CGPoint(x: -0.5, y: topY),
                to: CGPoint(x: bounds.width + 0.5, y: topY),
                jitter: 0.4
            )
            pitchingChangeLayer.path = pitchPath.cgPath
        }

        if !inningBreakLayer.isHidden {
            let inningPath = UIBezierPath()
            inningPath.move(to: CGPoint(x: 2, y: 2))
            inningPath.addLine(to: CGPoint(x: bounds.width - 2, y: 2))
            inningBreakLayer.path = inningPath.cgPath
        }
    }
}

private final class DashedGuideLineView: UIView {
    enum Style {
        case inningBreak
        case pitchingChange
    }

    private let style: Style
    private let lineLayer = CAShapeLayer()

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        backgroundColor = .clear
        lineLayer.strokeColor = AppColors.pencil.cgColor
        lineLayer.fillColor = nil
        lineLayer.lineWidth = 2.5
        lineLayer.lineCap = .round
        if style == .inningBreak {
            lineLayer.lineDashPattern = [5, 4]
        }
        layer.addSublayer(lineLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath()
        let y = bounds.midY
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: bounds.width, y: y))
        lineLayer.path = path.cgPath
    }
}

private final class MarkerPreviewView: UIView {
    enum Style {
        case inningBreak
        case pitchingChange
    }

    private let style: Style
    private let lineLayer = CAShapeLayer()

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        backgroundColor = AppColors.paper
        layer.cornerRadius = 0
        layer.borderWidth = 0.5
        layer.borderColor = AppColors.grid.cgColor

        lineLayer.strokeColor = AppColors.pencil.cgColor
        lineLayer.fillColor = nil
        lineLayer.lineWidth = 2.5
        lineLayer.lineCap = .round
        if style == .inningBreak {
            lineLayer.lineDashPattern = [5, 4]
        }
        layer.addSublayer(lineLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.borderColor = AppColors.grid.cgColor
        lineLayer.strokeColor = AppColors.pencil.cgColor
        let path = UIBezierPath()
        let y: CGFloat = style == .inningBreak ? 2 : 0
        path.move(to: CGPoint(x: 2, y: y + 2))
        path.addLine(to: CGPoint(x: bounds.width - 2, y: y + 2))
        lineLayer.path = path.cgPath
    }
}
