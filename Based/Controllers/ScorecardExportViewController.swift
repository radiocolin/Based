import UIKit

class ScorecardExportViewController: UIViewController {

    private let scorecard: ScorecardData
    private let linescore: Linescore?
    private var options = ScorecardExportOptions()

    private let scrollView = UIScrollView()
    private let previewImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.layer.borderWidth = 0.5
        iv.layer.borderColor = AppColors.grid.cgColor
        iv.layer.cornerRadius = 4
        iv.clipsToBounds = true
        iv.backgroundColor = AppColors.paper
        return iv
    }()
    private let toggleStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 0
        return s
    }()
    private let buttonStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 12
        s.distribution = .fillEqually
        return s
    }()

    private var atBatResultsToggle: UISwitch?
    private var previewTask: Task<Void, Never>?

    init(scorecard: ScorecardData, linescore: Linescore?) {
        self.scorecard = scorecard
        self.linescore = linescore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.paper
        setupNavBar()
        setupLayout()
        setupToggles()
        setupButtons()
        refreshPreview()
    }

    private func setupNavBar() {
        title = "Export Scorecard"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))

        let titleFont = UIFont(name: "IBMPlexSansCond-Bold", size: 20) ?? .systemFont(ofSize: 20, weight: .bold)
        let buttonFont = UIFont(name: "PatrickHand-Regular", size: 18) ?? .systemFont(ofSize: 18)
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

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        toggleStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let previewContainer = UIView()
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewImageView)

        contentStack.addArrangedSubview(previewContainer)
        contentStack.addArrangedSubview(toggleStack)
        contentStack.addArrangedSubview(buttonStack)

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(spacer)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),

            previewImageView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            previewImageView.heightAnchor.constraint(equalTo: previewImageView.widthAnchor, multiplier: 612.0 / 792.0),

            buttonStack.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func setupToggles() {
        let items: [(String, Bool, WritableKeyPath<ScorecardExportOptions, Bool>)] = [
            ("Scoreboard", options.showScoreboard, \.showScoreboard),
            ("Game Info", options.showGameInfo, \.showGameInfo),
            ("Lineup", options.showLineup, \.showLineup),
            ("At-Bat Results", options.showAtBatResults, \.showAtBatResults),
            ("Pitchers", options.showPitchers, \.showPitchers),
            ("Umpires", options.showUmpires, \.showUmpires),
        ]

        for (label, isOn, keyPath) in items {
            let row = makeToggleRow(title: label, isOn: isOn, keyPath: keyPath)
            toggleStack.addArrangedSubview(row)
        }
    }

    private func makeToggleRow(title: String, isOn: Bool, keyPath: WritableKeyPath<ScorecardExportOptions, Bool>) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = UIFont(name: "PatrickHand-Regular", size: 20) ?? .systemFont(ofSize: 20)
        label.textColor = AppColors.pencil
        label.translatesAutoresizingMaskIntoConstraints = false

        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.onTintColor = AppColors.pencil.withAlphaComponent(0.5)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.addAction(UIAction { [weak self] action in
            guard let self, let sw = action.sender as? UISwitch else { return }
            self.options[keyPath: keyPath] = sw.isOn
            if keyPath == \.showLineup {
                if let abToggle = self.atBatResultsToggle {
                    abToggle.isEnabled = sw.isOn
                    if !sw.isOn {
                        abToggle.setOn(false, animated: true)
                        self.options.showAtBatResults = false
                    }
                }
            }
            self.refreshPreview()
        }, for: .valueChanged)

        if keyPath == \.showAtBatResults {
            atBatResultsToggle = toggle
        }

        let separator = UIView()
        separator.backgroundColor = AppColors.grid
        separator.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(toggle)
        container.addSubview(separator)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 52),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            toggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        return container
    }

    private func setupButtons() {
        let imageBtn = makeExportButton(title: "Share Image", icon: "photo")
        imageBtn.addTarget(self, action: #selector(shareImageTapped), for: .touchUpInside)

        let pdfBtn = makeExportButton(title: "Save PDF", icon: "doc.richtext")
        pdfBtn.addTarget(self, action: #selector(sharePDFTapped), for: .touchUpInside)

        buttonStack.addArrangedSubview(imageBtn)
        buttonStack.addArrangedSubview(pdfBtn)
    }

    private func makeExportButton(title: String, icon: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 8
        config.cornerStyle = .medium
        config.baseBackgroundColor = AppColors.pencil.withAlphaComponent(0.12)
        config.baseForegroundColor = AppColors.pencil

        let font = UIFont(name: "IBMPlexSansCond-Bold", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = font
            return out
        }

        let btn = UIButton(configuration: config)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth = 1
        btn.layer.borderColor = AppColors.grid.cgColor
        return btn
    }

    private func refreshPreview() {
        previewTask?.cancel()
        previewTask = Task {
            let generator = ScorecardImageGenerator()
            let image = await generator.generate(scorecard: scorecard, linescore: linescore, options: options)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.previewImageView.image = image
            }
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func shareImageTapped() {
        exportWith { generator, sc, ls, opts in
            await generator.generate(scorecard: sc, linescore: ls, options: opts)
        } present: { image in
            let awayName = self.scorecard.teams.away.name ?? "Away"
            let homeName = self.scorecard.teams.home.name ?? "Home"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(awayName) vs \(homeName) Scorecard.png")
            try? image.pngData()?.write(to: tempURL)
            return tempURL
        }
    }

    @objc private func sharePDFTapped() {
        exportWith { generator, sc, ls, opts in
            await generator.generatePDF(scorecard: sc, linescore: ls, options: opts)
        } present: { data in
            let awayName = self.scorecard.teams.away.name ?? "Away"
            let homeName = self.scorecard.teams.home.name ?? "Home"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(awayName) vs \(homeName) Scorecard.pdf")
            try? data.write(to: tempURL)
            return tempURL
        }
    }

    private func exportWith<T>(generate: @escaping (ScorecardImageGenerator, ScorecardData, Linescore?, ScorecardExportOptions) async -> T, present: @escaping (T) -> URL) {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        view.isUserInteractionEnabled = false

        let opts = options
        let sc = scorecard
        let ls = linescore

        Task {
            let generator = ScorecardImageGenerator()
            let result = await generate(generator, sc, ls, opts)

            await MainActor.run {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                self.view.isUserInteractionEnabled = true

                let url = present(result)
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = self.buttonStack
                    popover.sourceRect = self.buttonStack.bounds
                }
                self.present(activityVC, animated: true)
            }
        }
    }
}
