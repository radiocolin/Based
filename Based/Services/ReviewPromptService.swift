import StoreKit
import UIKit

final class ReviewPromptService {
    static let shared = ReviewPromptService()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let sessionCount = "reviewPrompt.sessionCount"
        static let lastPromptDate = "reviewPrompt.lastPromptDate"
        static let lastBackgroundDate = "reviewPrompt.lastBackgroundDate"
    }

    private let minimumSessions = 5
    private let minimumDaysBetweenPrompts = 14
    private let returnGapDays = 3

    private init() {}

    func recordSession() {
        defaults.set(defaults.integer(forKey: Keys.sessionCount) + 1, forKey: Keys.sessionCount)
    }

    func recordBackgroundEntry() {
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastBackgroundDate)
    }

    func requestReviewIfAppropriate(in scene: UIWindowScene?) {
        guard let scene else { return }
        guard defaults.integer(forKey: Keys.sessionCount) >= minimumSessions else { return }
        guard daysSinceLastPrompt() >= minimumDaysBetweenPrompts else { return }

        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastPromptDate)
        AppStore.requestReview(in: scene)
    }

    func requestReviewAfterReturnIfAppropriate(in scene: UIWindowScene?) {
        let lastBackground = defaults.double(forKey: Keys.lastBackgroundDate)
        guard lastBackground > 0 else { return }
        let daysSinceBackground = Date().timeIntervalSince(Date(timeIntervalSince1970: lastBackground)) / 86400
        guard daysSinceBackground >= Double(returnGapDays) else { return }
        requestReviewIfAppropriate(in: scene)
    }

    private func daysSinceLastPrompt() -> Int {
        let lastPrompt = defaults.double(forKey: Keys.lastPromptDate)
        guard lastPrompt > 0 else { return Int.max }
        return Int(Date().timeIntervalSince(Date(timeIntervalSince1970: lastPrompt)) / 86400)
    }
}
