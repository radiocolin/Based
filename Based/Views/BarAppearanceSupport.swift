import UIKit

enum BarAppearanceSupport {
    static func titleFont(for traitCollection: UITraitCollection) -> UIFont {
        AppFont.permanent(28, textStyle: .largeTitle, compatibleWith: traitCollection)
    }

    static func buttonFont(for traitCollection: UITraitCollection) -> UIFont {
        AppFont.patrick(20, textStyle: .headline, compatibleWith: traitCollection)
    }

    static func iconSize(for traitCollection: UITraitCollection, base: CGFloat = 32, maximum: CGFloat? = nil) -> CGSize {
        var side = UIFontMetrics(forTextStyle: .headline).scaledValue(for: base, compatibleWith: traitCollection)
        if let maximum {
            side = min(side, maximum)
        }
        return CGSize(width: side, height: side)
    }

    static func applyPlainBarButtonAppearance(_ appearance: UIBarButtonItemAppearance, font: UIFont, color: UIColor) {
        let normalAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let highlightedAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color.withAlphaComponent(0.5)]

        let normalState = appearance.normal
        normalState.backgroundImage = UIImage()
        normalState.titlePositionAdjustment = .zero

        let highlightedState = appearance.highlighted
        highlightedState.backgroundImage = UIImage()
        highlightedState.titlePositionAdjustment = .zero

        let focusedState = appearance.focused
        focusedState.backgroundImage = UIImage()
        focusedState.titlePositionAdjustment = .zero

        let disabledState = appearance.disabled
        disabledState.backgroundImage = UIImage()
        disabledState.titlePositionAdjustment = .zero

        appearance.normal.titleTextAttributes = normalAttributes
        appearance.highlighted.titleTextAttributes = highlightedAttributes
        appearance.focused.titleTextAttributes = normalAttributes
        appearance.disabled.titleTextAttributes = normalAttributes
    }
}
