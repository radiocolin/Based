import UIKit

class GameHeaderView: UIView {

    private let containerView = UIView()
    private let inningsScrollView = UIScrollView()
    private let inningsContentView = UIView()

    private let awayName = UILabel()
    private let homeName = UILabel()

    private let rHeader = UILabel()
    private let hHeader = UILabel()
    private let eHeader = UILabel()

    private let awayR = UILabel()
    private let awayH = UILabel()
    private let awayE = UILabel()

    private let homeR = UILabel()
    private let homeH = UILabel()
    private let homeE = UILabel()

    private var inningHeaders: [UILabel] = []
    private var awayInningLabels: [UILabel] = []
    private var homeInningLabels: [UILabel] = []
    private var inningColumnConstraints: [NSLayoutConstraint] = []
    private var inningWidthConstraints: [NSLayoutConstraint] = []
    private var inningsContentWidthConstraint: NSLayoutConstraint?
    private var inningsContentMatchesFrameConstraint: NSLayoutConstraint?
    private var awayNameWidthConstraint: NSLayoutConstraint?
    private var homeNameWidthConstraint: NSLayoutConstraint?
    private var statsBackgroundWidthConstraint: NSLayoutConstraint?
    private var rHeaderWidthConstraint: NSLayoutConstraint?
    private var hHeaderWidthConstraint: NSLayoutConstraint?
    private var eHeaderWidthConstraint: NSLayoutConstraint?

    private let venueWeatherLabel = UILabel()
    private let linesLayer = CAShapeLayer()

    private let paperColor = AppColors.paper
    private var pencilColor: UIColor { AppColors.pencil }
    private let headerFont = "PatrickHand-Regular"
    private let bodyFont = "PermanentMarker-Regular"
    private let nameWidth: CGFloat = 45
    private let statWidth: CGFloat = 28
    private let inningWidth: CGFloat = 28
    private let rowHeight: CGFloat = 28
    private let headerHeight: CGFloat = 22
    private let outerPadding: CGFloat = 16

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        rebuildInningColumns(count: 9)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: GameHeaderView, _) in
            self.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = paperColor
        containerView.layer.cornerRadius = 8
        addSubview(containerView)

        let headerBackground = UIView()
        headerBackground.backgroundColor = AppColors.header
        headerBackground.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(headerBackground)

        let statsBackground = UIView()
        statsBackground.backgroundColor = AppColors.selected
        statsBackground.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statsBackground)

        containerView.layer.addSublayer(linesLayer)

        venueWeatherLabel.font = UIFont(name: bodyFont, size: 12) ?? .systemFont(ofSize: 12)
        venueWeatherLabel.textColor = pencilColor.withAlphaComponent(0.6)
        venueWeatherLabel.textAlignment = .center
        venueWeatherLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(venueWeatherLabel)

        inningsScrollView.translatesAutoresizingMaskIntoConstraints = false
        inningsScrollView.showsHorizontalScrollIndicator = false
        inningsScrollView.alwaysBounceHorizontal = false
        inningsScrollView.delegate = self
        containerView.addSubview(inningsScrollView)

        inningsContentView.translatesAutoresizingMaskIntoConstraints = false
        inningsScrollView.addSubview(inningsContentView)

        [rHeader, hHeader, eHeader, awayR, awayH, awayE, homeR, homeH, homeE].forEach {
            containerView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.textColor = pencilColor
            $0.textAlignment = .center
        }

        [awayName, homeName].forEach {
            containerView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.textColor = pencilColor
            $0.textAlignment = .left
        }

        rHeader.text = "R"
        hHeader.text = "H"
        eHeader.text = "E"

        rHeader.font = UIFont(name: headerFont, size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
        hHeader.font = UIFont(name: headerFont, size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
        eHeader.font = UIFont(name: headerFont, size: 16) ?? .systemFont(ofSize: 16, weight: .bold)

        [awayR, awayH, awayE, homeR, homeH, homeE].forEach {
            $0.font = UIFont(name: bodyFont, size: 18) ?? .systemFont(ofSize: 18)
        }

        awayName.font = UIFont(name: bodyFont, size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        homeName.font = UIFont(name: bodyFont, size: 18) ?? .systemFont(ofSize: 18, weight: .bold)

        awayNameWidthConstraint = awayName.widthAnchor.constraint(equalToConstant: nameWidth)
        homeNameWidthConstraint = homeName.widthAnchor.constraint(equalToConstant: nameWidth)
        statsBackgroundWidthConstraint = statsBackground.widthAnchor.constraint(equalToConstant: statWidth * 3)
        rHeaderWidthConstraint = rHeader.widthAnchor.constraint(equalToConstant: statWidth)
        hHeaderWidthConstraint = hHeader.widthAnchor.constraint(equalToConstant: statWidth)
        eHeaderWidthConstraint = eHeader.widthAnchor.constraint(equalToConstant: statWidth)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: outerPadding),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -outerPadding),

            venueWeatherLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 6),
            venueWeatherLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: outerPadding),
            venueWeatherLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -outerPadding),
            venueWeatherLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            headerBackground.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerBackground.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerBackground.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerBackground.heightAnchor.constraint(equalToConstant: headerHeight + 4),

            statsBackground.topAnchor.constraint(equalTo: containerView.topAnchor),
            statsBackground.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            statsBackground.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            statsBackgroundWidthConstraint!,

            eHeader.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            eHeader.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            eHeaderWidthConstraint!,
            eHeader.heightAnchor.constraint(equalToConstant: headerHeight),

            hHeader.centerYAnchor.constraint(equalTo: eHeader.centerYAnchor),
            hHeader.trailingAnchor.constraint(equalTo: eHeader.leadingAnchor),
            hHeaderWidthConstraint!,
            hHeader.heightAnchor.constraint(equalToConstant: headerHeight),

            rHeader.centerYAnchor.constraint(equalTo: eHeader.centerYAnchor),
            rHeader.trailingAnchor.constraint(equalTo: hHeader.leadingAnchor),
            rHeaderWidthConstraint!,
            rHeader.heightAnchor.constraint(equalToConstant: headerHeight),

            awayName.topAnchor.constraint(equalTo: eHeader.bottomAnchor, constant: 4),
            awayName.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            awayNameWidthConstraint!,
            awayName.heightAnchor.constraint(equalToConstant: rowHeight),

            homeName.topAnchor.constraint(equalTo: awayName.bottomAnchor),
            homeName.leadingAnchor.constraint(equalTo: awayName.leadingAnchor),
            homeNameWidthConstraint!,
            homeName.heightAnchor.constraint(equalToConstant: rowHeight),
            homeName.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4),

            inningsScrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            inningsScrollView.leadingAnchor.constraint(equalTo: awayName.trailingAnchor),
            inningsScrollView.trailingAnchor.constraint(equalTo: rHeader.leadingAnchor),
            inningsScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            inningsContentView.topAnchor.constraint(equalTo: inningsScrollView.contentLayoutGuide.topAnchor),
            inningsContentView.leadingAnchor.constraint(equalTo: inningsScrollView.contentLayoutGuide.leadingAnchor),
            inningsContentView.trailingAnchor.constraint(equalTo: inningsScrollView.contentLayoutGuide.trailingAnchor),
            inningsContentView.bottomAnchor.constraint(equalTo: inningsScrollView.contentLayoutGuide.bottomAnchor),
            inningsContentView.heightAnchor.constraint(equalTo: inningsScrollView.frameLayoutGuide.heightAnchor),

            awayE.centerYAnchor.constraint(equalTo: awayName.centerYAnchor),
            awayE.centerXAnchor.constraint(equalTo: eHeader.centerXAnchor),
            awayH.centerYAnchor.constraint(equalTo: awayName.centerYAnchor),
            awayH.centerXAnchor.constraint(equalTo: hHeader.centerXAnchor),
            awayR.centerYAnchor.constraint(equalTo: awayName.centerYAnchor),
            awayR.centerXAnchor.constraint(equalTo: rHeader.centerXAnchor),

            homeE.centerYAnchor.constraint(equalTo: homeName.centerYAnchor),
            homeE.centerXAnchor.constraint(equalTo: eHeader.centerXAnchor),
            homeH.centerYAnchor.constraint(equalTo: homeName.centerYAnchor),
            homeH.centerXAnchor.constraint(equalTo: hHeader.centerXAnchor),
            homeR.centerYAnchor.constraint(equalTo: homeName.centerYAnchor),
            homeR.centerXAnchor.constraint(equalTo: rHeader.centerXAnchor)
        ])
    }

    private func updateStaticWidthConstraintsIfNeeded() {
        awayNameWidthConstraint?.constant = nameWidth
        homeNameWidthConstraint?.constant = nameWidth
        statsBackgroundWidthConstraint?.constant = statWidth * 3
        rHeaderWidthConstraint?.constant = statWidth
        hHeaderWidthConstraint?.constant = statWidth
        eHeaderWidthConstraint?.constant = statWidth
        if inningHeaders.count > 9 {
            updateInningsContentWidth(for: inningHeaders.count)
            for constraint in inningWidthConstraints {
                constraint.constant = inningWidth
            }
        }
    }

    private func rebuildInningColumns(count: Int) {
        inningColumnConstraints.forEach { $0.isActive = false }
        inningColumnConstraints.removeAll()
        inningWidthConstraints.removeAll()
        inningsContentMatchesFrameConstraint?.isActive = false

        (inningHeaders + awayInningLabels + homeInningLabels).forEach { $0.removeFromSuperview() }
        inningHeaders.removeAll()
        awayInningLabels.removeAll()
        homeInningLabels.removeAll()

        var previousTrailing = inningsContentView.leadingAnchor
        for inning in 1...count {
            let header = createLabel(text: "\(inning)", font: headerFont, size: 16)
            let away = createLabel(text: "", font: bodyFont, size: 18)
            let home = createLabel(text: "", font: bodyFont, size: 18)

            inningHeaders.append(header)
            awayInningLabels.append(away)
            homeInningLabels.append(home)

            [header, away, home].forEach { inningsContentView.addSubview($0) }
            let headerWidthConstraint: NSLayoutConstraint
            if count <= 9 {
                headerWidthConstraint = header.widthAnchor.constraint(equalTo: inningsScrollView.frameLayoutGuide.widthAnchor, multiplier: 1 / CGFloat(count))
            } else {
                headerWidthConstraint = header.widthAnchor.constraint(equalToConstant: inningWidth)
                inningWidthConstraints.append(headerWidthConstraint)
            }

            inningColumnConstraints.append(contentsOf: [
                header.leadingAnchor.constraint(equalTo: previousTrailing),
                header.topAnchor.constraint(equalTo: inningsContentView.topAnchor, constant: 4),
                headerWidthConstraint,
                header.heightAnchor.constraint(equalToConstant: headerHeight),

                away.leadingAnchor.constraint(equalTo: header.leadingAnchor),
                away.widthAnchor.constraint(equalTo: header.widthAnchor),
                away.centerYAnchor.constraint(equalTo: awayName.centerYAnchor),

                home.leadingAnchor.constraint(equalTo: header.leadingAnchor),
                home.widthAnchor.constraint(equalTo: header.widthAnchor),
                home.centerYAnchor.constraint(equalTo: homeName.centerYAnchor)
            ])

            previousTrailing = header.trailingAnchor
        }

        if let lastHeader = inningHeaders.last {
            inningColumnConstraints.append(lastHeader.trailingAnchor.constraint(equalTo: inningsContentView.trailingAnchor))
        }

        if count <= 9 {
            inningsContentWidthConstraint?.isActive = false
            inningsContentMatchesFrameConstraint = inningsContentView.widthAnchor.constraint(equalTo: inningsScrollView.frameLayoutGuide.widthAnchor)
            inningsContentMatchesFrameConstraint?.isActive = true
            inningsScrollView.isScrollEnabled = false
        } else {
            inningsContentMatchesFrameConstraint?.isActive = false
            updateInningsContentWidth(for: count)
            inningsContentWidthConstraint?.isActive = true
            inningsScrollView.isScrollEnabled = true
        }
        NSLayoutConstraint.activate(inningColumnConstraints)
    }

    private func updateInningsContentWidth(for inningCount: Int) {
        let totalWidth = CGFloat(inningCount) * inningWidth
        if let inningsContentWidthConstraint {
            inningsContentWidthConstraint.constant = totalWidth
        } else {
            inningsContentWidthConstraint = inningsContentView.widthAnchor.constraint(equalToConstant: totalWidth)
        }
    }

    private func createLabel(text: String, font: String, size: CGFloat) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont(name: font, size: size) ?? .systemFont(ofSize: size)
        label.textColor = pencilColor
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateStaticWidthConstraintsIfNeeded()
        drawPencilLines()
    }

    private func drawPencilLines() {
        let bounds = containerView.bounds
        let path = UIBezierPath()
        path.append(UIBezierPath.pencilLine(from: .zero, to: CGPoint(x: bounds.width, y: 0)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: bounds.width, y: 0), to: CGPoint(x: bounds.width, y: bounds.height)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: bounds.width, y: bounds.height), to: CGPoint(x: 0, y: bounds.height)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: bounds.height), to: .zero))

        let headerY = rHeader.frame.maxY + 2
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: headerY), to: CGPoint(x: bounds.width, y: headerY)))

        let splitY = awayName.frame.maxY + 2
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: splitY), to: CGPoint(x: bounds.width, y: splitY)))

        let nameX = awayName.frame.maxX
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: nameX, y: 0), to: CGPoint(x: nameX, y: bounds.height)))

        for header in inningHeaders {
            let x = containerView.convert(header.frame, from: inningsContentView).maxX
            if x > nameX && x < rHeader.frame.minX {
                path.append(UIBezierPath.pencilLine(from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: bounds.height)))
            }
        }

        let rX = rHeader.frame.minX
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: rX, y: 0), to: CGPoint(x: rX, y: bounds.height)))
        let hX = hHeader.frame.minX
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: hX, y: 0), to: CGPoint(x: hX, y: bounds.height)))
        let eX = eHeader.frame.minX
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: eX, y: 0), to: CGPoint(x: eX, y: bounds.height)))

        linesLayer.path = path.cgPath
        linesLayer.strokeColor = pencilColor.withAlphaComponent(0.3).cgColor
        linesLayer.lineWidth = 0.75
        linesLayer.fillColor = UIColor.clear.cgColor
        linesLayer.lineCap = .round
        linesLayer.lineJoin = .round
    }

    func configure(with linescore: Linescore, awayNameOverride: String? = nil, homeNameOverride: String? = nil, isFinal: Bool = false) {
        let awayActual = awayNameOverride ?? linescore.teams?.away?.team?.name ?? "AWAY"
        let homeActual = homeNameOverride ?? linescore.teams?.home?.team?.name ?? "HOME"
        let awayColor = TeamColorProvider.color(for: awayActual)
        let homeColor = TeamColorProvider.color(for: homeActual)
        let zeroColor = pencilColor.withAlphaComponent(0.7)
        let inningCount = max(9, linescore.innings?.count ?? 0)

        if inningHeaders.count != inningCount {
            rebuildInningColumns(count: inningCount)
        }

        awayName.text = abbreviation(for: awayActual)
        homeName.text = abbreviation(for: homeActual)
        awayName.textColor = awayColor
        homeName.textColor = homeColor

        if let runs = linescore.teams?.away?.runs {
            awayR.text = "\(runs)"
            awayR.textColor = runs > 0 ? awayColor : zeroColor
        } else {
            awayR.text = ""
        }

        if let hits = linescore.teams?.away?.hits {
            awayH.text = "\(hits)"
            awayH.textColor = zeroColor
        } else {
            awayH.text = ""
        }

        if let errors = linescore.teams?.away?.errors {
            awayE.text = "\(errors)"
            awayE.textColor = zeroColor
        } else {
            awayE.text = ""
        }

        if let runs = linescore.teams?.home?.runs {
            homeR.text = "\(runs)"
            homeR.textColor = runs > 0 ? homeColor : zeroColor
        } else {
            homeR.text = ""
        }

        if let hits = linescore.teams?.home?.hits {
            homeH.text = "\(hits)"
            homeH.textColor = zeroColor
        } else {
            homeH.text = ""
        }

        if let errors = linescore.teams?.home?.errors {
            homeE.text = "\(errors)"
            homeE.textColor = zeroColor
        } else {
            homeE.text = ""
        }

        awayInningLabels.forEach {
            $0.text = ""
            $0.textColor = pencilColor
        }
        homeInningLabels.forEach {
            $0.text = ""
            $0.textColor = pencilColor
        }

        if let innings = linescore.innings {
            for inning in innings {
                guard let num = inning.num else { continue }
                let index = num - 1
                guard index >= 0 && index < inningHeaders.count else { continue }

                if let awayRuns = inning.away?.runs {
                    awayInningLabels[index].text = "\(awayRuns)"
                    awayInningLabels[index].textColor = awayRuns > 0 ? awayColor : zeroColor
                }

                if let homeRuns = inning.home?.runs {
                    homeInningLabels[index].text = "\(homeRuns)"
                    homeInningLabels[index].textColor = homeRuns > 0 ? homeColor : zeroColor
                }
            }

            if isFinal {
                for index in 0..<inningHeaders.count {
                    if awayInningLabels[index].text?.isEmpty == false && homeInningLabels[index].text?.isEmpty != false {
                        homeInningLabels[index].text = "-"
                        homeInningLabels[index].textColor = zeroColor
                    }
                }
            }
        }

        var venueWeatherParts: [String] = []
        if let venue = linescore.venue {
            var venueText = venue.name ?? "Unknown Venue"
            if let city = venue.location?.city, let state = venue.location?.stateAbbrev {
                venueText += " • \(city), \(state)"
            }
            venueWeatherParts.append(venueText)
        }
        if let weather = linescore.weather {
            var weatherText = ""
            if let temp = weather.temp { weatherText += "\(temp)°" }
            if let condition = weather.condition { weatherText += weatherText.isEmpty ? condition : ", \(condition)" }
            if let wind = weather.wind { weatherText += weatherText.isEmpty ? wind : " • \(wind)" }
            if !weatherText.isEmpty {
                venueWeatherParts.append(weatherText)
            }
        }
        venueWeatherLabel.text = venueWeatherParts.joined(separator: " | ")

        setNeedsLayout()
        layoutIfNeeded()
        if inningCount > 9 {
            let maxOffset = max(0, inningsScrollView.contentSize.width - inningsScrollView.bounds.width)
            inningsScrollView.setContentOffset(CGPoint(x: maxOffset, y: 0), animated: false)
        } else {
            inningsScrollView.setContentOffset(.zero, animated: false)
        }
    }

    private func abbreviation(for teamName: String) -> String {
        let map: [String: String] = ["Arizona Diamondbacks": "ARI", "Atlanta Braves": "ATL", "Baltimore Orioles": "BAL", "Boston Red Sox": "BOS", "Chicago Cubs": "CHC", "Chicago White Sox": "CWS", "Cincinnati Reds": "CIN", "Cleveland Guardians": "CLE", "Colorado Rockies": "COL", "Detroit Tigers": "DET", "Houston Astros": "HOU", "Kansas City Royals": "KC", "Los Angeles Angels": "LAA", "Los Angeles Dodgers": "LAD", "Miami Marlins": "MIA", "Milwaukee Brewers": "MIL", "Minnesota Twins": "MIN", "New York Mets": "NYM", "New York Yankees": "NYY", "Oakland Athletics": "OAK", "Philadelphia Phillies": "PHI", "Pittsburgh Pirates": "PIT", "San Diego Padres": "SD", "San Francisco Giants": "SF", "Seattle Mariners": "SEA", "St. Louis Cardinals": "STL", "Tampa Bay Rays": "TB", "Texas Rangers": "TEX", "Toronto Blue Jays": "TOR", "Washington Nationals": "WSH"]
        return map[teamName] ?? String(teamName.prefix(3)).uppercased()
    }
}

extension GameHeaderView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === inningsScrollView else { return }
        setNeedsLayout()
    }
}
