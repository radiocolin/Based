import Foundation

// MARK: - Scorecard Result

enum ScorecardResult: Sendable, Equatable {
    case single
    case double
    case triple
    case homeRun
    case walk
    case intentionalWalk
    case hitByPitch
    case strikeoutSwinging
    case strikeoutLooking
    case flyout(position: String)
    case popout(position: String)
    case lineout(position: String)
    case groundout(sequence: String)
    case forceOut(sequence: String)
    case fieldersChoice
    case doublePlay(sequence: String)
    case triplePlay
    case sacFly(position: String?)
    case sacBunt
    case fieldError
    case stolenBase
    case caughtStealing
    case pickoff
    case balk
    case wildPitch
    case passedBall
    case live
    case runnerOnly
    case empty
    case other(text: String)

    var displayText: String {
        switch self {
        case .single: return "1B"
        case .double: return "2B"
        case .triple: return "3B"
        case .homeRun: return "HR"
        case .walk: return "BB"
        case .intentionalWalk: return "IBB"
        case .hitByPitch: return "HBP"
        case .strikeoutSwinging: return "K"
        case .strikeoutLooking: return "K"
        case .flyout(let pos): return "F\(pos)"
        case .popout(let pos): return "P\(pos)"
        case .lineout(let pos): return "L\(pos)"
        case .groundout(let seq): return seq
        case .forceOut(let seq): return "FO\n\(seq)"
        case .fieldersChoice: return "FC"
        case .doublePlay(let seq): return "\(seq)\nGIDP"
        case .triplePlay: return "TP"
        case .sacFly(let pos):
            if let pos { return "SAC\nF\(pos)" }
            return "SAC"
        case .sacBunt: return "SAC"
        case .fieldError: return "E"
        case .stolenBase: return "SB"
        case .caughtStealing: return "CS"
        case .pickoff: return "PO"
        case .balk: return "BK"
        case .wildPitch: return "WP"
        case .passedBall: return "PB"
        case .live: return "LIVE"
        case .runnerOnly: return "Z"
        case .empty: return ""
        case .other(let text): return text
        }
    }

    var isHit: Bool {
        switch self {
        case .single, .double, .triple, .homeRun: return true
        default: return false
        }
    }

    var isWalk: Bool {
        switch self {
        case .walk, .intentionalWalk, .hitByPitch: return true
        default: return false
        }
    }

    var isSacrifice: Bool {
        switch self {
        case .sacFly, .sacBunt: return true
        default: return false
        }
    }

    var isStrikeout: Bool {
        switch self {
        case .strikeoutSwinging, .strikeoutLooking: return true
        default: return false
        }
    }

    var isCalledStrikeout: Bool { self == .strikeoutLooking }
    var isHomeRun: Bool { self == .homeRun }
    var isLive: Bool { self == .live }
    var countsAsAtBat: Bool { !isWalk && !isSacrifice }
}

extension ScorecardResult: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.parse(raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(encodingText)
    }

    private var encodingText: String {
        if case .strikeoutLooking = self { return "Ʞ" }
        return displayText
    }

    static func parse(_ text: String) -> ScorecardResult {
        switch text {
        case "1B": return .single
        case "2B": return .double
        case "3B": return .triple
        case "HR": return .homeRun
        case "BB": return .walk
        case "IBB": return .intentionalWalk
        case "HBP": return .hitByPitch
        case "K": return .strikeoutSwinging
        case "Ʞ": return .strikeoutLooking
        case "FC": return .fieldersChoice
        case "TP": return .triplePlay
        case "SAC": return .sacBunt
        case "E": return .fieldError
        case "SB": return .stolenBase
        case "CS": return .caughtStealing
        case "PO": return .pickoff
        case "BK": return .balk
        case "WP": return .wildPitch
        case "PB": return .passedBall
        case "FO": return .forceOut(sequence: "")
        case "GIDP": return .doublePlay(sequence: "")
        case "LIVE": return .live
        case "Z": return .runnerOnly
        case "": return .empty
        default:
            let lines = text.split(separator: "\n", maxSplits: 1).map(String.init)
            if lines.count == 2 {
                if lines[1] == "GIDP" { return .doublePlay(sequence: lines[0]) }
                if lines[0] == "FO" { return .forceOut(sequence: lines[1]) }
                if lines[0] == "SAC" && lines[1].hasPrefix("F") {
                    return .sacFly(position: String(lines[1].dropFirst()))
                }
            }
            if text.hasPrefix("F") && text.count <= 3 && text.dropFirst().allSatisfy(\.isNumber) {
                return .flyout(position: String(text.dropFirst()))
            }
            if text.hasPrefix("P") && text.count <= 3 && text.dropFirst().allSatisfy(\.isNumber) {
                return .popout(position: String(text.dropFirst()))
            }
            if text.hasPrefix("L") && text.count <= 3 && text.dropFirst().allSatisfy(\.isNumber) {
                return .lineout(position: String(text.dropFirst()))
            }
            if text.contains("-") && !text.contains("\n") {
                return .groundout(sequence: text)
            }
            return .other(text: text)
        }
    }
}
