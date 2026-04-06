import UIKit

struct AtBatPresentation {
    let event: AtBatEvent
    let teamAccentColor: UIColor

    init(event: AtBatEvent, teamAccentColor: UIColor? = nil) {
        self.event = event
        self.teamAccentColor = teamAccentColor ?? AppColors.pencil
    }

    var isLive: Bool {
        event.result == "LIVE"
    }

    var isCalledStrikeout: Bool {
        event.result == "Ʞ"
    }

    var isScoringPlay: Bool {
        event.result == "HR" || event.bases.home
    }

    var displayResult: String {
        if isLive { return "LIVE" }
        return isCalledStrikeout ? "K" : event.result
    }

    var displayDescription: String {
        isLive ? "Current at bat" : event.description
    }

    var resultTransform: CGAffineTransform {
        isCalledStrikeout && !isLive ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    }

    var primaryColor: UIColor {
        isScoringPlay ? teamAccentColor : AppColors.pencil
    }

    var diamondStyle: DiamondView.Style {
        isLive ? .liveStatus : .scorecard
    }

    var diamondAccentColor: UIColor {
        teamAccentColor
    }

    var ballsText: String {
        "\(event.balls)B"
    }

    var strikesText: String {
        "\(event.strikes)S"
    }

    var outsText: String {
        event.outs > 0 ? "\(event.outs)" : ""
    }

    func resultAttributedString(font: UIFont) -> NSAttributedString? {
        guard !isLive else { return nil }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 0.75
        paragraphStyle.alignment = .center

        return NSAttributedString(
            string: displayResult,
            attributes: [
                .paragraphStyle: paragraphStyle,
                .font: font,
                .foregroundColor: primaryColor
            ]
        )
    }
}

extension ScorecardData {
    func teamAccentColor(isTopInning: Bool) -> UIColor {
        let teamName = isTopInning ? teams.away.name : teams.home.name
        guard let teamName else { return AppColors.pencil }
        return TeamColorProvider.color(for: teamName)
    }

    func teamAccentColor(for event: AtBatEvent) -> UIColor {
        teamAccentColor(isTopInning: event.isTop)
    }

    func teamAccentColor(isHomeTeam: Bool) -> UIColor {
        let teamName = isHomeTeam ? teams.home.name : teams.away.name
        guard let teamName else { return AppColors.pencil }
        return TeamColorProvider.color(for: teamName)
    }
}

struct InningGroup {
    let inning: Int
    let isTop: Bool
    let events: [AtBatEvent]

    var title: String {
        let side = isTop ? "TOP" : "BOTTOM"
        return "\(side) \(inning)"
    }

    static func build(from timeline: [AtBatEvent]) -> [InningGroup] {
        var grouped: [InningGroup] = []
        var currentInning: Int?
        var currentIsTop: Bool?
        var currentEvents: [AtBatEvent] = []

        for event in timeline {
            if event.inning != currentInning || event.isTop != currentIsTop {
                if let inning = currentInning, let isTop = currentIsTop {
                    grouped.append(InningGroup(inning: inning, isTop: isTop, events: currentEvents))
                }
                currentInning = event.inning
                currentIsTop = event.isTop
                currentEvents = [event]
            } else {
                currentEvents.append(event)
            }
        }

        if let inning = currentInning, let isTop = currentIsTop {
            grouped.append(InningGroup(inning: inning, isTop: isTop, events: currentEvents))
        }

        return grouped
    }
}
