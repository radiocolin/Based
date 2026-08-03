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

    /// A runner physically passes through every intermediate base to reach a further one — a
    /// single that sends a runner from first to third never stops her at second, but the
    /// scorecard path must still be drawn unbroken through it. Each case therefore cascades
    /// through every earlier base the runner didn't already start this half-inning on, otherwise
    /// the diamond draws a disconnected floating segment (e.g. second-to-third with no
    /// first-to-second line feeding into it) whenever a runner skips stopping at an intermediate
    /// base. The `priorBase` guard exists for MLB's placed extra-innings runner, who can start a
    /// half-inning already on second or third — cascading unconditionally would fabricate a line
    /// for a leg she never actually ran this inning.
    mutating func advanceRunner(to end: String) {
        let priorBase = currentBase ?? 0
        switch end {
        case "1b":
            reachFirst = true
        case "2b":
            reachSecond = true; lineToSecond = true
        case "3b":
            if priorBase < 2 { reachSecond = true; lineToSecond = true }
            reachThird = true; lineToThird = true
        case "score", "home":
            if priorBase < 2 { reachSecond = true; lineToSecond = true }
            if priorBase < 3 { reachThird = true; lineToThird = true }
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
