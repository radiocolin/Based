import UIKit

enum AppFont {
    static func permanent(_ size: CGFloat, textStyle: UIFont.TextStyle, compatibleWith traitCollection: UITraitCollection? = nil) -> UIFont {
        let fallback = UIFont.systemFont(ofSize: size, weight: .bold)
        return scaledFont(named: "PermanentMarker-Regular", size: size, textStyle: textStyle, fallback: fallback, compatibleWith: traitCollection)
    }

    static func patrick(_ size: CGFloat, textStyle: UIFont.TextStyle, compatibleWith traitCollection: UITraitCollection? = nil) -> UIFont {
        let fallback = UIFont.systemFont(ofSize: size)
        return scaledFont(named: "PatrickHand-Regular", size: size, textStyle: textStyle, fallback: fallback, compatibleWith: traitCollection)
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
