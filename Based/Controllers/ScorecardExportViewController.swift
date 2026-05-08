import UIKit

class ScorecardExportViewController: UIViewController {

    private let scorecard: ScorecardData
    private let linescore: Linescore?
    private var selectedMode: ScorecardExportMode = .full

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
    private let modeStack: UIStackView = {
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

    private var modeRows: [UIView] = []
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
        setupModeList()
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
        modeStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let previewContainer = UIView()
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewImageView)

        contentStack.addArrangedSubview(previewContainer)
        contentStack.addArrangedSubview(modeStack)
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

    private func setupModeList() {
        for mode in ScorecardExportMode.allCases {
            let row = makeModeRow(for: mode)
            modeStack.addArrangedSubview(row)
            modeRows.append(row)
        }
        updateCheckmarks()
    }

    private func makeModeRow(for mode: ScorecardExportMode) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.tag = mode.rawValue

        let checkmark = UIImageView()
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.tintColor = AppColors.pencil
        checkmark.contentMode = .scaleAspectFit
        checkmark.tag = 100

        let titleLabel = UILabel()
        titleLabel.text = mode.title
        titleLabel.font = UIFont(name: "PatrickHand-Regular", size: 20) ?? .systemFont(ofSize: 20)
        titleLabel.textColor = AppColors.pencil
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = mode.subtitle
        subtitleLabel.font = UIFont(name: "IBMPlexSansCond-Regular", size: 14) ?? .systemFont(ofSize: 14)
        subtitleLabel.textColor = AppColors.pencil.withAlphaComponent(0.6)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let separator = UIView()
        separator.backgroundColor = AppColors.grid
        separator.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(checkmark)
        container.addSubview(textStack)
        container.addSubview(separator)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 60),
            checkmark.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            checkmark.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            checkmark.widthAnchor.constraint(equalToConstant: 22),
            checkmark.heightAnchor.constraint(equalToConstant: 22),
            textStack.leadingAnchor.constraint(equalTo: checkmark.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            textStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(modeRowTapped(_:)))
        container.addGestureRecognizer(tap)

        return container
    }

    @objc private func modeRowTapped(_ gesture: UITapGestureRecognizer) {
        guard let row = gesture.view,
              let mode = ScorecardExportMode(rawValue: row.tag) else { return }
        selectedMode = mode
        updateCheckmarks()
        refreshPreview()
    }

    private func updateCheckmarks() {
        for row in modeRows {
            guard let checkmark = row.viewWithTag(100) as? UIImageView else { continue }
            let isSelected = row.tag == selectedMode.rawValue
            checkmark.image = isSelected ? UIImage(systemName: "checkmark") : nil
        }
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
            let image = await generator.generate(scorecard: scorecard, linescore: linescore, options: selectedMode)
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
        exportWith { generator, sc, ls, mode in
            await generator.generate(scorecard: sc, linescore: ls, options: mode)
        } present: { image in
            let awayName = self.scorecard.teams.away.name ?? "Away"
            let homeName = self.scorecard.teams.home.name ?? "Home"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(awayName) vs \(homeName) Scorecard.png")
            try? image.pngData()?.write(to: tempURL)
            return tempURL
        }
    }

    @objc private func sharePDFTapped() {
        exportWith { generator, sc, ls, mode in
            await generator.generatePDF(scorecard: sc, linescore: ls, options: mode)
        } present: { data in
            let awayName = self.scorecard.teams.away.name ?? "Away"
            let homeName = self.scorecard.teams.home.name ?? "Home"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(awayName) vs \(homeName) Scorecard.pdf")
            try? data.write(to: tempURL)
            return tempURL
        }
    }

    private func exportWith<T>(generate: @escaping (ScorecardImageGenerator, ScorecardData, Linescore?, ScorecardExportMode) async -> T, present: @escaping (T) -> URL) {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        view.isUserInteractionEnabled = false

        let mode = selectedMode
        let sc = scorecard
        let ls = linescore

        Task {
            let generator = ScorecardImageGenerator()
            let result = await generate(generator, sc, ls, mode)

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
