import UIKit

enum AccessibilitySupport {
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
        default: return code
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
        let awayScore = game.teams.away.score.map(String.init) ?? "-"
        let homeScore = game.teams.home.score.map(String.init) ?? "-"
        return joined([
            "\(awayName) at \(homeName)",
            "Score \(awayScore) to \(homeScore)",
            game.status.detailedState,
            game.venue?.name
        ])
    }
}
