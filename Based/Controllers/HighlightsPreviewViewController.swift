import UIKit

class HighlightsPreviewViewController: UIViewController {

    private let scorecard: ScorecardData
    private let linescore: Linescore?
    private let plays: [AtBatEvent]
    private let selectedStyle: UIUserInterfaceStyle

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
    private let buttonStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 12
        s.distribution = .fillEqually
        return s
    }()
    private var exportButtons: [UIButton] = []
    private var previewTask: Task<Void, Never>?

    init(scorecard: ScorecardData, linescore: Linescore?, plays: [AtBatEvent], style: UIUserInterfaceStyle) {
        self.scorecard = scorecard
        self.linescore = linescore
        self.plays = plays
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
        title = "Preview"
        setupNavBar()
        setupLayout()
        setupButtons()
        refreshPreview()
    }

    private func setupNavBar() {
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

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let previewContainer = UIView()
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewImageView)

        contentStack.addArrangedSubview(previewContainer)
        contentStack.addArrangedSubview(buttonStack)

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
            previewImageView.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            previewImageView.widthAnchor.constraint(lessThanOrEqualTo: previewContainer.widthAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            previewImageView.heightAnchor.constraint(equalTo: previewImageView.widthAnchor, multiplier: 1280.0 / 720.0),
            previewImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 560),

            buttonStack.heightAnchor.constraint(equalToConstant: 50),
        ])

        let widthFill = previewImageView.widthAnchor.constraint(equalTo: previewContainer.widthAnchor)
        widthFill.priority = .defaultHigh
        widthFill.isActive = true
    }

    private func setupButtons() {
        let imageBtn = makeExportButton(title: "Share Image", icon: "photo")
        imageBtn.addTarget(self, action: #selector(shareImageTapped), for: .touchUpInside)

        let pdfBtn = makeExportButton(title: "Save PDF", icon: "doc.richtext")
        pdfBtn.addTarget(self, action: #selector(sharePDFTapped), for: .touchUpInside)

        exportButtons = [imageBtn, pdfBtn]
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

        let font = UIFont(name: AppFont.ibmPlexBold, size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
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
        let style = selectedStyle
        let sc = scorecard
        let ls = linescore
        let ps = plays
        previewTask = Task {
            let generator = ScorecardImageGenerator()
            let image = await generator.generateHighlights(scorecard: sc, linescore: ls, plays: ps, userInterfaceStyle: style)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.previewImageView.image = image
            }
        }
    }

    @objc private func shareImageTapped() {
        exportWith { generator, sc, ls, ps, style in
            await generator.generateHighlights(scorecard: sc, linescore: ls, plays: ps, userInterfaceStyle: style)
        } present: { image in
            let awayName = self.scorecard.teams.away.name ?? "Away"
            let homeName = self.scorecard.teams.home.name ?? "Home"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(awayName) vs \(homeName) Highlights.png")
            try? image.pngData()?.write(to: tempURL)
            return tempURL
        }
    }

    @objc private func sharePDFTapped() {
        exportWith { generator, sc, ls, ps, style in
            await generator.generateHighlightsPDF(scorecard: sc, linescore: ls, plays: ps, userInterfaceStyle: style)
        } present: { data in
            let awayName = self.scorecard.teams.away.name ?? "Away"
            let homeName = self.scorecard.teams.home.name ?? "Home"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(awayName) vs \(homeName) Highlights.pdf")
            try? data.write(to: tempURL)
            return tempURL
        }
    }

    private func exportWith<T>(
        generate: @escaping (ScorecardImageGenerator, ScorecardData, Linescore?, [AtBatEvent], UIUserInterfaceStyle) async -> T,
        present: @escaping (T) -> URL
    ) {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        view.isUserInteractionEnabled = false

        let style = selectedStyle
        let sc = scorecard
        let ls = linescore
        let ps = plays

        Task {
            let generator = ScorecardImageGenerator()
            let result = await generate(generator, sc, ls, ps, style)

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
                activityVC.completionWithItemsHandler = { _, completed, _, _ in
                    if completed {
                        ReviewPromptService.shared.requestReviewIfAppropriate(in: self.view.window?.windowScene)
                    }
                }
                self.present(activityVC, animated: true)
            }
        }
    }
}
