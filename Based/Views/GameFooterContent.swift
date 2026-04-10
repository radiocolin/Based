import UIKit

struct FooterPitcherGroup {
    let title: String
    let pitchers: [ScorecardPitcher]
}

enum GameFooterContent {
    private static let pitcherStatLabels = ["IP", "H", "R", "ER", "BB", "K"]

    static func makePitcherSection(
        groups: [FooterPitcherGroup],
        target: AnyObject?,
        action: Selector?
    ) -> UIView? {
        let visibleGroups = groups.filter { !$0.pitchers.isEmpty }
        guard !visibleGroups.isEmpty else { return nil }

        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 2

        for (groupIndex, group) in visibleGroups.enumerated() {
            let titleLabel = UILabel()
            titleLabel.text = group.title
            titleLabel.font = AppFont.patrick(16, textStyle: .headline)
            titleLabel.textColor = AppColors.pencil
            titleLabel.accessibilityTraits = .header
            titleLabel.adjustsFontForContentSizeCategory = true
            container.addArrangedSubview(titleLabel)

            let headerRow = UIStackView()
            headerRow.axis = .horizontal
            headerRow.spacing = 4
            headerRow.isAccessibilityElement = false

            let nameHeader = UILabel()
            nameHeader.text = "Name"
            nameHeader.font = AppFont.patrick(12, textStyle: .caption1)
            nameHeader.textColor = AppColors.pencil.withAlphaComponent(0.6)
            nameHeader.isAccessibilityElement = false
            nameHeader.adjustsFontForContentSizeCategory = true
            headerRow.addArrangedSubview(nameHeader)

            for label in pitcherStatLabels {
                let statLabel = UILabel()
                statLabel.text = label
                statLabel.font = AppFont.patrick(12, textStyle: .caption1)
                statLabel.textColor = AppColors.pencil.withAlphaComponent(0.6)
                statLabel.textAlignment = .center
                statLabel.isAccessibilityElement = false
                statLabel.adjustsFontForContentSizeCategory = true
                statLabel.widthAnchor.constraint(equalToConstant: 30).isActive = true
                headerRow.addArrangedSubview(statLabel)
            }
            container.addArrangedSubview(headerRow)

            for (pitcherIndex, pitcher) in group.pitchers.enumerated() {
                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = 4
                row.backgroundColor = pitcherIndex % 2 == 1 ? AppColors.alternateRow.withAlphaComponent(0.5) : .clear
                row.isAccessibilityElement = true
                if let target, let action {
                    row.isUserInteractionEnabled = true
                    row.tag = pitcher.id
                    let tap = UITapGestureRecognizer(target: target, action: action)
                    row.addGestureRecognizer(tap)
                }

                let nameLabel = UILabel()
                nameLabel.text = pitcher.fullName
                nameLabel.font = AppFont.permanent(14, textStyle: .body)
                nameLabel.textColor = AppColors.pencil
                nameLabel.isAccessibilityElement = false
                nameLabel.adjustsFontForContentSizeCategory = true
                row.addArrangedSubview(nameLabel)

                let stats = [pitcher.ip, "\(pitcher.h)", "\(pitcher.r)", "\(pitcher.er)", "\(pitcher.bb)", "\(pitcher.k)"]
                for value in stats {
                    let valueLabel = UILabel()
                    valueLabel.text = value
                    valueLabel.font = AppFont.permanent(14, textStyle: .body)
                    valueLabel.textColor = AppColors.pencil
                    valueLabel.textAlignment = .center
                    valueLabel.isAccessibilityElement = false
                    valueLabel.adjustsFontForContentSizeCategory = true
                    valueLabel.widthAnchor.constraint(equalToConstant: 30).isActive = true
                    row.addArrangedSubview(valueLabel)
                }

                row.accessibilityLabel = AccessibilitySupport.joined([
                    group.title,
                    pitcher.fullName,
                    "Innings pitched \(pitcher.ip)",
                    "Hits \(pitcher.h)",
                    "Runs \(pitcher.r)",
                    "Earned runs \(pitcher.er)",
                    "Walks \(pitcher.bb)",
                    "Strikeouts \(pitcher.k)"
                ])
                row.accessibilityTraits = action == nil ? .staticText : .button

                container.addArrangedSubview(row)
            }

            if groupIndex < visibleGroups.count - 1 {
                let spacer = UIView()
                spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
                container.addArrangedSubview(spacer)
            }
        }

        return container
    }

    static func makeUmpireText(_ umpires: [ScorecardUmpire]) -> NSAttributedString? {
        guard !umpires.isEmpty else { return nil }

        let attributedText = NSMutableAttributedString(string: "UMPIRES\n", attributes: [
            .font: AppFont.patrick(16, textStyle: .headline),
            .foregroundColor: AppColors.pencil
        ])

        for (index, umpire) in umpires.enumerated() {
            let roleAttributes: [NSAttributedString.Key: Any] = [
                .font: AppFont.patrick(14, textStyle: .footnote),
                .foregroundColor: AppColors.pencil.withAlphaComponent(0.7)
            ]
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: AppFont.permanent(14, textStyle: .body),
                .foregroundColor: AppColors.pencil
            ]
            attributedText.append(NSAttributedString(string: "\(umpire.type): ", attributes: roleAttributes))
            attributedText.append(NSAttributedString(string: umpire.fullName, attributes: nameAttributes))
            if index < umpires.count - 1 {
                attributedText.append(NSAttributedString(string: "\n", attributes: roleAttributes))
            }
        }

        return attributedText
    }

    static func makeUmpireAccessibilityLabel(_ umpires: [ScorecardUmpire]) -> String? {
        guard !umpires.isEmpty else { return nil }
        return AccessibilitySupport.umpiresDescription(umpires)
    }

    static func makeGameInfoText(gameInfoItems: [GameInfoItem], weather: Weather?) -> NSAttributedString? {
        let displayLabels = ["First pitch", "T", "Att", "Venue"]
        let infoItems = gameInfoItems.filter { item in
            displayLabels.contains(item.label) && item.value != nil
        }
        let dateItem = gameInfoItems.first { $0.value == nil && !$0.label.isEmpty }

        guard !infoItems.isEmpty || dateItem != nil || weather != nil else { return nil }

        let labelMap = ["First pitch": "First Pitch", "T": "Duration", "Att": "Attendance"]
        let attributedText = NSMutableAttributedString(string: "GAME INFO\n", attributes: [
            .font: AppFont.patrick(16, textStyle: .headline),
            .foregroundColor: AppColors.pencil
        ])

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.patrick(14, textStyle: .footnote),
            .foregroundColor: AppColors.pencil.withAlphaComponent(0.7)
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.permanent(14, textStyle: .body),
            .foregroundColor: AppColors.pencil
        ]

        for item in infoItems {
            let displayLabel = labelMap[item.label] ?? item.label
            let value = (item.value ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "."))
            attributedText.append(NSAttributedString(string: "\(displayLabel): ", attributes: labelAttributes))
            attributedText.append(NSAttributedString(string: "\(value)\n", attributes: valueAttributes))
        }

        if let weather {
            var weatherParts: [String] = []
            if let temp = weather.temp { weatherParts.append("\(temp)°F") }
            if let condition = weather.condition { weatherParts.append(condition) }
            if !weatherParts.isEmpty {
                attributedText.append(NSAttributedString(string: "Weather: ", attributes: labelAttributes))
                attributedText.append(NSAttributedString(string: "\(weatherParts.joined(separator: ", "))\n", attributes: valueAttributes))
            }
            if let wind = weather.wind {
                attributedText.append(NSAttributedString(string: "Wind: ", attributes: labelAttributes))
                attributedText.append(NSAttributedString(string: "\(wind)\n", attributes: valueAttributes))
            }
        }

        if let dateItem {
            attributedText.append(NSAttributedString(string: dateItem.label, attributes: valueAttributes))
        }

        return attributedText
    }
}
