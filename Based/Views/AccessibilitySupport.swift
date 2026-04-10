import UIKit

enum AccessibilitySupport {
    private static let accessibilityGameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static func gameDate(from isoDate: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: isoDate) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        return formatter.date(from: isoDate)
    }

    static func spokenGameTime(_ isoDate: String) -> String? {
        guard let date = gameDate(from: isoDate) else { return nil }
        return accessibilityGameDateFormatter.string(from: date)
    }

    static func joined(_ parts: [String?]) -> String {
        parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    static func statName(for code: String) -> String {
        switch code {
        case "AB": return "at bats"
        case "R": return "runs"
        case "H": return "hits"
        case "RBI": return "runs batted in"
        case "BB": return "walks"
        case "K": return "strikeouts"
        case "ER": return "earned runs"
        case "IP": return "innings pitched"
        case "AVG": return "batting average"
        case "HR": return "home runs"
        case "SB": return "stolen bases"
        case "OPS": return "OPS"
        case "ERA": return "earned run average"
        case "W": return "wins"
        case "L": return "losses"
        default: return code
        }
    }

    static func positionDescription(_ code: String) -> String {
        switch code.uppercased() {
        case "P":
            return "Pitcher"
        case "C":
            return "Catcher"
        case "1B":
            return "First base"
        case "2B":
            return "Second base"
        case "3B":
            return "Third base"
        case "SS":
            return "Shortstop"
        case "LF":
            return "Left field"
        case "CF":
            return "Center field"
        case "RF":
            return "Right field"
        case "DH":
            return "Designated hitter"
        case "PH":
            return "Pinch hitter"
        case "PR":
            return "Pinch runner"
        default:
            return code
        }
    }

    static func handednessDescription(_ code: String) -> String {
        switch code.uppercased() {
        case "R":
            return "right-handed"
        case "L":
            return "left-handed"
        case "S":
            return "switch hitter"
        default:
            return code
        }
    }

    static func ordinal(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    static func inningSide(isTop: Bool) -> String {
        isTop ? "top" : "bottom"
    }

    static func inningHalf(event: AtBatEvent) -> String {
        "\(inningSide(isTop: event.isTop)) of the \(ordinal(event.inning))"
    }

    static func countDescription(balls: Int, strikes: Int, outs: Int) -> String {
        let outsWord = outs == 1 ? "out" : "outs"
        return "\(balls) balls, \(strikes) strikes, \(outs) \(outsWord)"
    }

    static func basesDescription(_ bases: BasesReached) -> String {
        var occupied: [String] = []
        if bases.first { occupied.append("first") }
        if bases.second { occupied.append("second") }
        if bases.third { occupied.append("third") }

        let runnersText = occupied.isEmpty ? "Bases empty" : "Runners on \(occupied.joined(separator: " and "))"
        return bases.home ? "\(runnersText), run scored" : runnersText
    }

    static func subtitle(for pitch: PitchEvent) -> String? {
        if let balls = pitch.balls, let strikes = pitch.strikes {
            return "Count \(balls)-\(strikes)"
        }

        let normalizedDescription = pitch.description.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedOutcome = pitch.outcome.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedOutcome.isEmpty, normalizedOutcome != normalizedDescription else {
            return nil
        }

        return pitch.outcome
    }

    static func speedDescription(for pitch: PitchEvent) -> String? {
        let type = pitch.pitchType?.trimmingCharacters(in: .whitespacesAndNewlines)
        let speed = pitch.speed.map { String(format: "%.0f miles per hour", $0) }

        switch (type?.isEmpty == false ? type : nil, speed) {
        case let (type?, speed?):
            return "\(type), \(speed)"
        case let (type?, nil):
            return type
        case let (nil, speed?):
            return speed
        default:
            return nil
        }
    }

    static func pitchDescription(_ pitch: PitchEvent) -> String {
        joined([
            "Pitch \(pitch.pitchNumber)",
            pitch.description,
            subtitle(for: pitch),
            speedDescription(for: pitch)
        ])
    }

    static func eventDescription(_ event: AtBatEvent, includeMatchup: Bool = false) -> String {
        var parts: [String] = []
        if includeMatchup {
            parts.append("\(event.batterName), against \(event.pitcherName)")
        }
        parts.append("\(inningHalf(event: event)) at bat")
        parts.append(event.description)
        if event.isRunnerOnly {
            parts.append("Runner advance only")
        } else {
            parts.append(countDescription(balls: event.balls, strikes: event.strikes, outs: event.outs))
        }
        parts.append(basesDescription(event.bases))
        if event.rbi > 0 {
            let rbiWord = event.rbi == 1 ? "run batted in" : "runs batted in"
            parts.append("\(event.rbi) \(rbiWord)")
        }
        if let pitchCount = event.pitches?.count, pitchCount > 0 {
            let pitchWord = pitchCount == 1 ? "pitch" : "pitches"
            parts.append("\(pitchCount) \(pitchWord)")
        }
        return parts.joined(separator: ". ")
    }

    static func gameCardDescription(_ game: ScheduleGame) -> String {
        let awayName = game.teams.away.team.name ?? "Away"
        let homeName = game.teams.home.team.name ?? "Home"
        var parts = ["\(awayName) at \(homeName)"]

        let status = game.status.detailedState
        let shouldSpeakScore = !["Scheduled", "Pre-Game"].contains(status)
            && game.teams.away.score != nil
            && game.teams.home.score != nil

        if shouldSpeakScore {
            let awayScore = game.teams.away.score.map(String.init) ?? "0"
            let homeScore = game.teams.home.score.map(String.init) ?? "0"
            parts.append("Score, \(awayName) \(awayScore), \(homeName) \(homeScore)")
        } else if let spokenTime = spokenGameTime(game.gameDate) {
            parts.append("First pitch \(spokenTime)")
        }

        parts.append(status)
        parts.append(game.venue?.name ?? "")
        return joined(parts)
    }

    static func umpireRoleDescription(_ code: String) -> String {
        switch code.uppercased() {
        case "HP":
            return "Home plate"
        case "1B":
            return "First base"
        case "2B":
            return "Second base"
        case "3B":
            return "Third base"
        default:
            return code
        }
    }

    static func umpiresDescription(_ umpires: [ScorecardUmpire]) -> String {
        let parts = umpires.map { umpire in
            "\(umpireRoleDescription(umpire.type)): \(umpire.fullName)"
        }
        return joined(["Umpires", parts.joined(separator: ", ")])
    }

    static func playerBioDescription(number: String?, position: String?, team: String?, height: String?, weight: Int?, batSide: String?, throwSide: String?) -> String {
        var parts: [String] = []

        if let number, !number.isEmpty {
            parts.append("Number \(number)")
        }
        if let position, !position.isEmpty {
            parts.append(positionDescription(position))
        }
        if let team, !team.isEmpty {
            parts.append(team)
        }
        if let height, !height.isEmpty {
            parts.append(height)
        }
        if let weight {
            parts.append("\(weight) pounds")
        }
        if let batSide, !batSide.isEmpty {
            parts.append("Bats \(handednessDescription(batSide))")
        }
        if let throwSide, !throwSide.isEmpty {
            parts.append("Throws \(handednessDescription(throwSide))")
        }

        return joined(parts)
    }
}
