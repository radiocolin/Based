import UIKit

enum AppFont {
    static let permanentMarker = "PermanentMarker-Regular"
    static let patrickHand = "PatrickHand-Regular"
    static let ibmPlexBold = "IBMPlexSansCond-Bold"
    static let ibmPlexRegular = "IBMPlexSansCond-Regular"
    static let ibmPlexSemiBold = "IBMPlexSansCond-SemiBold"

    static func permanent(_ size: CGFloat, textStyle: UIFont.TextStyle, compatibleWith traitCollection: UITraitCollection? = nil) -> UIFont {
        let fallback = UIFont.systemFont(ofSize: size, weight: .bold)
        return scaledFont(named: permanentMarker, size: size, textStyle: textStyle, fallback: fallback, compatibleWith: traitCollection)
    }

    static func patrick(_ size: CGFloat, textStyle: UIFont.TextStyle, compatibleWith traitCollection: UITraitCollection? = nil) -> UIFont {
        let fallback = UIFont.systemFont(ofSize: size)
        return scaledFont(named: patrickHand, size: size, textStyle: textStyle, fallback: fallback, compatibleWith: traitCollection)
    }

    static func ibmPlexCondensed(_ size: CGFloat, textStyle: UIFont.TextStyle, compatibleWith traitCollection: UITraitCollection? = nil) -> UIFont {
        let fallback = UIFont.systemFont(ofSize: size)
        return scaledFont(named: ibmPlexRegular, size: size, textStyle: textStyle, fallback: fallback, compatibleWith: traitCollection)
    }

    static func ibmPlexCondensedBold(_ size: CGFloat, textStyle: UIFont.TextStyle, compatibleWith traitCollection: UITraitCollection? = nil) -> UIFont {
        let fallback = UIFont.systemFont(ofSize: size, weight: .bold)
        return scaledFont(named: ibmPlexBold, size: size, textStyle: textStyle, fallback: fallback, compatibleWith: traitCollection)
    }

    static func ibmPlexCondensedSemiBold(_ size: CGFloat, textStyle: UIFont.TextStyle, compatibleWith traitCollection: UITraitCollection? = nil) -> UIFont {
        let fallback = UIFont.systemFont(ofSize: size, weight: .semibold)
        return scaledFont(named: ibmPlexSemiBold, size: size, textStyle: textStyle, fallback: fallback, compatibleWith: traitCollection)
    }

    private static func scaledFont(
        named fontName: String,
        size: CGFloat,
        textStyle: UIFont.TextStyle,
        fallback: UIFont,
        compatibleWith traitCollection: UITraitCollection?
    ) -> UIFont {
        let baseFont = UIFont(name: fontName, size: size) ?? fallback
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: baseFont, compatibleWith: traitCollection)
    }
}
