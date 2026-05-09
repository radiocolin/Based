import TipKit
import SwiftUI

struct TapAtBatTip: Tip {
    static let gameViewed = Event(id: "basedGameViewed")

    var title: Text {
        Text("See Play Details")
    }

    var message: Text? {
        Text("Tap any at-bat cell to see the full play-by-play.")
    }

    var image: Image? {
        Image(systemName: "hand.tap")
    }

    var options: [any TipOption] {
        MaxDisplayCount(3)
    }
}

struct TeamScheduleTip: Tip {
    @Parameter
    static var tapAtBatSeen: Bool = false

    var title: Text {
        Text("View Team Schedule")
    }

    var message: Text? {
        Text("Tap a team name in the scoreboard to see their full schedule.")
    }

    var image: Image? {
        Image(systemName: "calendar")
    }

    var rules: [Rule] {
        #Rule(Self.$tapAtBatSeen) { $0 == true }
        #Rule(TapAtBatTip.gameViewed) { $0.donations.count >= 3 }
    }

    var options: [any TipOption] {
        MaxDisplayCount(3)
    }
}

struct ShareScorecardTip: Tip {
    @Parameter
    static var teamScheduleSeen: Bool = false

    var title: Text {
        Text("Share Your Scorecard")
    }

    var message: Text? {
        Text("Export the scorecard as an image or PDF to share with friends.")
    }

    var image: Image? {
        Image(systemName: "square.and.arrow.up")
    }

    var rules: [Rule] {
        #Rule(Self.$teamScheduleSeen) { $0 == true }
        #Rule(TapAtBatTip.gameViewed) { $0.donations.count >= 5 }
    }

    var options: [any TipOption] {
        MaxDisplayCount(3)
    }
}

struct FavoriteTeamTip: Tip {
    var title: Text {
        Text("Favorite a Team")
    }

    var message: Text? {
        Text("Long press any team to add it to your favorites.")
    }

    var image: Image? {
        Image(systemName: "star")
    }

    var options: [any TipOption] {
        MaxDisplayCount(3)
    }
}

struct StandingsModeTip: Tip {
    var title: Text {
        Text("Division & Wildcard")
    }

    var message: Text? {
        Text("Switch between Division and Wildcard views to see different standings.")
    }

    var image: Image? {
        Image(systemName: "arrow.left.arrow.right")
    }

    var options: [any TipOption] {
        MaxDisplayCount(3)
    }
}

enum BasedTips {
    static var showAllTipsForTesting = false

    static func configure() {
        do {
            if showAllTipsForTesting {
                try Tips.resetDatastore()
                Tips.showAllTipsForTesting()
            }
            try Tips.configure([
                .displayFrequency(showAllTipsForTesting ? .immediate : .daily)
            ])
        } catch {
            print("TipKit configuration failed: \(error)")
        }
    }
}
