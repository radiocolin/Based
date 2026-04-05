import UIKit

class GameHeaderView: UIView {
    
    // UI Elements
    private let containerView = UIView()
    
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
    
    // Arrays for 1-9 innings
    private var inningHeaders: [UILabel] = []
    private var awayInningLabels: [UILabel] = []
    private var homeInningLabels: [UILabel] = []

    // Venue & Weather
    private let venueWeatherLabel = UILabel()

    // Graphics
    private let linesLayer = CAShapeLayer()
    
    // Constants
    private let paperColor = AppColors.paper
    private var pencilColor: UIColor { AppColors.pencil }
    private let headerFont = "PatrickHand-Regular"
    private let bodyFont = "PermanentMarker-Regular"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = paperColor
        containerView.layer.cornerRadius = 8
        
        // Shading Views
        let headerBackground = UIView()
        headerBackground.backgroundColor = AppColors.header
        headerBackground.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(headerBackground)
        
        let statsBackground = UIView()
        statsBackground.backgroundColor = AppColors.selected
        statsBackground.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statsBackground)
        
        containerView.layer.addSublayer(linesLayer)

        // Labels
        venueWeatherLabel.font = UIFont(name: bodyFont, size: 12) ?? .systemFont(ofSize: 12)
        venueWeatherLabel.textColor = pencilColor.withAlphaComponent(0.6)
        venueWeatherLabel.textAlignment = .center
        venueWeatherLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(venueWeatherLabel)

        // Scoreboard Labels
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
        
        for i in 1...9 {
            let h = createLabel(text: "\(i)", font: headerFont, size: 16)
            let a = createLabel(text: "", font: bodyFont, size: 18)
            let hm = createLabel(text: "", font: bodyFont, size: 18)
            inningHeaders.append(h)
            awayInningLabels.append(a)
            homeInningLabels.append(hm)
            [h, a, hm].forEach { containerView.addSubview($0) }
        }
        
        let nameWidth: CGFloat = 45
        let statWidth: CGFloat = 28
        let rowHeight: CGFloat = 28
        let headerHeight: CGFloat = 22
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            venueWeatherLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 6),
            venueWeatherLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            venueWeatherLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            venueWeatherLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            headerBackground.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerBackground.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerBackground.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerBackground.heightAnchor.constraint(equalToConstant: headerHeight + 4),
            
            statsBackground.topAnchor.constraint(equalTo: containerView.topAnchor),
            statsBackground.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            statsBackground.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            statsBackground.widthAnchor.constraint(equalToConstant: statWidth * 3),
            
            eHeader.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            eHeader.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            eHeader.widthAnchor.constraint(equalToConstant: statWidth),
            eHeader.heightAnchor.constraint(equalToConstant: headerHeight),
            
            hHeader.centerYAnchor.constraint(equalTo: eHeader.centerYAnchor),
            hHeader.trailingAnchor.constraint(equalTo: eHeader.leadingAnchor),
            hHeader.widthAnchor.constraint(equalToConstant: statWidth),
            hHeader.heightAnchor.constraint(equalToConstant: headerHeight),
            
            rHeader.centerYAnchor.constraint(equalTo: eHeader.centerYAnchor),
            rHeader.trailingAnchor.constraint(equalTo: hHeader.leadingAnchor),
            rHeader.widthAnchor.constraint(equalToConstant: statWidth),
            rHeader.heightAnchor.constraint(equalToConstant: headerHeight),
            
            awayName.topAnchor.constraint(equalTo: eHeader.bottomAnchor, constant: 4),
            awayName.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            awayName.widthAnchor.constraint(equalToConstant: nameWidth),
            awayName.heightAnchor.constraint(equalToConstant: rowHeight),
            
            homeName.topAnchor.constraint(equalTo: awayName.bottomAnchor),
            homeName.leadingAnchor.constraint(equalTo: awayName.leadingAnchor),
            homeName.widthAnchor.constraint(equalToConstant: nameWidth),
            homeName.heightAnchor.constraint(equalToConstant: rowHeight),
            homeName.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4),
            
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
            homeR.centerXAnchor.constraint(equalTo: rHeader.centerXAnchor),
        ])
        
        let startAnchor = awayName.trailingAnchor
        let endAnchor = rHeader.leadingAnchor
        var prevLeading = startAnchor
        
        for i in 0..<9 {
            let h = inningHeaders[i]
            let a = awayInningLabels[i]
            let hm = homeInningLabels[i]
            NSLayoutConstraint.activate([
                h.leadingAnchor.constraint(equalTo: prevLeading),
                h.centerYAnchor.constraint(equalTo: rHeader.centerYAnchor),
                a.leadingAnchor.constraint(equalTo: prevLeading),
                a.widthAnchor.constraint(equalTo: h.widthAnchor),
                a.centerYAnchor.constraint(equalTo: awayName.centerYAnchor),
                hm.leadingAnchor.constraint(equalTo: prevLeading),
                hm.widthAnchor.constraint(equalTo: h.widthAnchor),
                hm.centerYAnchor.constraint(equalTo: homeName.centerYAnchor)
            ])
            if i == 8 {
                h.trailingAnchor.constraint(equalTo: endAnchor).isActive = true
            } else {
                h.widthAnchor.constraint(equalTo: inningHeaders[i+1].widthAnchor).isActive = true
                prevLeading = h.trailingAnchor
            }
        }
    }
    
    private func createLabel(text: String, font: String, size: CGFloat) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont(name: font, size: size) ?? .systemFont(ofSize: size)
        l.textColor = pencilColor
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        drawPencilLines()
    }
    
    private func drawPencilLines() {
        let b = containerView.bounds
        let path = UIBezierPath()
        path.append(UIBezierPath.pencilLine(from: .zero, to: CGPoint(x: b.width, y: 0)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: b.width, y: 0), to: CGPoint(x: b.width, y: b.height)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: b.width, y: b.height), to: CGPoint(x: 0, y: b.height)))
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: b.height), to: .zero))
        let headerY = rHeader.frame.maxY + 2
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: headerY), to: CGPoint(x: b.width, y: headerY)))
        let splitY = awayName.frame.maxY + 2
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: 0, y: splitY), to: CGPoint(x: b.width, y: splitY)))
        let nameX = awayName.frame.maxX
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: nameX, y: 0), to: CGPoint(x: nameX, y: b.height)))
        for i in 0..<8 {
            let x = inningHeaders[i].frame.maxX
            path.append(UIBezierPath.pencilLine(from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: b.height)))
        }
        let rX = rHeader.frame.minX
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: rX, y: 0), to: CGPoint(x: rX, y: b.height)))
        let hX = hHeader.frame.minX
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: hX, y: 0), to: CGPoint(x: hX, y: b.height)))
        let eX = eHeader.frame.minX
        path.append(UIBezierPath.pencilLine(from: CGPoint(x: eX, y: 0), to: CGPoint(x: eX, y: b.height)))
        linesLayer.path = path.cgPath
        linesLayer.strokeColor = pencilColor.withAlphaComponent(0.3).cgColor
        linesLayer.lineWidth = 0.75
        linesLayer.fillColor = UIColor.clear.cgColor
        linesLayer.lineCap = .round
        linesLayer.lineJoin = .round
    }
    
    func configure(with linescore: Linescore, awayNameOverride: String? = nil, homeNameOverride: String? = nil) {
        let awayActual = awayNameOverride ?? linescore.teams?.away?.team?.name ?? "AWAY"
        let homeActual = homeNameOverride ?? linescore.teams?.home?.team?.name ?? "HOME"
        
        awayName.text = abbreviation(for: awayActual)
        homeName.text = abbreviation(for: homeActual)
        
        awayName.textColor = TeamColorProvider.color(for: awayActual)
        homeName.textColor = TeamColorProvider.color(for: homeActual)
        
        awayR.text = "\(linescore.teams?.away?.runs ?? 0)"
        awayH.text = "\(linescore.teams?.away?.hits ?? 0)"
        awayE.text = "\(linescore.teams?.away?.errors ?? 0)"
        homeR.text = "\(linescore.teams?.home?.runs ?? 0)"
        homeH.text = "\(linescore.teams?.home?.hits ?? 0)"
        homeE.text = "\(linescore.teams?.home?.errors ?? 0)"
        
        for label in awayInningLabels { label.text = "" }
        for label in homeInningLabels { label.text = "" }
        if let innings = linescore.innings {
            for inning in innings {
                if let num = inning.num {
                    let index = num - 1
                    if index >= 0 && index < 9 {
                        awayInningLabels[index].text = "\(inning.away?.runs ?? 0)"
                        homeInningLabels[index].text = "\(inning.home?.runs ?? 0)"
                    }
                }
            }
        }
        var venueWeatherParts: [String] = []
        if let venue = linescore.venue {
            var venueText = venue.name ?? "Unknown Venue"
            if let city = venue.location?.city, let state = venue.location?.stateAbbrev { venueText += " • \(city), \(state)" }
            venueWeatherParts.append(venueText)
        }
        if let weather = linescore.weather {
            var weatherText = ""
            if let temp = weather.temp { weatherText += "\(temp)°" }
            if let condition = weather.condition { weatherText += weatherText.isEmpty ? condition : ", \(condition)" }
            if let wind = weather.wind { weatherText += weatherText.isEmpty ? wind : " • \(wind)" }
            if !weatherText.isEmpty { venueWeatherParts.append(weatherText) }
        }
        venueWeatherLabel.text = venueWeatherParts.joined(separator: " | ")
        setNeedsLayout()
    }

    private func abbreviation(for teamName: String) -> String {
        let map: [String: String] = ["Arizona Diamondbacks": "ARI", "Atlanta Braves": "ATL", "Baltimore Orioles": "BAL", "Boston Red Sox": "BOS", "Chicago Cubs": "CHC", "Chicago White Sox": "CWS", "Cincinnati Reds": "CIN", "Cleveland Guardians": "CLE", "Colorado Rockies": "COL", "Detroit Tigers": "DET", "Houston Astros": "HOU", "Kansas City Royals": "KC", "Los Angeles Angels": "LAA", "Los Angeles Dodgers": "LAD", "Miami Marlins": "MIA", "Milwaukee Brewers": "MIL", "Minnesota Twins": "MIN", "New York Mets": "NYM", "New York Yankees": "NYY", "Oakland Athletics": "OAK", "Philadelphia Phillies": "PHI", "Pittsburgh Pirates": "PIT", "San Diego Padres": "SD", "San Francisco Giants": "SF", "Seattle Mariners": "SEA", "St. Louis Cardinals": "STL", "Tampa Bay Rays": "TB", "Texas Rangers": "TEX", "Toronto Blue Jays": "TOR", "Washington Nationals": "WSH"]
        return map[teamName] ?? String(teamName.prefix(3)).uppercased()
    }
}
