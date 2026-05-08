import Foundation

// MARK: - Runner Base State

struct RunnerBaseState {
    var reachFirst = false
    var reachSecond = false
    var reachThird = false
    var reachHome = false
    var outAtFirst = false
    var outAtSecond = false
    var outAtThird = false
    var outAtHome = false
    var annotations: [BaseAnnotation] = []
    var pinchRunnerName: String?

    mutating func applyInitialReach(for eventType: String) {
        switch eventType {
        case "single", "walk", "hit_by_pitch", "intent_walk", "field_error", "fielders_choice":
            reachFirst = true
        case "double":
            reachFirst = true; reachSecond = true
        case "triple":
            reachFirst = true; reachSecond = true; reachThird = true
        case "home_run":
            reachFirst = true; reachSecond = true; reachThird = true; reachHome = true
        default:
            break
        }
    }

    mutating func advanceBatter(to end: String) {
        switch end {
        case "1b": reachFirst = true
        case "2b": reachFirst = true; reachSecond = true
        case "3b": reachFirst = true; reachSecond = true; reachThird = true
        case "score", "home": reachFirst = true; reachSecond = true; reachThird = true; reachHome = true
        default: break
        }
    }

    mutating func advanceRunner(to end: String) {
        switch end {
        case "1b": reachFirst = true
        case "2b": reachSecond = true; lineToSecond = true
        case "3b": reachThird = true; lineToThird = true
        case "score", "home":
            if reachSecond { reachThird = true; lineToThird = true }
            reachHome = true; lineToHome = true
        default: break
        }
    }

    mutating func recordOut(at base: String) {
        switch base {
        case "1b": reachFirst = false; outAtFirst = true
        case "2b": reachSecond = false; outAtSecond = true
        case "3b": reachThird = false; outAtThird = true
        case "home": reachHome = false; outAtHome = true
        default: break
        }
    }

    var isResolved: Bool {
        reachHome || outAtFirst || outAtSecond || outAtThird || outAtHome
    }

    var currentBase: Int? {
        if reachHome { return 4 }
        if reachThird { return 3 }
        if reachSecond { return 2 }
        if reachFirst { return 1 }
        return nil
    }

    // Line-to fields for placed runners (who advance from a starting base)
    var lineToSecond = false
    var lineToThird = false
    var lineToHome = false

    func toBasesReached(includeLines: Bool = false) -> BasesReached {
        BasesReached(
            first: reachFirst,
            second: reachSecond,
            third: reachThird,
            home: reachHome,
            lineToFirst: includeLines ? (reachFirst ? true : nil) : nil,
            lineToSecond: includeLines ? (lineToSecond ? true : nil) : nil,
            lineToThird: includeLines ? (lineToThird ? true : nil) : nil,
            lineToHome: includeLines ? (lineToHome ? true : nil) : nil,
            outAtFirst: outAtFirst,
            outAtSecond: outAtSecond,
            outAtThird: outAtThird,
            outAtHome: outAtHome,
            annotations: annotations.isEmpty ? nil : annotations
        )
    }
}
