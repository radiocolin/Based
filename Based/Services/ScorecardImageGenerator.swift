import UIKit

/// A dedicated service to generate a high-quality, landscape scorecard graphic.
/// Draws directly into a CGContext for maximum precision and to bypass UIKit off-screen rendering limitations.
enum ScorecardExportMode: Int, CaseIterable {
    case blank = 0
    case summary = 1
    case full = 2
    case highlights = 3

    var title: String {
        switch self {
        case .blank: return "Blank Scorecard"
        case .summary: return "Game Summary"
        case .full: return "Full Scorecard"
        case .highlights: return "Highlights"
        }
    }

    var subtitle: String {
        switch self {
        case .blank: return "Structure and labels only — fill in by hand"
        case .summary: return "Score, lineups, game info, and umpires"
        case .full: return "Complete scorecard with play-by-play"
        case .highlights: return "Pick up to 6 plays for a 9:16 share card"
        }
    }

    var showScoreboard: Bool { rawValue >= Self.summary.rawValue && self != .highlights }
    var showGameInfo: Bool { rawValue >= Self.summary.rawValue && self != .highlights }
    var showLineup: Bool { rawValue >= Self.summary.rawValue && self != .highlights }
    var showAtBatResults: Bool { rawValue >= Self.full.rawValue && self != .highlights }
    var showPitchers: Bool { rawValue >= Self.full.rawValue && self != .highlights }
    var showUmpires: Bool { rawValue >= Self.summary.rawValue && self != .highlights }
    var isHighlights: Bool { self == .highlights }
}

final class ScorecardImageGenerator {

    struct Config {
        let margin: CGFloat = 5
        let columnGap: CGFloat = 16
        let rowHeight: CGFloat = 60
        let headerHeight: CGFloat = 40
        let nameWidth: CGFloat = 220
        let inningWidth: CGFloat = 60
        let statWidth: CGFloat = 50

        // Pitcher Table Config
        let pNameWidth: CGFloat = 250
        let pStatWidth: CGFloat = 60
        let pRowHeight: CGFloat = 40
        
        let pencilColor = AppColors.pencil
        let paperColor = AppColors.paper
        let gridColor = AppColors.grid
        
        let teamTitleFont = UIFont(name: AppFont.permanentMarker, size: 48) ?? .systemFont(ofSize: 48, weight: .bold)
        let headerFont = UIFont(name: AppFont.ibmPlexBold, size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        let nameFont = UIFont(name: AppFont.permanentMarker, size: 16) ?? .systemFont(ofSize: 16)
        let posFont = UIFont(name: AppFont.patrickHand, size: 14) ?? .systemFont(ofSize: 14)
        let resultFont = UIFont(name: AppFont.permanentMarker, size: 18) ?? .systemFont(ofSize: 18)
        let legibilityFont = UIFont(name: AppFont.patrickHand, size: 12) ?? .systemFont(ofSize: 12)

        let sectionTitleFont = UIFont(name: AppFont.ibmPlexBold, size: 28) ?? .systemFont(ofSize: 28, weight: .bold)
        let footerHeaderFont = UIFont(name: AppFont.ibmPlexBold, size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
        let footerBodyFont = UIFont(name: AppFont.ibmPlexRegular, size: 16) ?? .systemFont(ofSize: 16)
        let footerDataFont = UIFont(name: AppFont.permanentMarker, size: 16) ?? .systemFont(ofSize: 16)
    }
    
    private let config = Config()

    static let defaultUmpirePositions: [ScorecardUmpire] = [
        ScorecardUmpire(fullName: "", type: "HP"),
        ScorecardUmpire(fullName: "", type: "1B"),
        ScorecardUmpire(fullName: "", type: "2B"),
        ScorecardUmpire(fullName: "", type: "3B"),
    ]
    

    private struct LayoutInfo {
        let filteredInfo: [GameInfoItem]
        let imageWidth: CGFloat
        let contentWidth: CGFloat
        let colWidth: CGFloat
        let awayLayout: ColumnLayout
        let homeLayout: ColumnLayout
        let scorecardSectionHeight: CGFloat
        let pitcherSectionHeight: CGFloat
        let umpireHeight: CGFloat
        let sbWidth: CGFloat
        let totalHeight: CGFloat
    }

    private let layoutEngine = ScorecardLayoutEngine()

    func generate(scorecard: ScorecardData, linescore: Linescore?, options: ScorecardExportMode = .full, userInterfaceStyle: UIUserInterfaceStyle = .unspecified) async -> UIImage {
        let pdfData = await generatePDF(scorecard: scorecard, linescore: linescore, options: options, userInterfaceStyle: userInterfaceStyle)
        guard let provider = CGDataProvider(data: pdfData as CFData),
              let pdf = CGPDFDocument(provider),
              let page = pdf.page(at: 1) else {
            return UIImage()
        }
        let pageRect = page.getBoxRect(.mediaBox)
        let scale: CGFloat = 8
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            withTraitStyle(userInterfaceStyle) {
                let ctx = context.cgContext
                self.config.paperColor.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.translateBy(x: 0, y: size.height)
                ctx.scaleBy(x: scale, y: -scale)
                ctx.drawPDFPage(page)
            }
        }
    }

    func generatePDF(scorecard: ScorecardData, linescore: Linescore?, options: ScorecardExportMode = .full, userInterfaceStyle: UIUserInterfaceStyle = .unspecified) async -> Data {
        let layout = computeLayout(scorecard: scorecard, linescore: linescore, options: options)
        let pageWidth: CGFloat = 792
        let pageHeight: CGFloat = 612
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfMargin: CGFloat = 8
        let printableWidth = pageWidth - 2 * pdfMargin
        let printableHeight = pageHeight - 2 * pdfMargin
        let scale = min(printableWidth / layout.imageWidth, printableHeight / layout.totalHeight)
        let scaledWidth = layout.imageWidth * scale
        let scaledHeight = layout.totalHeight * scale
        let offsetX = (pageWidth - scaledWidth) / 2
        let offsetY = (pageHeight - scaledHeight) / 2

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            withTraitStyle(userInterfaceStyle) {
                context.beginPage()
                let ctx = context.cgContext
                self.config.paperColor.setFill()
                ctx.fill(pageRect)
                ctx.saveGState()
                ctx.translateBy(x: offsetX, y: offsetY)
                ctx.scaleBy(x: scale, y: scale)
                self.drawAllContent(scorecard: scorecard, linescore: linescore, layout: layout, imageWidth: layout.imageWidth, options: options, ctx: ctx)
                ctx.restoreGState()
            }
        }
    }

    private func withTraitStyle(_ style: UIUserInterfaceStyle, _ work: () -> Void) {
        if style == .unspecified {
            work()
        } else {
            UITraitCollection(userInterfaceStyle: style).performAsCurrent(work)
        }
    }

    // MARK: - Highlights Card (9:16 portrait, user-picked plays)

    private enum Highlights {
        static let pageWidth: CGFloat = 720
        static let pageHeight: CGFloat = 1280
        static let outerPadding: CGFloat = 28
        static let headerHeight: CGFloat = 150
        static let attributionHeight: CGFloat = 20
        static let cellGap: CGFloat = 12
        static let maxPlays: Int = 6
    }

    func generateHighlights(scorecard: ScorecardData, linescore: Linescore?, plays: [AtBatEvent], userInterfaceStyle: UIUserInterfaceStyle = .unspecified) async -> UIImage {
        let pdfData = await generateHighlightsPDF(scorecard: scorecard, linescore: linescore, plays: plays, userInterfaceStyle: userInterfaceStyle)
        guard let provider = CGDataProvider(data: pdfData as CFData),
              let pdf = CGPDFDocument(provider),
              let page = pdf.page(at: 1) else {
            return UIImage()
        }
        let pageRect = page.getBoxRect(.mediaBox)
        let scale: CGFloat = 4
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            withTraitStyle(userInterfaceStyle) {
                let ctx = context.cgContext
                self.config.paperColor.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.translateBy(x: 0, y: size.height)
                ctx.scaleBy(x: scale, y: -scale)
                ctx.drawPDFPage(page)
            }
        }
    }

    func generateHighlightsPDF(scorecard: ScorecardData, linescore: Linescore?, plays: [AtBatEvent], userInterfaceStyle: UIUserInterfaceStyle = .unspecified) async -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: Highlights.pageWidth, height: Highlights.pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            withTraitStyle(userInterfaceStyle) {
                context.beginPage()
                let ctx = context.cgContext
                self.config.paperColor.setFill()
                ctx.fill(pageRect)
                self.drawHighlightsCard(in: pageRect, scorecard: scorecard, linescore: linescore, plays: plays, ctx: ctx)
            }
        }
    }

    private func drawHighlightsCard(in pageRect: CGRect, scorecard: ScorecardData, linescore: Linescore?, plays: [AtBatEvent], ctx: CGContext) {
        let contentRect = pageRect.insetBy(dx: Highlights.outerPadding, dy: Highlights.outerPadding)

        let headerRect = CGRect(x: contentRect.minX, y: contentRect.minY, width: contentRect.width, height: Highlights.headerHeight)
        drawHighlightsHeader(in: headerRect, scorecard: scorecard, linescore: linescore, ctx: ctx)

        let attributionY = pageRect.maxY - Highlights.outerPadding - Highlights.attributionHeight
        let gridY = headerRect.maxY + Highlights.cellGap
        let gridRect = CGRect(
            x: contentRect.minX,
            y: gridY,
            width: contentRect.width,
            height: attributionY - gridY - Highlights.cellGap
        )
        drawHighlightsGrid(in: gridRect, plays: plays, scorecard: scorecard, ctx: ctx)

        let attrFont = UIFont(name: AppFont.ibmPlexBold, size: 14) ?? .systemFont(ofSize: 14, weight: .bold)
        let attrAttrs: [NSAttributedString.Key: Any] = [
            .font: attrFont,
            .foregroundColor: config.pencilColor.withAlphaComponent(0.45),
            .kern: 4.0
        ]
        let attrText = "BASED"
        let aSize = (attrText as NSString).size(withAttributes: attrAttrs)
        NSAttributedString(string: attrText, attributes: attrAttrs).draw(at: CGPoint(
            x: pageRect.midX - aSize.width / 2,
            y: attributionY + (Highlights.attributionHeight - aSize.height) / 2
        ))
    }

    private func drawHighlightsHeader(in rect: CGRect, scorecard: ScorecardData, linescore: Linescore?, ctx: CGContext) {
        let awayName = scorecard.teams.away.name ?? "Away"
        let homeName = scorecard.teams.home.name ?? "Home"
        let awayColor = TeamColorProvider.color(for: awayName)
        let homeColor = TeamColorProvider.color(for: homeName)
        let awayRuns = linescore?.teams?.away?.runs ?? 0
        let homeRuns = linescore?.teams?.home?.runs ?? 0
        let hasScore = linescore?.innings != nil && !(linescore?.innings?.isEmpty ?? true)

        let barHeight: CGFloat = 4
        let halfWidth = rect.width / 2
        awayColor.setFill()
        ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: halfWidth, height: barHeight))
        homeColor.setFill()
        ctx.fill(CGRect(x: rect.minX + halfWidth, y: rect.minY, width: halfWidth, height: barHeight))

        let dateFont = UIFont(name: AppFont.patrickHand, size: 20) ?? .systemFont(ofSize: 20)

        // A justified two-row table — team name left-aligned, score right-aligned to the same
        // column on both rows — instead of the score just trailing the name inline. Inline
        // put the two scores at whatever X the (differently-wide) team names happened to end at,
        // so "11" and "3" landed nowhere near each other; a real scoreboard aligns the numbers.
        let gap: CGFloat = 14
        func fittedTeamFont(longestName: String, widestScore: String) -> UIFont {
            var size: CGFloat = 36
            while size > 20 {
                let font = UIFont(name: AppFont.permanentMarker, size: size) ?? .systemFont(ofSize: size, weight: .bold)
                let nameWidth = (longestName.uppercased() as NSString).size(withAttributes: [.font: font]).width
                let scoreWidth = hasScore ? (widestScore as NSString).size(withAttributes: [.font: font]).width : 0
                if nameWidth + (hasScore ? gap + scoreWidth : 0) <= rect.width { return font }
                size -= 1
            }
            return UIFont(name: AppFont.permanentMarker, size: 20) ?? .systemFont(ofSize: 20, weight: .bold)
        }
        let longestName = awayName.count >= homeName.count ? awayName : homeName
        let widestScoreText = String(max(awayRuns, homeRuns))
        let teamFont = fittedTeamFont(longestName: longestName, widestScore: widestScoreText)
        let teamAttrs = { (color: UIColor) in [NSAttributedString.Key.font: teamFont, .foregroundColor: color] }

        let rowHeight = ceil(teamFont.lineHeight)
        let rowGap: CGFloat = 6
        let awayY = rect.minY + barHeight + 10
        let homeY = awayY + rowHeight + rowGap

        func drawRow(name: String, runs: Int, color: UIColor, y: CGFloat) {
            (name.uppercased() as NSString).draw(at: CGPoint(x: rect.minX, y: y), withAttributes: teamAttrs(color))
            if hasScore {
                let scoreText = "\(runs)"
                let scoreAttrs = teamAttrs(color)
                let scoreWidth = (scoreText as NSString).size(withAttributes: scoreAttrs).width
                (scoreText as NSString).draw(at: CGPoint(x: rect.maxX - scoreWidth, y: y), withAttributes: scoreAttrs)
            }
        }
        drawRow(name: awayName, runs: awayRuns, color: awayColor, y: awayY)
        drawRow(name: homeName, runs: homeRuns, color: homeColor, y: homeY)

        if let date = highlightsDateString(scorecard: scorecard) {
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: config.pencilColor.withAlphaComponent(0.7)
            ]
            let dSize = (date as NSString).size(withAttributes: dateAttrs)
            let dateY = homeY + rowHeight + 2
            NSAttributedString(string: date, attributes: dateAttrs)
                .draw(at: CGPoint(x: rect.midX - dSize.width / 2, y: dateY))
        }
    }

    private func highlightsDateString(scorecard: ScorecardData) -> String? {
        if let raw = scorecard.gameDate, !raw.isEmpty { return raw }
        for item in scorecard.gameInfo where item.label.lowercased().contains("date") {
            if let v = item.value, !v.isEmpty { return v }
        }
        return nil
    }

    /// One full-width row per play, stacked vertically, rather than a 2-column grid. A grid only
    /// gives each play half the card's width, and baseball play descriptions ("Andreanne Leblanc
    /// singled to right center, RBI...") routinely run 80-140 characters — at half width they
    /// wrapped to more lines than the fixed cell height budgeted for and got cut off with an
    /// ellipsis. Full width roughly doubles the wrap width, which is the single biggest lever for
    /// fitting the whole sentence without shrinking text into illegibility.
    ///
    /// Typography is shared across every row on the card (one binary-searched scale factor), not
    /// computed per row — rows with a short description shouldn't render in a different type size
    /// than rows with a long one just because they ended up shorter. What varies per row is
    /// height: a search finds the largest uniform scale whose *total* natural content height
    /// still fits the card, so fewer/shorter plays render bigger (using the space instead of
    /// leaving it blank) and more/longer plays render smaller — always filling the card exactly,
    /// never overflowing it. Leftover space becomes gap between rows (capped) plus equal top/
    /// bottom padding, rather than dead air trapped inside a single row.
    private func drawHighlightsGrid(in rect: CGRect, plays: [AtBatEvent], scorecard: ScorecardData, ctx: CGContext) {
        let capped = Array(plays.prefix(Highlights.maxPlays))
        guard !capped.isEmpty else { return }
        let count = capped.count
        let minGap: CGFloat = 14
        let maxGap: CGFloat = 44

        func naturalHeights(at scale: CGFloat) -> [CGFloat] {
            let sizes = HighlightsRowSizes(scale: scale)
            return capped.map { highlightsNaturalRowHeight(for: $0, cardWidth: rect.width, scorecard: scorecard, sizes: sizes) }
        }

        let targetRows = rect.height - CGFloat(count - 1) * minGap
        var lo: CGFloat = 0.6, hi: CGFloat = 2.6
        for _ in 0..<20 {
            let mid = (lo + hi) / 2
            if naturalHeights(at: mid).reduce(0, +) > targetRows { hi = mid } else { lo = mid }
        }
        let scale = min(2.6, max(0.6, lo))
        let sizes = HighlightsRowSizes(scale: scale)
        let heights = naturalHeights(at: scale)
        let naturalTotal = heights.reduce(0, +)
        let leftover = max(0, rect.height - CGFloat(count - 1) * minGap - naturalTotal)
        let gap = min(maxGap, minGap + leftover / CGFloat(max(1, count - 1)))
        let usedTotal = naturalTotal + CGFloat(count - 1) * gap
        let topPad = max(0, (rect.height - usedTotal) / 2)

        var y = rect.minY + topPad
        for (i, event) in capped.enumerated() {
            let h = heights[i]
            let rowRect = CGRect(x: rect.minX, y: y, width: rect.width, height: h)
            drawHighlightsPlayRow(in: rowRect, event: event, scorecard: scorecard, sizes: sizes, ctx: ctx)
            y += h + gap
        }
    }

    /// The one set of font/glyph sizes shared by every row on a given card, at a given scale
    /// factor found by drawHighlightsGrid's search. Base sizes were tuned by eye against real
    /// WPBL and MLB games at 1-6 plays.
    private struct HighlightsRowSizes {
        let diamondSide: CGFloat
        let metaSize: CGFloat
        let nameSize: CGFloat
        let descSize: CGFloat

        init(scale: CGFloat) {
            diamondSide = 108 * scale
            // Capped independently of `scale`, unlike the other sizes: this is a compact label
            // ("TOP 1 · DOUBLE · VS. PADGHAM"), not hero text, and letting it grow all the way to
            // a 1-play card's ~2.6x scale made it wide enough to wrap — which silently clipped
            // the pitcher's name, since its height budget assumed a single line.
            metaSize = min(22, 15 * scale)
            nameSize = 30 * scale
            descSize = 20 * scale
        }
    }

    /// "TOP 1 · DOUBLE · VS. PADGHAM" — half/inning, plain-English result, and the pitcher, all on
    /// one compact meta line. Shared by the height estimate and the actual draw so they can never
    /// disagree about what text is being measured.
    private func highlightsMetaText(for event: AtBatEvent) -> String {
        var parts = ["\(event.isTop ? "TOP" : "BOT") \(event.inning)"]
        let resultLabel = highlightsResultLabel(for: event.result)
        if !resultLabel.isEmpty { parts.append(resultLabel.uppercased()) }
        parts.append("vs. \(event.pitcherName)".uppercased())
        return parts.joined(separator: "  \u{00B7}  ")
    }

    private struct HighlightsMetaLayout {
        let pillRect: CGRect
        let pillText: String
        let textRect: CGRect
        var height: CGFloat { max(pillRect.height, textRect.height) }
    }

    /// Lays out the meta line — team pill + "TOP 1 · DOUBLE · VS. PADGHAM" — relative to a local
    /// (0,0) origin. Both highlightsNaturalRowHeight and drawHighlightsPlayRow call this *same*
    /// function rather than each computing their own positions; the earlier bug where the meta
    /// line's height estimate quietly disagreed with what was actually drawn (missing `.kern` in
    /// one of the two call sites) came from having two independent copies of this math that could
    /// drift. One function, called twice, can't drift from itself.
    ///
    /// The pill exists because color is the *only* signal distinguishing home/away elsewhere on
    /// the card, and division rivals sharing a primary color (e.g. Nationals/Braves, both red)
    /// make that signal genuinely ambiguous — plus color alone never works for colorblind readers.
    /// The team code makes "who did this" legible independent of hue.
    private func highlightsMetaLayout(for event: AtBatEvent, scorecard: ScorecardData, metaFont: UIFont, accent: UIColor, maxWidth: CGFloat) -> HighlightsMetaLayout {
        let teamName = event.isTop ? scorecard.teams.away.name : scorecard.teams.home.name
        let pillText = teamAbbreviation(for: teamName ?? "")
        let pillFont = UIFont(name: AppFont.ibmPlexBold, size: metaFont.pointSize * 0.82) ?? metaFont
        let pillAttrs: [NSAttributedString.Key: Any] = [.font: pillFont, .kern: 0.5]
        let pillTextSize = (pillText as NSString).size(withAttributes: pillAttrs)
        let pillPaddingH = max(4, pillFont.pointSize * 0.5)
        let pillHeight = ceil(pillTextSize.height + pillFont.pointSize * 0.36)
        let pillWidth = ceil(pillTextSize.width + pillPaddingH * 2)
        let pillRect = CGRect(x: 0, y: 0, width: pillWidth, height: pillHeight)

        let gap: CGFloat = 8
        let metaText = highlightsMetaText(for: event)
        let metaAttrs: [NSAttributedString.Key: Any] = [.font: metaFont, .foregroundColor: accent, .kern: 1.0]
        let textMaxWidth = max(20, maxWidth - pillWidth - gap)
        let bounds = (metaText as NSString).boundingRect(
            with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: metaAttrs,
            context: nil
        )
        let textRect = CGRect(x: pillWidth + gap, y: 0, width: textMaxWidth, height: ceil(bounds.height))

        return HighlightsMetaLayout(pillRect: pillRect, pillText: pillText, textRect: textRect)
    }

    /// Shrinks the batter-name font (preserving family/weight) until `name` fits on one line
    /// within `maxWidth`, down to a floor. The name is drawn with a plain single-line `.draw(at:)`
    /// (no wrapping — a wrapped hero name would look like a mistake), which means unlike the meta
    /// line and description, nothing constrains its width automatically. A row's card-wide
    /// `sizes.nameSize` is tuned against short/medium names; an 11-letter name like "Yastrzemski"
    /// at a large scale (few plays selected) can exceed the text column's width and run off the
    /// edge of the card entirely if not explicitly fitted. Called identically by the height
    /// estimate and the draw call so they can't disagree about the resulting size.
    private func highlightsFittedNameFont(for name: String, baseSize: CGFloat, maxWidth: CGFloat, minSize: CGFloat = 16) -> UIFont {
        var size = baseSize
        while size > minSize {
            let font = UIFont(name: AppFont.permanentMarker, size: size) ?? .systemFont(ofSize: size, weight: .bold)
            if (name as NSString).size(withAttributes: [.font: font]).width <= maxWidth { return font }
            size -= 1
        }
        return UIFont(name: AppFont.permanentMarker, size: minSize) ?? .systemFont(ofSize: minSize, weight: .bold)
    }

    /// How tall a row needs to be at these sizes to fit its meta line, batter name, and full
    /// description without truncation. Mirrors drawHighlightsPlayRow's own layout math exactly —
    /// both derive positions from the same `sizes` struct — so the estimate here always matches
    /// what actually gets drawn.
    private func highlightsNaturalRowHeight(for event: AtBatEvent, cardWidth: CGFloat, scorecard: ScorecardData, sizes: HighlightsRowSizes) -> CGFloat {
        let barWidth: CGFloat = 5
        let contentWidth = cardWidth - barWidth - 18
        let dSide = min(sizes.diamondSide, contentWidth * 0.46)
        let textWidth = contentWidth - dSide - 20

        let metaFont = UIFont(name: AppFont.ibmPlexBold, size: sizes.metaSize) ?? .systemFont(ofSize: sizes.metaSize, weight: .bold)
        let descFont = UIFont(name: AppFont.patrickHand, size: sizes.descSize) ?? .systemFont(ofSize: sizes.descSize)

        let metaLayout = highlightsMetaLayout(for: event, scorecard: scorecard, metaFont: metaFont, accent: .clear, maxWidth: textWidth)
        let displayName = batterDisplayName(for: event, scorecard: scorecard)
        let nameFont = highlightsFittedNameFont(for: displayName, baseSize: sizes.nameSize, maxWidth: textWidth)
        let nameHeight = ceil(nameFont.lineHeight)
        let descBounds = (event.description as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: descFont],
            context: nil
        )

        let textNeeded = metaLayout.height + 2 + nameHeight + 4 + ceil(descBounds.height)
        return max(textNeeded, dSide)
    }

    /// The scorecard's own lineup abbreviation (last name, suffix-aware — same field the grid's
    /// column headers use), falling back to the last word of the full name for a batter who
    /// isn't in the starting lineup (a pinch hitter, say).
    private func batterDisplayName(for event: AtBatEvent, scorecard: ScorecardData) -> String {
        let lineup = scorecard.lineups.away + scorecard.lineups.home
        if let batter = lineup.first(where: { $0.id == event.batterId }) {
            return batter.abbreviation
        }
        return event.batterName.components(separatedBy: " ").last ?? event.batterName
    }

    /// ScorecardResult.displayText ("1B", "F8", "GIDP") is scorecard notation, the right call for
    /// the dense batter/inning grid where a literate reader expects it. A highlights card is built
    /// to be understood by anyone scrolling past it, so the headline uses plain English instead.
    private func highlightsResultLabel(for result: ScorecardResult) -> String {
        switch result {
        case .single: return "Single"
        case .double: return "Double"
        case .triple: return "Triple"
        case .homeRun: return "Home Run"
        case .walk: return "Walk"
        case .intentionalWalk: return "Intentional Walk"
        case .hitByPitch: return "Hit By Pitch"
        case .strikeoutSwinging, .strikeoutLooking: return "Strikeout"
        case .flyout: return "Flyout"
        case .popout: return "Pop Out"
        case .lineout: return "Lineout"
        case .groundout: return "Groundout"
        case .forceOut: return "Force Out"
        case .fieldersChoice: return "Fielder's Choice"
        case .doublePlay: return "Double Play"
        case .triplePlay: return "Triple Play"
        case .sacFly: return "Sac Fly"
        case .sacBunt: return "Sac Bunt"
        case .fieldError: return "Error"
        case .stolenBase: return "Stolen Base"
        case .caughtStealing: return "Caught Stealing"
        case .pickoff: return "Pickoff"
        case .balk: return "Balk"
        case .wildPitch: return "Wild Pitch"
        case .passedBall: return "Passed Ball"
        case .live, .runnerOnly, .empty: return ""
        case .other(let text): return text.capitalized
        }
    }


    /// Small diamond badge on the left, everything else stacked in a full-width text column on
    /// the right — the same "icon beside unlimited-line text" shape as the in-app TimelineCell
    /// (88x80pt diamond, description with numberOfLines=0), which never has this problem. The
    /// diamond here trades the full base/out/count detail of drawAtBatCell (illegible at badge
    /// size) for a single bold result code and a "did this score" fill — a supporting glyph, not
    /// the dominant element competing with text for space. `sizes` is shared across every row on
    /// the card (see drawHighlightsGrid); `rect.height` is only used to vertically center content.
    private func drawHighlightsPlayRow(in rect: CGRect, event: AtBatEvent, scorecard: ScorecardData, sizes: HighlightsRowSizes, ctx: CGContext) {
        let accent = scorecard.teamAccentColor(for: event)

        // Tried a faint full-row color wash here to reinforce team identity a second way — at an
        // opacity subtle enough not to fight the text, red (SF) and orange (BOS) both flattened
        // into the same pale pink and stopped reading as different teams at all, which is worse
        // than no wash. Reverted; the accent bar + pill are doing that job well on their own.
        let barWidth: CGFloat = 5
        ctx.setFillColor(accent.cgColor)
        ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: barWidth, height: rect.height))

        let contentRect = CGRect(x: rect.minX + barWidth + 18, y: rect.minY, width: rect.width - barWidth - 18, height: rect.height)
        let dSide = min(sizes.diamondSide, contentRect.width * 0.46)
        let textRect = CGRect(
            x: contentRect.minX + dSide + 20,
            y: contentRect.minY,
            width: contentRect.width - dSide - 20,
            height: contentRect.height
        )

        // Meta line: team pill, half/inning, plain-English result, and the pitcher —
        // e.g. [ATL]  TOP 1 · DOUBLE · VS. PADGHAM
        let metaFont = UIFont(name: AppFont.ibmPlexBold, size: sizes.metaSize) ?? .systemFont(ofSize: sizes.metaSize, weight: .bold)
        let metaLayout = highlightsMetaLayout(for: event, scorecard: scorecard, metaFont: metaFont, accent: accent, maxWidth: textRect.width)
        let metaHeight = metaLayout.height

        let pillOrigin = CGPoint(x: textRect.minX + metaLayout.pillRect.minX, y: textRect.minY + (metaHeight - metaLayout.pillRect.height) / 2)
        let pillRect = CGRect(origin: pillOrigin, size: metaLayout.pillRect.size)
        let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: pillRect.height / 2)
        accent.setFill()
        pillPath.fill()
        let pillFont = UIFont(name: AppFont.ibmPlexBold, size: metaFont.pointSize * 0.82) ?? metaFont
        let pillTextAttrs: [NSAttributedString.Key: Any] = [.font: pillFont, .foregroundColor: config.paperColor, .kern: 0.5]
        let pillTextSize = (metaLayout.pillText as NSString).size(withAttributes: pillTextAttrs)
        (metaLayout.pillText as NSString).draw(
            at: CGPoint(x: pillRect.midX - pillTextSize.width / 2, y: pillRect.midY - pillTextSize.height / 2),
            withAttributes: pillTextAttrs
        )

        let metaAttrs: [NSAttributedString.Key: Any] = [.font: metaFont, .foregroundColor: accent, .kern: 1.0]
        (highlightsMetaText(for: event) as NSString).draw(
            with: CGRect(x: textRect.minX + metaLayout.textRect.minX, y: textRect.minY + (metaHeight - metaLayout.textRect.height) / 2, width: metaLayout.textRect.width, height: metaLayout.textRect.height + 4),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: metaAttrs,
            context: nil
        )

        // Batter name — last name only (see batterDisplayName), the card's hero text. Shrunk to
        // fit textRect.width via the same function the height estimate used, so a long name
        // (e.g. "Yastrzemski") at a large scale can never run off the edge of the card.
        let displayName = batterDisplayName(for: event, scorecard: scorecard)
        let nameFont = highlightsFittedNameFont(for: displayName, baseSize: sizes.nameSize, maxWidth: textRect.width)
        let nameY = textRect.minY + metaHeight + 2
        let nameAttrs: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: config.pencilColor]
        (displayName as NSString).draw(at: CGPoint(x: textRect.minX, y: nameY), withAttributes: nameAttrs)
        let nameHeight = ceil(nameFont.lineHeight)

        // Description — sized identically to every other row on the card, guaranteed to fit by
        // drawHighlightsGrid's height search (never truncated, never needs its own shrink pass).
        let descFont = UIFont(name: AppFont.patrickHand, size: sizes.descSize) ?? .systemFont(ofSize: sizes.descSize)
        let descTop = nameY + nameHeight + 4
        (event.description as NSString).draw(
            with: CGRect(x: textRect.minX, y: descTop, width: textRect.width, height: max(0, textRect.maxY - descTop)),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: descFont, .foregroundColor: config.pencilColor.withAlphaComponent(0.85)],
            context: nil
        )

        // The real diamond — same base boxes (1B/2B/3B, filled if reached) and progress path
        // lines as the main scorecard grid, not a stripped-down badge. An earlier pass here
        // simplified this down to an outline + a small result code on the theory that base/out
        // detail would be illegible at badge size, but that traded away the one visual that's
        // actually specific to baseball scorekeeping — which is the whole visual identity of the
        // app — for a generic colored diamond. Sized notably bigger than a supporting-glyph
        // treatment would be (see HighlightsRowSizes) so the base paths are worth including.
        if dSide > 20 {
            let diamondRect = CGRect(x: contentRect.minX, y: contentRect.midY - dSide / 2, width: dSide, height: dSide)
            if event.result.isHomeRun {
                drawHomeRunSparkle(around: diamondRect, color: accent, ctx: ctx)
            }
            let resultFontSize = min(72, max(20, dSide * 0.4))
            drawAtBatCell(in: diamondRect, event: event, accentColor: accent, resultFontSize: resultFontSize, ctx: ctx)
        }
    }

    /// A soft color halo behind the diamond, home runs only — the one outcome almost everyone
    /// recognizes as a big moment regardless of baseball literacy, so it's worth a little extra
    /// visual energy without re-ranking which plays the user already chose to feature (every row
    /// still gets equal size/treatment otherwise). An earlier attempt used thin radiating sparkle
    /// lines; at a subtlety that didn't fight the diamond they read as scratches, not a flourish,
    /// and rays near the card's left edge clipped past the available space entirely — a soft
    /// concentric glow reads unambiguously as "special" at a glance and can't clip since it's
    /// bounded by its own radius, not thin lines escaping outward.
    private func drawHomeRunSparkle(around diamondRect: CGRect, color: UIColor, ctx: CGContext) {
        let center = CGPoint(x: diamondRect.midX, y: diamondRect.midY)
        let haloR = diamondRect.width * 0.72
        let steps = 5
        ctx.saveGState()
        for i in stride(from: steps, to: 0, by: -1) {
            let t = CGFloat(i) / CGFloat(steps)
            let r = haloR * t
            let alpha = 0.10 * (1 - t) + 0.02
            let circle = UIBezierPath(arcCenter: center, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            color.withAlphaComponent(alpha).setFill()
            circle.fill()
        }
        ctx.restoreGState()
    }

    private func actualColumnWidth(layout: ColumnLayout) -> CGFloat {
        var w = config.nameWidth
        for inning in layout.innings { w += CGFloat(inning.subColumnCount) * config.inningWidth }
        for _ in layout.statColumns { w += config.statWidth }
        return w
    }

    /// Only labels with a real, non-blank value are returned — leagues like WPBL that don't
    /// report weather/attendance/duration/first-pitch (ScorecardData.gameInfo comes back empty)
    /// shouldn't render a row of blank fill-in-the-blank cells in a data export; that treatment
    /// is reserved for the intentional hand-fill .blank template.
    private func gatherGameInfo(scorecard: ScorecardData, labels: [String]) -> [GameInfoItem] {
        var infoMap: [String: String] = [:]
        if let date = scorecard.gameDate, !date.trimmingCharacters(in: .whitespaces).isEmpty {
            infoMap["DATE"] = date
        }
        let mapping = ["Venue": "VENUE", "Weather": "WEATHER", "Att": "ATTENDANCE", "T": "DURATION", "First pitch": "FIRST PITCH"]
        for item in scorecard.gameInfo {
            let raw = item.label.replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
            guard let value = item.value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            for (key, val) in mapping where raw.contains(key) {
                infoMap[val] = value
                break
            }
        }
        return labels.compactMap { label in
            guard let value = infoMap[label] else { return nil }
            return GameInfoItem(label: label, value: value)
        }
    }

    private func computeLayout(scorecard: ScorecardData, linescore: Linescore?, options: ScorecardExportMode = .full) -> LayoutInfo {
        let filteredInfo = gatherGameInfo(scorecard: scorecard, labels: ["DATE", "VENUE", "WEATHER", "ATTENDANCE", "DURATION", "FIRST PITCH"])

        let awayLayout = computeColumnLayout(for: scorecard, isHome: false)
        let homeLayout = computeColumnLayout(for: scorecard, isHome: true)

        let awayColWidth = actualColumnWidth(layout: awayLayout)
        let homeColWidth = actualColumnWidth(layout: homeLayout)
        let colWidth = max(awayColWidth, homeColWidth)

        let inningCount = max(scorecard.scheduledInnings, linescore?.innings?.count ?? scorecard.scheduledInnings)
        let sbTeamCol: CGFloat = 140
        let sbInningCol: CGFloat = 65
        let sbStatCol: CGFloat = 70
        let sbSepGap: CGFloat = 15
        let sbWidth: CGFloat = sbTeamCol + CGFloat(inningCount) * sbInningCol + sbSepGap + 3 * sbStatCol

        let pitcherTableWidth = config.pNameWidth + 6 * config.pStatWidth

        let scorecardTotalWidth = config.margin + colWidth + config.columnGap + colWidth + config.margin
        let scoreboardTotalWidth = sbWidth + 2 * config.margin
        let pitcherTotalWidth = config.margin + pitcherTableWidth + config.columnGap + pitcherTableWidth + config.margin

        let imageWidth = max(scorecardTotalWidth, max(scoreboardTotalWidth, pitcherTotalWidth))
        let contentWidth = imageWidth - (config.margin * 2)

        let defaultLineupRows = 9
        let hasAwayLineup = !scorecard.lineups.away.isEmpty
        let hasHomeLineup = !scorecard.lineups.home.isEmpty
        let awayRows = (options.showLineup && hasAwayLineup) ? max(scorecard.lineups.away.count, defaultLineupRows) : defaultLineupRows
        let homeRows = (options.showLineup && hasHomeLineup) ? max(scorecard.lineups.home.count, defaultLineupRows) : defaultLineupRows
        let awayHeight = CGFloat(awayRows + 1) * config.rowHeight + config.headerHeight
        let homeHeight = CGFloat(homeRows + 1) * config.rowHeight + config.headerHeight
        let scorecardSectionHeight = max(awayHeight, homeHeight)

        let defaultPitcherRows = 5
        let hasAwayPitchers = !scorecard.pitchers.away.isEmpty
        let hasHomePitchers = !scorecard.pitchers.home.isEmpty
        let awayPRows = (options.showPitchers && hasAwayPitchers) ? max(scorecard.pitchers.away.count, defaultPitcherRows) : defaultPitcherRows
        let homePRows = (options.showPitchers && hasHomePitchers) ? max(scorecard.pitchers.home.count, defaultPitcherRows) : defaultPitcherRows
        let awayPHeight = config.headerHeight + CGFloat(awayPRows) * config.pRowHeight
        let homePHeight = config.headerHeight + CGFloat(homePRows) * config.pRowHeight
        let pitcherSectionHeight = max(awayPHeight, homePHeight)

        // The .blank template always shows fill-in-the-blank umpire lines regardless of league —
        // that's its whole purpose. Everywhere else, only real umpire data earns the section;
        // WPBL has none, and blank "HP: ___" placeholders look unfinished next to an otherwise
        // fully-populated export.
        let showUmpireSection = options == .blank || !scorecard.umpires.isEmpty
        let umpireHeight: CGFloat = showUmpireSection ? 24 : 0

        var totalHeight: CGFloat = config.margin
        totalHeight += 120                    // scoreboard + game info (side by side)
        totalHeight += 10                     // gap after top section
        totalHeight += 55                     // team titles
        totalHeight += scorecardSectionHeight
        totalHeight += 8                      // gap before pitcher title
        totalHeight += 34                     // pitcher section title
        totalHeight += pitcherSectionHeight
        if showUmpireSection {
            totalHeight += 8                  // gap before umpires
            totalHeight += umpireHeight
        }
        totalHeight += config.margin

        return LayoutInfo(
            filteredInfo: filteredInfo,
            imageWidth: imageWidth,
            contentWidth: contentWidth,
            colWidth: colWidth,
            awayLayout: awayLayout,
            homeLayout: homeLayout,
            scorecardSectionHeight: scorecardSectionHeight,
            pitcherSectionHeight: pitcherSectionHeight,
            umpireHeight: umpireHeight,
            sbWidth: sbWidth,
            totalHeight: totalHeight
        )
    }

    private func drawAllContent(scorecard: ScorecardData, linescore: Linescore?, layout: LayoutInfo, imageWidth: CGFloat, options: ScorecardExportMode = .full, ctx: CGContext) {
        config.paperColor.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: imageWidth, height: layout.totalHeight))

        var currentY = config.margin

        let hasLinescore = linescore?.innings != nil && !(linescore?.innings?.isEmpty ?? true)
        let hasAwayLineup = !scorecard.lineups.away.isEmpty
        let hasHomeLineup = !scorecard.lineups.home.isEmpty
        let hasAwayPitchers = !scorecard.pitchers.away.isEmpty
        let hasHomePitchers = !scorecard.pitchers.home.isEmpty
        let hasUmpires = !scorecard.umpires.isEmpty

        let sbRect = CGRect(x: config.margin, y: currentY, width: layout.sbWidth, height: 120)
        drawScoreboard(in: sbRect, linescore: linescore, scorecard: scorecard, drawData: options.showScoreboard && hasLinescore, ctx: ctx)

        if !layout.filteredInfo.isEmpty {
            let infoX = config.margin + layout.sbWidth + 30
            let infoRect = CGRect(x: infoX, y: currentY, width: imageWidth - infoX - config.margin, height: 120)
            drawGameInfoTable(in: infoRect, info: layout.filteredInfo, drawData: options.showGameInfo, ctx: ctx)
        }
        currentY += 130

        let titleY = currentY
        let rawAwayName = scorecard.teams.away.name ?? "Away"
        let rawHomeName = scorecard.teams.home.name ?? "Home"

        let awayColor = TeamColorProvider.color(for: rawAwayName)
        let homeColor = TeamColorProvider.color(for: rawHomeName)

        NSAttributedString(string: rawAwayName.uppercased(), attributes: [.font: config.teamTitleFont, .foregroundColor: awayColor]).draw(at: CGPoint(x: config.margin, y: titleY))
        NSAttributedString(string: rawHomeName.uppercased(), attributes: [.font: config.teamTitleFont, .foregroundColor: homeColor]).draw(at: CGPoint(x: config.margin + layout.colWidth + config.columnGap, y: titleY))
        currentY += 55

        let awayRect = CGRect(x: config.margin, y: currentY, width: layout.colWidth, height: layout.scorecardSectionHeight)
        drawScorecard(in: awayRect, data: scorecard, layout: layout.awayLayout, isHome: false, drawLineup: options.showLineup && hasAwayLineup, drawResults: options.showAtBatResults, ctx: ctx)

        let homeRect = CGRect(x: config.margin + layout.colWidth + config.columnGap, y: currentY, width: layout.colWidth, height: layout.scorecardSectionHeight)
        drawScorecard(in: homeRect, data: scorecard, layout: layout.homeLayout, isHome: true, drawLineup: options.showLineup && hasHomeLineup, drawResults: options.showAtBatResults, ctx: ctx)

        currentY += layout.scorecardSectionHeight

        currentY += 8
        let pTitleY = currentY
        let pTitleAttrs: [NSAttributedString.Key: Any] = [.font: config.sectionTitleFont, .foregroundColor: config.pencilColor]
        NSAttributedString(string: "\(rawAwayName.uppercased()) PITCHERS", attributes: pTitleAttrs).draw(at: CGPoint(x: config.margin, y: pTitleY))
        NSAttributedString(string: "\(rawHomeName.uppercased()) PITCHERS", attributes: pTitleAttrs).draw(at: CGPoint(x: config.margin + layout.colWidth + config.columnGap, y: pTitleY))
        currentY += 34

        let awayPRect = CGRect(x: config.margin, y: currentY, width: layout.colWidth, height: layout.pitcherSectionHeight)
        drawPitcherTable(in: awayPRect, pitchers: scorecard.pitchers.away, drawData: options.showPitchers && hasAwayPitchers, ctx: ctx)

        let homePRect = CGRect(x: config.margin + layout.colWidth + config.columnGap, y: currentY, width: layout.colWidth, height: layout.pitcherSectionHeight)
        drawPitcherTable(in: homePRect, pitchers: scorecard.pitchers.home, drawData: options.showPitchers && hasHomePitchers, ctx: ctx)

        currentY += layout.pitcherSectionHeight

        if options == .blank || hasUmpires {
            currentY += 8
            let umpires = hasUmpires ? scorecard.umpires : ScorecardImageGenerator.defaultUmpirePositions
            drawUmpireLine(in: CGRect(x: config.margin, y: currentY, width: layout.contentWidth, height: layout.umpireHeight), umpires: umpires, drawData: options.showUmpires && hasUmpires, ctx: ctx)
        }
    }

    // MARK: - Drawing Helpers
    
    private func drawScoreboard(in rect: CGRect, linescore: Linescore?, scorecard: ScorecardData, drawData: Bool = true, ctx: CGContext) {
        let awayName = linescore?.teams?.away?.team?.name ?? scorecard.teams.away.name ?? "Away"
        let homeName = linescore?.teams?.home?.team?.name ?? scorecard.teams.home.name ?? "Home"
        let awayAbbr = teamAbbreviation(for: awayName)
        let homeAbbr = teamAbbreviation(for: homeName)
        let teamColorA = TeamColorProvider.color(for: awayName)
        let teamColorH = TeamColorProvider.color(for: homeName)
        
        let abbrFont = UIFont(name: AppFont.permanentMarker, size: 30) ?? .systemFont(ofSize: 30, weight: .bold)
        let scoreFont = UIFont(name: AppFont.permanentMarker, size: 26) ?? .systemFont(ofSize: 26, weight: .bold)
        let headerFont = UIFont(name: AppFont.ibmPlexRegular, size: 18) ?? .systemFont(ofSize: 18)
        let inningRFont = UIFont(name: AppFont.permanentMarker, size: 22) ?? .systemFont(ofSize: 22)
        
        // Table dimensions (must match sbWidth calculation)
        let teamColWidth: CGFloat = 140
        let inningColWidth: CGFloat = 65
        let statColWidth: CGFloat = 70
        let separatorGap: CGFloat = 15
        let inningCount = max(scorecard.scheduledInnings, linescore?.innings?.count ?? scorecard.scheduledInnings)
        let tableWidth = teamColWidth + CGFloat(inningCount) * inningColWidth + separatorGap + 3 * statColWidth
        let rowHeight: CGFloat = 40
        let tableHeight: CGFloat = 3 * rowHeight
        
        // Center the table in the given rect
        let tableX = rect.midX - tableWidth / 2
        let tableY = rect.midY - tableHeight / 2
        
        // Draw outer border
        ctx.setStrokeColor(config.pencilColor.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(1.5)
        UIBezierPath.pencilRoughRect(rect: CGRect(x: tableX, y: tableY, width: tableWidth, height: tableHeight), jitter: 1.5).stroke()
        
        // Draw horizontal row dividers
        ctx.setStrokeColor(config.gridColor.cgColor)
        ctx.setLineWidth(0.5)
        for row in 1..<3 {
            let y = tableY + CGFloat(row) * rowHeight
            UIBezierPath.pencilLine(from: CGPoint(x: tableX, y: y), to: CGPoint(x: tableX + tableWidth, y: y), jitter: 0.3).stroke()
        }
        
        // Draw vertical separator between innings and R/H/E
        let rheX = tableX + teamColWidth + CGFloat(inningCount) * inningColWidth + separatorGap / 2
        ctx.setStrokeColor(config.pencilColor.withAlphaComponent(0.3).cgColor)
        ctx.setLineWidth(1.0)
        UIBezierPath.pencilLine(from: CGPoint(x: rheX, y: tableY), to: CGPoint(x: rheX, y: tableY + tableHeight), jitter: 0.3).stroke()
        
        // Helper to draw centered text in a cell
        func drawCentered(_ text: String, in cellRect: CGRect, attrs: [NSAttributedString.Key: Any]) {
            let size = (text as NSString).size(withAttributes: attrs)
            NSAttributedString(string: text, attributes: attrs).draw(at: CGPoint(
                x: cellRect.midX - size.width / 2,
                y: cellRect.midY - size.height / 2
            ))
        }
        
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: config.pencilColor.withAlphaComponent(0.5)]
        // Row 0 — Header: inning numbers + R H E
        let headerRowRect = { (col: Int) -> CGRect in
            CGRect(x: tableX + teamColWidth + CGFloat(col) * inningColWidth, y: tableY, width: inningColWidth, height: rowHeight)
        }
        for i in 0..<inningCount {
            drawCentered("\(i + 1)", in: headerRowRect(i), attrs: headerAttrs)
        }
        let rheStartX = tableX + teamColWidth + CGFloat(inningCount) * inningColWidth + separatorGap
        for (i, label) in ["R", "H", "E"].enumerated() {
            drawCentered(label, in: CGRect(x: rheStartX + CGFloat(i) * statColWidth, y: tableY, width: statColWidth, height: rowHeight), attrs: headerAttrs)
        }
        
        // Row 1 — Away team
        let awayRowY = tableY + rowHeight
        drawCentered(awayAbbr, in: CGRect(x: tableX, y: awayRowY, width: teamColWidth, height: rowHeight), attrs: [.font: abbrFont, .foregroundColor: teamColorA])
        if drawData {
            for i in 0..<inningCount {
                if let inning = linescore?.innings?.first(where: { $0.num == i + 1 }) {
                    let runs = inning.away?.runs ?? 0
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: inningRFont,
                        .foregroundColor: runs > 0 ? teamColorA : config.pencilColor
                    ]
                    drawCentered("\(runs)", in: CGRect(x: tableX + teamColWidth + CGFloat(i) * inningColWidth, y: awayRowY, width: inningColWidth, height: rowHeight), attrs: attrs)
                }
            }
            let awayRuns = linescore?.teams?.away?.runs ?? 0
            let awayRHE = ["\(awayRuns)", "\(linescore?.teams?.away?.hits ?? 0)", "\(linescore?.teams?.away?.errors ?? 0)"]
            for (i, val) in awayRHE.enumerated() {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: scoreFont,
                    .foregroundColor: i == 0 && awayRuns > 0 ? teamColorA : config.pencilColor
                ]
                drawCentered(val, in: CGRect(x: rheStartX + CGFloat(i) * statColWidth, y: awayRowY, width: statColWidth, height: rowHeight), attrs: attrs)
            }
        }

        // Row 2 — Home team
        let homeRowY = tableY + 2 * rowHeight
        drawCentered(homeAbbr, in: CGRect(x: tableX, y: homeRowY, width: teamColWidth, height: rowHeight), attrs: [.font: abbrFont, .foregroundColor: teamColorH])
        if drawData {
            for i in 0..<inningCount {
                if let inning = linescore?.innings?.first(where: { $0.num == i + 1 }) {
                    let runs = inning.home?.runs ?? 0
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: inningRFont,
                        .foregroundColor: runs > 0 ? teamColorH : config.pencilColor
                    ]
                    drawCentered("\(runs)", in: CGRect(x: tableX + teamColWidth + CGFloat(i) * inningColWidth, y: homeRowY, width: inningColWidth, height: rowHeight), attrs: attrs)
                }
            }
            let homeRuns = linescore?.teams?.home?.runs ?? 0
            let homeRHE = ["\(homeRuns)", "\(linescore?.teams?.home?.hits ?? 0)", "\(linescore?.teams?.home?.errors ?? 0)"]
            for (i, val) in homeRHE.enumerated() {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: scoreFont,
                    .foregroundColor: i == 0 && homeRuns > 0 ? teamColorH : config.pencilColor
                ]
                drawCentered(val, in: CGRect(x: rheStartX + CGFloat(i) * statColWidth, y: homeRowY, width: statColWidth, height: rowHeight), attrs: attrs)
            }
        }
    }
    
    private func teamAbbreviation(for teamName: String) -> String {
        let map = [
            "Arizona Diamondbacks": "ARI", "Atlanta Braves": "ATL", "Baltimore Orioles": "BAL", "Boston Red Sox": "BOS",
            "Chicago Cubs": "CHC", "Chicago White Sox": "CWS", "Cincinnati Reds": "CIN", "Cleveland Guardians": "CLE",
            "Colorado Rockies": "COL", "Detroit Tigers": "DET", "Houston Astros": "HOU", "Kansas City Royals": "KC",
            "Los Angeles Angels": "LAA", "Los Angeles Dodgers": "LAD", "Miami Marlins": "MIA", "Milwaukee Brewers": "MIL",
            "Minnesota Twins": "MIN", "New York Mets": "NYM", "New York Yankees": "NYY", "Oakland Athletics": "OAK", "Athletics": "ATH",
            "Philadelphia Phillies": "PHI", "Pittsburgh Pirates": "PIT", "San Diego Padres": "SD", "San Francisco Giants": "SF",
            "Seattle Mariners": "SEA", "St. Louis Cardinals": "STL", "Tampa Bay Rays": "TB", "Texas Rangers": "TEX",
            "Toronto Blue Jays": "TOR", "Washington Nationals": "WSH"
        ]
        return map[teamName] ?? String(teamName.prefix(3)).uppercased()
    }
    
    private func drawScorecard(in rect: CGRect, data: ScorecardData, layout: ColumnLayout, isHome: Bool, drawLineup: Bool = true, drawResults: Bool = true, ctx: CGContext) {
        let lineup = isHome ? data.lineups.home : data.lineups.away
        let rowCount = drawLineup ? max(lineup.count, 9) + 1 : 10

        var actualWidth = config.nameWidth
        for inning in layout.innings { actualWidth += CGFloat(inning.subColumnCount) * config.inningWidth }
        for _ in layout.statColumns { actualWidth += config.statWidth }

        let totalHeight = CGFloat(rowCount) * config.rowHeight + config.headerHeight

        drawScorecardGrid(in: rect, actualWidth: actualWidth, totalHeight: totalHeight, rowCount: rowCount, layout: layout, ctx: ctx)

        let hAttrs: [NSAttributedString.Key: Any] = [.font: config.headerFont, .foregroundColor: config.pencilColor]
        let bLabel = "Batter", bSize = (bLabel as NSString).size(withAttributes: hAttrs)
        drawScorecardHeaders(in: rect, layout: layout, hAttrs: hAttrs, bSize: bSize, ctx: ctx)

        drawScorecardLineup(in: rect, data: data, layout: layout, isHome: isHome, lineup: lineup, rowCount: rowCount, drawLineup: drawLineup, drawResults: drawResults, ctx: ctx)

        drawScorecardTotals(in: rect, data: data, layout: layout, isHome: isHome, lineup: lineup, rowCount: rowCount, hAttrs: hAttrs, drawResults: drawResults, ctx: ctx)
    }

    private func drawScorecardGrid(in rect: CGRect, actualWidth: CGFloat, totalHeight: CGFloat, rowCount: Int, layout: ColumnLayout, ctx: CGContext) {
        config.gridColor.withAlphaComponent(0.05).setFill()
        ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: actualWidth, height: config.headerHeight))

        ctx.setStrokeColor(config.gridColor.cgColor); ctx.setLineWidth(0.5)

        let subDividerTop = rect.minY + config.headerHeight
        let subDividerBottom = subDividerTop + CGFloat(max(rowCount - 1, 0)) * config.rowHeight

        var currentX = rect.minX
        func drawVLine(_ x: CGFloat) { UIBezierPath.pencilLine(from: CGPoint(x: x, y: rect.minY), to: CGPoint(x: x, y: rect.minY + totalHeight), jitter: 0.5).stroke() }
        func drawSubColumnDivider(_ x: CGFloat) { UIBezierPath.pencilLine(from: CGPoint(x: x, y: subDividerTop), to: CGPoint(x: x, y: subDividerBottom), jitter: 0.5).stroke() }
        drawVLine(currentX); currentX += config.nameWidth; drawVLine(currentX)
        for inning in layout.innings {
            for sub in 1..<inning.subColumnCount {
                drawSubColumnDivider(currentX + CGFloat(sub) * config.inningWidth)
            }
            currentX += CGFloat(inning.subColumnCount) * config.inningWidth
            drawVLine(currentX)
        }
        for _ in layout.statColumns { currentX += config.statWidth; drawVLine(currentX) }

        var currentY = rect.minY
        func drawHLine(_ y: CGFloat) { UIBezierPath.pencilLine(from: CGPoint(x: rect.minX, y: y), to: CGPoint(x: rect.minX + actualWidth, y: y), jitter: 0.5).stroke() }
        drawHLine(currentY); currentY += config.headerHeight; drawHLine(currentY)
        for _ in 0..<rowCount { currentY += config.rowHeight; drawHLine(currentY) }
    }

    private func drawScorecardHeaders(in rect: CGRect, layout: ColumnLayout, hAttrs: [NSAttributedString.Key: Any], bSize: CGSize, ctx: CGContext) {
        let bLabel = "Batter"
        NSAttributedString(string: bLabel, attributes: hAttrs).draw(at: CGPoint(x: rect.minX + (config.nameWidth - bSize.width)/2, y: rect.minY + (config.headerHeight - bSize.height)/2))

        var currentX = rect.minX + config.nameWidth
        for inning in layout.innings {
            let label = "\(inning.inningNum)"
            let colW = CGFloat(inning.subColumnCount) * config.inningWidth
            let size = (label as NSString).size(withAttributes: hAttrs)
            NSAttributedString(string: label, attributes: hAttrs).draw(at: CGPoint(x: currentX + (colW - size.width)/2, y: rect.minY + (config.headerHeight - bSize.height)/2))
            currentX += colW
        }
        for stat in layout.statColumns {
            let size = (stat as NSString).size(withAttributes: hAttrs)
            NSAttributedString(string: stat, attributes: hAttrs).draw(at: CGPoint(x: currentX + (config.statWidth - size.width)/2, y: rect.minY + (config.headerHeight - bSize.height)/2))
            currentX += config.statWidth
        }
    }

    private func drawScorecardLineup(in rect: CGRect, data: ScorecardData, layout: ColumnLayout, isHome: Bool, lineup: [ScorecardBatter], rowCount: Int, drawLineup: Bool, drawResults: Bool, ctx: CGContext) {
        let hasAnyResults = !data.timeline.isEmpty
        for idx in 0..<rowCount {
            let rowY = rect.minY + config.headerHeight + CGFloat(idx) * config.rowHeight

            if drawLineup && idx < lineup.count {
                let batter = lineup[idx]
                let nameAttrs: [NSAttributedString.Key: Any] = [.font: config.nameFont, .foregroundColor: config.pencilColor]
                let posAttrs: [NSAttributedString.Key: Any] = [.font: config.posFont, .foregroundColor: config.pencilColor.withAlphaComponent(0.6)]
                NSAttributedString(string: batter.abbreviation, attributes: nameAttrs).draw(at: CGPoint(x: rect.minX + 10, y: rowY + 10))
                NSAttributedString(string: batter.position + (batter.jerseyNumber.map { " #\($0)" } ?? ""), attributes: posAttrs).draw(at: CGPoint(x: rect.minX + 10, y: rowY + 38))
            }

            var actualX = rect.minX + config.nameWidth
            let showFullGrid = !drawResults || !hasAnyResults || !drawLineup

            for col in 0..<(layout.totalColumns - layout.statColumns.count) {
                let cellRect = CGRect(x: actualX, y: rowY, width: config.inningWidth, height: config.rowHeight)

                if showFullGrid {
                    if idx < rowCount - 1 {
                        drawEmptyDiamond(in: cellRect, ctx: ctx)
                    }
                } else if idx < lineup.count {
                    let batter = lineup[idx]
                    drawAtBatEvents(in: cellRect, bId: batter.id, col: col, isHome: isHome, data: data, layout: layout, ctx: ctx)
                }
                actualX += config.inningWidth
            }

            if drawResults && drawLineup && idx < lineup.count {
                drawBatterStats(in: rect, data: data, layout: layout, isHome: isHome, batter: lineup[idx], rowY: rowY)
            }
        }
    }

    private func drawAtBatEvents(in cellRect: CGRect, bId: String, col: Int, isHome: Bool, data: ScorecardData, layout: ColumnLayout, ctx: CGContext) {
        if let (inningNum, subIndex) = layout.inningInfo(forColumn: col) {
            let allEvents = data.events(inningNum: inningNum, isHomeBatting: isHome)
            let batterEvents = allEvents.filter { $0.batterId == bId }
            if subIndex < batterEvents.count {
                let event = batterEvents[subIndex]

                drawAtBatCell(
                    in: cellRect,
                    event: event,
                    accentColor: data.teamAccentColor(isHomeTeam: isHome),
                    ctx: ctx
                )

                if event.isPitchingChange {
                    drawPitchingChangeIndicator(in: cellRect, ctx: ctx)
                }
            }
        }
    }

    private func drawCompactAtBatEvent(in cellRect: CGRect, batter: ScorecardBatter, paIndex: Int, isHome: Bool, data: ScorecardData, eventsBySlot: [Int: [Int: AtBatEvent]], ctx: CGContext) {
        guard let slot = batter.battingOrderSlot,
              let event = eventsBySlot[slot]?[paIndex],
              event.batterId == batter.id else { return }

        drawAtBatCell(
            in: cellRect,
            event: event,
            accentColor: data.teamAccentColor(isHomeTeam: isHome),
            ctx: ctx
        )

        if event.isPitchingChange {
            drawPitchingChangeIndicator(in: cellRect, ctx: ctx)
        }
    }

    private func drawPitchingChangeIndicator(in cellRect: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.setStrokeColor(config.pencilColor.cgColor)
        ctx.setLineWidth(2.5)
        ctx.setLineCap(.round)
        UIBezierPath.pencilLine(
            from: CGPoint(x: cellRect.minX - 0.5, y: cellRect.minY + 0.5),
            to: CGPoint(x: cellRect.maxX + 0.5, y: cellRect.minY + 0.5),
            jitter: 0.4
        ).stroke()
        ctx.restoreGState()
    }

    private func drawBatterStats(in rect: CGRect, data: ScorecardData, layout: ColumnLayout, isHome: Bool, batter: ScorecardBatter, rowY: CGFloat) {
        var actualStatsX = rect.minX + config.nameWidth + CGFloat(layout.totalColumns - layout.statColumns.count) * config.inningWidth
        let stats = data.calculatePlayerStats(for: batter.id, isHome: isHome)
        let nameAttrs: [NSAttributedString.Key: Any] = [.font: config.nameFont, .foregroundColor: config.pencilColor]
        for val in [stats.atBats, stats.runs, stats.hits, stats.rbi] {
            let str = "\(val)", size = (str as NSString).size(withAttributes: nameAttrs)
            NSAttributedString(string: str, attributes: nameAttrs).draw(at: CGPoint(x: actualStatsX + (config.statWidth - size.width)/2, y: rowY + (config.rowHeight - size.height)/2))
            actualStatsX += config.statWidth
        }
    }

    private func drawScorecardTotals(in rect: CGRect, data: ScorecardData, layout: ColumnLayout, isHome: Bool, lineup: [ScorecardBatter], rowCount: Int, hAttrs: [NSAttributedString.Key: Any], drawResults: Bool, ctx: CGContext) {
        let totalsY = rect.minY + config.headerHeight + CGFloat(rowCount - 1) * config.rowHeight
        let tLabel = "TOTALS", tSize = (tLabel as NSString).size(withAttributes: hAttrs)
        NSAttributedString(string: tLabel, attributes: hAttrs).draw(at: CGPoint(x: rect.minX + (config.nameWidth - tSize.width)/2, y: totalsY + (config.rowHeight - tSize.height)/2))

        if drawResults {
            var actualX = rect.minX + config.nameWidth
            for inning in layout.innings {
                drawInningTotal(in: actualX, totalsY: totalsY, inning: inning, isHome: isHome, data: data, ctx: ctx)
                actualX += CGFloat(inning.subColumnCount) * config.inningWidth
            }

            var tAB = 0, tR = 0, tH = 0, tRBI = 0
            for b in lineup { let s = data.calculatePlayerStats(for: b.id, isHome: isHome); tAB += s.atBats; tR += s.runs; tH += s.hits; tRBI += s.rbi }
            for val in [tAB, tR, tH, tRBI] {
                let str = "\(val)", sAttrs: [NSAttributedString.Key: Any] = [.font: config.nameFont, .foregroundColor: config.pencilColor]
                let size = (str as NSString).size(withAttributes: sAttrs)
                NSAttributedString(string: str, attributes: sAttrs).draw(at: CGPoint(x: actualX + (config.statWidth - size.width)/2, y: totalsY + (config.rowHeight - tSize.height)/2))
                actualX += config.statWidth
            }
        }
    }

    private func drawInningTotal(in actualX: CGFloat, totalsY: CGFloat, inning: InningColumnLayout, isHome: Bool, data: ScorecardData, ctx: CGContext) {
        let inningObj = data.innings.first { $0.num == inning.inningNum }
        let events = isHome ? (inningObj?.home ?? []) : (inningObj?.away ?? [])
        let linescoreRuns = isHome ? inningObj?.homeRuns : inningObj?.awayRuns
        let derivedRuns = events.filter { $0.bases.home }.count
        let runs = linescoreRuns ?? derivedRuns
        let columnWidth = CGFloat(inning.subColumnCount) * config.inningWidth
        drawColumnRunTotal(in: actualX, totalsY: totalsY, columnWidth: columnWidth, runs: runs, isHome: isHome, data: data)
    }

    private func drawColumnRunTotal(in actualX: CGFloat, totalsY: CGFloat, columnWidth: CGFloat, runs: Int, isHome: Bool, data: ScorecardData) {
        guard runs > 0 else { return }
        let str = "\(runs)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: config.nameFont,
            .foregroundColor: data.teamAccentColor(isHomeTeam: isHome)
        ]
        let size = (str as NSString).size(withAttributes: attrs)
        NSAttributedString(string: str, attributes: attrs).draw(
            at: CGPoint(
                x: actualX + (columnWidth - size.width) / 2,
                y: totalsY + (config.rowHeight - size.height) / 2
            )
        )
    }

    private func drawPitcherTable(in rect: CGRect, pitchers: [ScorecardPitcher], drawData: Bool = true, ctx: CGContext) {
        let tableWidth = config.pNameWidth + 6 * config.pStatWidth
        let gridRows = Int((rect.height - config.headerHeight) / config.pRowHeight)
        let totalHeight = config.headerHeight + CGFloat(gridRows) * config.pRowHeight
        ctx.setStrokeColor(config.gridColor.cgColor); ctx.setLineWidth(0.5)
        var currentX = rect.minX
        func drawVLine(_ x: CGFloat) { UIBezierPath.pencilLine(from: CGPoint(x: x, y: rect.minY), to: CGPoint(x: x, y: rect.minY + totalHeight), jitter: 0.5).stroke() }
        drawVLine(currentX); currentX += config.pNameWidth; drawVLine(currentX)
        for _ in 0..<6 { currentX += config.pStatWidth; drawVLine(currentX) }
        var currentY = rect.minY
        func drawHLine(_ y: CGFloat) { UIBezierPath.pencilLine(from: CGPoint(x: rect.minX, y: y), to: CGPoint(x: rect.minX + tableWidth, y: y), jitter: 0.5).stroke() }
        drawHLine(currentY); currentY += config.headerHeight; drawHLine(currentY)
        for _ in 0..<gridRows { currentY += config.pRowHeight; drawHLine(currentY) }
        let hAttrs: [NSAttributedString.Key: Any] = [.font: config.footerHeaderFont, .foregroundColor: config.pencilColor]
        NSAttributedString(string: "NAME", attributes: hAttrs).draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 10))
        let stats = ["IP", "H", "R", "ER", "BB", "K"]
        for (i, s) in stats.enumerated() {
            let x = rect.minX + config.pNameWidth + CGFloat(i) * config.pStatWidth, size = (s as NSString).size(withAttributes: hAttrs)
            NSAttributedString(string: s, attributes: hAttrs).draw(at: CGPoint(x: x + (config.pStatWidth - size.width)/2, y: rect.minY + 10))
        }
        if drawData {
            let nAttrs: [NSAttributedString.Key: Any] = [.font: config.footerDataFont, .foregroundColor: config.pencilColor]
            for (i, p) in pitchers.enumerated() {
                let rowY = rect.minY + config.headerHeight + CGFloat(i) * config.pRowHeight
                NSAttributedString(string: p.fullName, attributes: nAttrs).draw(at: CGPoint(x: rect.minX + 10, y: rowY + 8))
                let vals = [p.ip, "\(p.h)", "\(p.r)", "\(p.er)", "\(p.bb)", "\(p.k)"]
                for (vi, v) in vals.enumerated() {
                    let x = rect.minX + config.pNameWidth + CGFloat(vi) * config.pStatWidth, size = (v as NSString).size(withAttributes: nAttrs)
                    NSAttributedString(string: v, attributes: nAttrs).draw(at: CGPoint(x: x + (config.pStatWidth - size.width)/2, y: rowY + 10))
                }
            }
        }
    }
    
    private func drawGameInfoTable(in rect: CGRect, info: [GameInfoItem], drawData: Bool = true, maxFontSize: CGFloat = 60, ctx: CGContext) {
        let labelFont = UIFont(name: AppFont.ibmPlexSemiBold, size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: config.pencilColor.withAlphaComponent(0.45)]

        let cleanLabels: [(String, String)] = info.map { item in
            let value = (item.value ?? "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: "")
            return (item.label.uppercased(), value)
        }

        if cleanLabels.isEmpty { return }

        let colCount = cleanLabels.count
        let colWidth = rect.width / CGFloat(colCount)
        let headerHeight: CGFloat = 24
        let tableX = rect.minX
        let tableY = rect.minY
        let pad: CGFloat = 8

        ctx.setStrokeColor(config.gridColor.cgColor)
        ctx.setLineWidth(0.5)

        UIBezierPath.pencilLine(from: CGPoint(x: tableX, y: tableY), to: CGPoint(x: tableX + rect.width, y: tableY), jitter: 0.3).stroke()
        UIBezierPath.pencilLine(from: CGPoint(x: tableX, y: tableY + headerHeight), to: CGPoint(x: tableX + rect.width, y: tableY + headerHeight), jitter: 0.3).stroke()
        UIBezierPath.pencilLine(from: CGPoint(x: tableX, y: tableY + rect.height), to: CGPoint(x: tableX + rect.width, y: tableY + rect.height), jitter: 0.3).stroke()

        for col in 0...colCount {
            let x = tableX + CGFloat(col) * colWidth
            UIBezierPath.pencilLine(from: CGPoint(x: x, y: tableY), to: CGPoint(x: x, y: tableY + rect.height), jitter: 0.3).stroke()
        }

        let maxCellWidth = colWidth - pad * 2
        let valueAreaHeight = rect.height - headerHeight - pad * 2

        let parStyle = NSMutableParagraphStyle()
        parStyle.alignment = .center
        parStyle.lineBreakMode = .byWordWrapping

        func fittedSize(for text: String, maxFontSize: CGFloat) -> CGFloat {
            var sz = maxFontSize
            while sz > 12 {
                let font = UIFont(name: AppFont.patrickHand, size: sz) ?? .systemFont(ofSize: sz)
                let bounds = (text as NSString).boundingRect(
                    with: CGSize(width: maxCellWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font, .paragraphStyle: parStyle],
                    context: nil
                )
                if bounds.height <= valueAreaHeight { return sz }
                sz -= 1
            }
            return sz
        }

        // Find the base size from the longest (multi-line) values
        var baseSize: CGFloat = maxFontSize
        for pair in cleanLabels {
            let fitted = fittedSize(for: pair.1, maxFontSize: maxFontSize)
            baseSize = min(baseSize, fitted)
        }
        // Short single-word values get a small bump (20%) for visual weight balance
        let bumpedSize = min(baseSize * 1.2, maxFontSize)

        for (i, pair) in cleanLabels.enumerated() {
            let cellX = tableX + CGFloat(i) * colWidth
            let labelSize = (pair.0 as NSString).size(withAttributes: labelAttrs)
            NSAttributedString(string: pair.0, attributes: labelAttrs).draw(
                at: CGPoint(x: cellX + (colWidth - labelSize.width) / 2, y: tableY + (headerHeight - labelSize.height) / 2)
            )

            if drawData {
                let singleLineFont = UIFont(name: AppFont.patrickHand, size: baseSize) ?? .systemFont(ofSize: baseSize)
                let singleLineWidth = (pair.1 as NSString).size(withAttributes: [.font: singleLineFont]).width
                let fitsOnOneLine = singleLineWidth <= maxCellWidth
                let fontSize = fitsOnOneLine ? bumpedSize : baseSize
                let valFont = UIFont(name: AppFont.patrickHand, size: fontSize) ?? .systemFont(ofSize: fontSize)

                let valAttrs: [NSAttributedString.Key: Any] = [.font: valFont, .foregroundColor: config.pencilColor, .paragraphStyle: parStyle]
                let valSize = (pair.1 as NSString).boundingRect(
                    with: CGSize(width: maxCellWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: valAttrs,
                    context: nil
                ).size
                let drawRect = CGRect(
                    x: cellX + pad,
                    y: tableY + headerHeight + (valueAreaHeight + pad * 2 - ceil(valSize.height)) / 2,
                    width: maxCellWidth,
                    height: ceil(valSize.height)
                )
                (pair.1 as NSString).draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: valAttrs, context: nil)
            }
        }
    }

    private func drawUmpireLine(in rect: CGRect, umpires: [ScorecardUmpire], drawData: Bool = true, ctx: CGContext) {
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: config.footerBodyFont, .foregroundColor: config.pencilColor.withAlphaComponent(0.5)]

        let nameAttrs: [NSAttributedString.Key: Any] = [.font: config.footerDataFont, .foregroundColor: config.pencilColor]

        let blankWidth: CGFloat = 100

        var parts: [NSAttributedString] = []
        for ump in umpires {
            let ms = NSMutableAttributedString()
            ms.append(NSAttributedString(string: "\(ump.type): ", attributes: labelAttrs))
            if drawData {
                ms.append(NSAttributedString(string: ump.fullName, attributes: nameAttrs))
            }
            parts.append(ms)
        }

        let spacing: CGFloat = 30
        let partWidths = parts.map { drawData ? $0.size().width : $0.size().width + blankWidth }
        let totalWidth = partWidths.reduce(0, +) + CGFloat(max(parts.count - 1, 0)) * spacing
        var currentX = rect.midX - totalWidth / 2

        for (i, part) in parts.enumerated() {
            let size = part.size()
            part.draw(at: CGPoint(x: currentX, y: rect.midY - size.height / 2))
            if !drawData {
                let lineY = rect.midY + size.height / 2 - 2
                let lineStartX = currentX + size.width + 2
                ctx.setStrokeColor(config.gridColor.cgColor)
                ctx.setLineWidth(0.5)
                UIBezierPath.pencilLine(
                    from: CGPoint(x: lineStartX, y: lineY),
                    to: CGPoint(x: lineStartX + blankWidth - 4, y: lineY),
                    jitter: 0.3
                ).stroke()
            }
            currentX += partWidths[i] + spacing
        }
    }
    
    private func drawEmptyDiamond(in rect: CGRect, ctx: CGContext) {
        let dRect = squareDiamondRect(in: rect)
        let home = CGPoint(x: dRect.midX, y: dRect.maxY)
        let first = CGPoint(x: dRect.maxX, y: dRect.midY)
        let second = CGPoint(x: dRect.midX, y: dRect.minY)
        let third = CGPoint(x: dRect.minX, y: dRect.midY)

        drawDiamondShape(in: dRect, home: home, first: first, second: second, third: third, shouldUseAccent: false, diamondColor: config.pencilColor, ctx: ctx)
        
        let baseSize = max(5, min(dRect.width, dRect.height) * 0.11)
        let baseStrokeWidth = max(0.5, min(1.5, min(dRect.width, dRect.height) * 0.015))
        
        drawBaseBox(at: first, occupied: false, base: 1, diamondColor: config.pencilColor, baseSize: baseSize, baseStrokeWidth: baseStrokeWidth, ctx: ctx)
        drawBaseBox(at: second, occupied: false, base: 2, diamondColor: config.pencilColor, baseSize: baseSize, baseStrokeWidth: baseStrokeWidth, ctx: ctx)
        drawBaseBox(at: third, occupied: false, base: 3, diamondColor: config.pencilColor, baseSize: baseSize, baseStrokeWidth: baseStrokeWidth, ctx: ctx)
        drawBaseBox(at: home, occupied: false, base: 0, diamondColor: config.pencilColor, baseSize: baseSize, baseStrokeWidth: baseStrokeWidth, ctx: ctx)
    }

    private func drawAtBatCell(in rect: CGRect, event: AtBatEvent, accentColor: UIColor, resultFontSize: CGFloat? = nil, ctx: CGContext) {
        if event.result.isLive {
            ctx.saveGState()
            ctx.setAlpha(0.3)
            drawEmptyDiamond(in: rect, ctx: ctx)
            ctx.restoreGState()
            return
        }

        let dRect = squareDiamondRect(in: rect)
        let baseSize = max(5, min(dRect.width, dRect.height) * 0.11)
        let baseStrokeWidth = max(0.5, min(1.5, min(dRect.width, dRect.height) * 0.015))
        let progressLineWidth = max(1.5, min(4, min(dRect.width, dRect.height) * 0.035))
        let shouldUseAccent = event.result.isHomeRun || event.bases.home
        let diamondColor = shouldUseAccent ? accentColor : config.pencilColor
        let home = CGPoint(x: dRect.midX, y: dRect.maxY)
        let first = CGPoint(x: dRect.maxX, y: dRect.midY)
        let second = CGPoint(x: dRect.midX, y: dRect.minY)
        let third = CGPoint(x: dRect.minX, y: dRect.midY)

        drawDiamondShape(in: dRect, home: home, first: first, second: second, third: third, shouldUseAccent: shouldUseAccent, diamondColor: diamondColor, ctx: ctx)
        drawProgressPath(in: dRect, event: event, home: home, first: first, second: second, third: third, diamondColor: diamondColor, progressLineWidth: progressLineWidth, ctx: ctx)
        drawBaseBoxes(event: event, home: home, first: first, second: second, third: third, diamondColor: diamondColor, baseSize: baseSize, baseStrokeWidth: baseStrokeWidth, ctx: ctx)
        drawResultAndCounts(in: rect, dRect: dRect, event: event, diamondColor: diamondColor, baseFontSize: resultFontSize, ctx: ctx)
    }

    private func squareDiamondRect(in rect: CGRect) -> CGRect {
        let side = max(0, min(rect.width, rect.height) - 8)
        return CGRect(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2,
            width: side,
            height: side
        )
    }

    private func drawDiamondShape(in dRect: CGRect, home: CGPoint, first: CGPoint, second: CGPoint, third: CGPoint, shouldUseAccent: Bool, diamondColor: UIColor, ctx: CGContext) {
        let diamondPath = UIBezierPath()
        diamondPath.move(to: home)
        diamondPath.addLine(to: first)
        diamondPath.addLine(to: second)
        diamondPath.addLine(to: third)
        diamondPath.close()
        AppColors.diamondFill.setFill()
        diamondPath.fill()

        if shouldUseAccent {
            diamondColor.withAlphaComponent(0.06).setFill()
            diamondPath.fill()

            ctx.saveGState()
            diamondPath.addClip()
            ctx.setStrokeColor(diamondColor.withAlphaComponent(0.32).cgColor)
            ctx.setLineWidth(max(0.6, min(1.2, min(dRect.width, dRect.height) * 0.008)))
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            UIBezierPath.pencilScribble(in: dRect, jitter: 0.8, spacing: max(1.5, min(3.0, min(dRect.width, dRect.height) * 0.02))).stroke()
            ctx.restoreGState()
        }
    }

    private func drawProgressPath(in dRect: CGRect, event: AtBatEvent, home: CGPoint, first: CGPoint, second: CGPoint, third: CGPoint, diamondColor: UIColor, progressLineWidth: CGFloat, ctx: CGContext) {
        let lineToFirst = event.bases.lineToFirst ?? event.bases.first
        let lineToSecond = event.bases.lineToSecond ?? event.bases.second
        let lineToThird = event.bases.lineToThird ?? event.bases.third
        let lineToHome = event.bases.lineToHome ?? event.bases.home

        let progressPath = UIBezierPath()
        func addSegment(from: CGPoint, to: CGPoint, wasOut: Bool?) {
            if wasOut == true {
                let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
                progressPath.append(UIBezierPath.pencilLine(from: from, to: mid))
                let dx = to.x - from.x
                let dy = to.y - from.y
                let len = hypot(dx, dy)
                guard len > 0 else { return }
                let slashSize = max(4, min(dRect.width, dRect.height) * 0.09)
                let px = -dy / len * slashSize
                let py = dx / len * slashSize
                progressPath.append(UIBezierPath.pencilLine(
                    from: CGPoint(x: mid.x - px, y: mid.y - py),
                    to: CGPoint(x: mid.x + px, y: mid.y + py)
                ))
            } else {
                progressPath.append(UIBezierPath.pencilLine(from: from, to: to))
            }
        }

        if lineToFirst || event.bases.outAtFirst == true { addSegment(from: home, to: first, wasOut: event.bases.outAtFirst) }
        if lineToSecond || event.bases.outAtSecond == true { addSegment(from: first, to: second, wasOut: event.bases.outAtSecond) }
        if lineToThird || event.bases.outAtThird == true { addSegment(from: second, to: third, wasOut: event.bases.outAtThird) }
        if lineToHome || event.bases.outAtHome == true { addSegment(from: third, to: home, wasOut: event.bases.outAtHome) }
        if let annotations = event.bases.annotations {
            for annotation in annotations where annotation.kind == .caughtStealing {
                let segment: (CGPoint, CGPoint)
                switch annotation.base {
                case 2: segment = (first, second)
                case 3: segment = (second, third)
                case 4: segment = (third, home)
                default: segment = (home, first)
                }
                addSegment(from: segment.0, to: segment.1, wasOut: true)
            }
        }

        ctx.setStrokeColor(diamondColor.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(progressLineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        progressPath.stroke()
    }

    private func drawBaseBoxes(event: AtBatEvent, home: CGPoint, first: CGPoint, second: CGPoint, third: CGPoint, diamondColor: UIColor, baseSize: CGFloat, baseStrokeWidth: CGFloat, ctx: CGContext) {
        drawBaseBox(at: first, occupied: event.bases.first, base: 1, diamondColor: diamondColor, baseSize: baseSize, baseStrokeWidth: baseStrokeWidth, ctx: ctx)
        drawBaseBox(at: second, occupied: event.bases.second, base: 2, diamondColor: diamondColor, baseSize: baseSize, baseStrokeWidth: baseStrokeWidth, ctx: ctx)
        drawBaseBox(at: third, occupied: event.bases.third, base: 3, diamondColor: diamondColor, baseSize: baseSize, baseStrokeWidth: baseStrokeWidth, ctx: ctx)
        drawBaseBox(at: home, occupied: event.bases.home, base: 0, diamondColor: diamondColor, baseSize: baseSize, baseStrokeWidth: baseStrokeWidth, ctx: ctx)
    }

    private func drawBaseBox(at vertex: CGPoint, occupied: Bool, base: Int, diamondColor: UIColor, baseSize: CGFloat, baseStrokeWidth: CGFloat, ctx: CGContext) {
        let half = baseSize / 2
        let bPath = UIBezierPath()
        if base == 0 {
            let width = baseSize * 1.2
            let height = baseSize * 1.2
            let topY = vertex.y - height
            let midY = vertex.y - height / 2
            bPath.move(to: CGPoint(x: vertex.x, y: vertex.y))
            bPath.addLine(to: CGPoint(x: vertex.x - width / 2, y: midY))
            bPath.addLine(to: CGPoint(x: vertex.x - width / 2, y: topY))
            bPath.addLine(to: CGPoint(x: vertex.x + width / 2, y: topY))
            bPath.addLine(to: CGPoint(x: vertex.x + width / 2, y: midY))
            bPath.close()
        } else {
            var center = vertex
            switch base {
            case 1: center.x -= half
            case 2: center.y += half
            case 3: center.x += half
            default: break
            }
            bPath.move(to: CGPoint(x: center.x, y: center.y - half))
            bPath.addLine(to: CGPoint(x: center.x + half, y: center.y))
            bPath.addLine(to: CGPoint(x: center.x, y: center.y + half))
            bPath.addLine(to: CGPoint(x: center.x - half, y: center.y))
            bPath.close()
        }

        (occupied ? diamondColor : AppColors.baseEmpty).setFill()
        bPath.fill()
        ctx.setStrokeColor(diamondColor.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(baseStrokeWidth)
        bPath.stroke()
    }

    private func drawResultAndCounts(in rect: CGRect, dRect: CGRect, event: AtBatEvent, diamondColor: UIColor, baseFontSize: CGFloat? = nil, ctx: CGContext) {
        let res = event.result.displayText
        var font = baseFontSize.map { config.resultFont.withSize($0) } ?? config.resultFont
        let maxWidth = rect.width * 0.8
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 0.75
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byClipping

        func measuredSize(for font: UIFont) -> CGSize {
            (res as NSString).boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraphStyle],
                context: nil
            ).integral.size
        }

        var size = measuredSize(for: font)
        if size.width > maxWidth {
            let scale = max(0.5, maxWidth / size.width)
            font = font.withSize(font.pointSize * scale)
            size = measuredSize(for: font)
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: diamondColor,
            .paragraphStyle: paragraphStyle
        ]
        let drawRect = CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )

        if event.result.isCalledStrikeout {
            ctx.saveGState()
            ctx.translateBy(x: rect.midX, y: rect.midY)
            ctx.scaleBy(x: -1, y: 1)
            NSString(string: res).draw(
                with: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            ctx.restoreGState()
        } else {
            NSString(string: res).draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
        }
        // Ball/strike/out corner counts scale with the diamond, not a fixed 12pt — that was fine
        // for the ~40pt diamonds in the main scorecard grid this function was written for, but
        // reads as nearly invisible on the highlights card's much larger diamonds (up to ~280pt).
        // The 12pt floor keeps the main scorecard's small cells exactly as they were.
        let cornerFontSize = max(12, min(dRect.width, dRect.height) * 0.09)
        let cornerFont = UIFont(name: AppFont.patrickHand, size: cornerFontSize) ?? .systemFont(ofSize: cornerFontSize, weight: .medium)
        let cInset = max(2, cornerFontSize * 0.18)
        let cAttrs: [NSAttributedString.Key: Any] = [.font: cornerFont, .foregroundColor: diamondColor.withAlphaComponent(0.7)]
        if event.balls > 0 { NSAttributedString(string: "\(event.balls)B", attributes: cAttrs).draw(at: CGPoint(x: rect.minX + cInset, y: rect.minY + cInset)) }
        if event.strikes > 0 {
            let sText = "\(event.strikes)S"
            let sSize = (sText as NSString).size(withAttributes: cAttrs)
            NSAttributedString(string: sText, attributes: cAttrs).draw(at: CGPoint(x: rect.maxX - sSize.width - cInset, y: rect.minY + cInset))
        }
        if event.outs > 0 {
            let oText = "\(event.outs)"
            let oSize = (oText as NSString).size(withAttributes: cAttrs)
            NSAttributedString(string: oText, attributes: cAttrs).draw(at: CGPoint(x: rect.maxX - oSize.width - cInset, y: rect.maxY - oSize.height - cInset))
        }
        if let annotations = event.bases.annotations {
            drawAnnotations(annotations, in: rect, diamondRect: dRect, color: diamondColor)
        }
    }

    private func drawAnnotations(_ annotations: [BaseAnnotation], in rect: CGRect, diamondRect dRect: CGRect, color: UIColor) {
        let color = color.withAlphaComponent(0.85)
        // Same diamond-relative scaling as the corner ball/strike/out counts, same reasoning.
        let annotationFontSize = max(10, min(dRect.width, dRect.height) * 0.075)
        let font = UIFont(name: AppFont.patrickHand, size: annotationFontSize) ?? .systemFont(ofSize: annotationFontSize, weight: .medium)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        var stackedCounts: [String: Int] = [:]
        for annotation in annotations {
            let placement = annotationPlacement(for: annotation, in: rect, diamondRect: dRect)
            let size = measuredAnnotationSize(for: annotation.label, attributes: attrs, font: font)
            let stackIndex = stackedCounts[placement.key, default: 0]
            stackedCounts[placement.key] = stackIndex + 1

            let stackOffset: CGFloat
            if stackIndex == 0 {
                stackOffset = 0
            } else {
                let step = (stackIndex + 1) / 2
                let preferredSign = placement.stackDirection == .down ? 1 : -1
                let sign = stackIndex.isMultiple(of: 2) ? -preferredSign : preferredSign
                stackOffset = CGFloat(step * sign) * (size.height + 1)
            }
            let origin = CGPoint(
                x: placement.anchor.x - size.width * placement.alignX,
                y: placement.anchor.y - size.height * placement.alignY + stackOffset
            )

            let drawRect = CGRect(
                x: max(rect.minX + 1, min(origin.x, rect.maxX - size.width - 1)),
                y: max(rect.minY + 1, min(origin.y, rect.maxY - size.height - 1)),
                width: size.width,
                height: size.height
            )

            NSString(string: annotation.label).draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
        }
    }

    private struct AnnotationPlacement {
        enum StackDirection {
            case down
            case up
        }

        let anchor: CGPoint
        let alignX: CGFloat
        let alignY: CGFloat
        let stackDirection: StackDirection
        let key: String
    }

    private func vertex(for base: Int, in dRect: CGRect) -> CGPoint {
        switch base {
        case 1: return CGPoint(x: dRect.maxX, y: dRect.midY)
        case 2: return CGPoint(x: dRect.midX, y: dRect.minY)
        case 3: return CGPoint(x: dRect.minX, y: dRect.midY)
        default: return CGPoint(x: dRect.midX, y: dRect.maxY)
        }
    }

    private func basePath(to base: Int, in dRect: CGRect) -> (CGPoint, CGPoint) {
        switch base {
        case 2: return (CGPoint(x: dRect.maxX, y: dRect.midY), CGPoint(x: dRect.midX, y: dRect.minY))
        case 3: return (CGPoint(x: dRect.midX, y: dRect.minY), CGPoint(x: dRect.minX, y: dRect.midY))
        case 4: return (CGPoint(x: dRect.minX, y: dRect.midY), CGPoint(x: dRect.midX, y: dRect.maxY))
        default: return (CGPoint(x: dRect.midX, y: dRect.maxY), CGPoint(x: dRect.maxX, y: dRect.midY))
        }
    }

    private func measuredAnnotationSize(for label: String, attributes attrs: [NSAttributedString.Key: Any], font: UIFont) -> CGSize {
        let maxWidth: CGFloat = label.contains("\n") ? 34 : 42
        let boundingSize = (label as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        ).integral.size
        return CGSize(
            width: min(maxWidth, max(ceil(boundingSize.width), 1)),
            height: max(ceil(boundingSize.height), font.lineHeight)
        )
    }

    private func annotationPlacement(for annotation: BaseAnnotation, in rect: CGRect, diamondRect dRect: CGRect) -> AnnotationPlacement {
        if annotation.kind == .caughtStealing {
            let (fromPt, toPt) = basePath(to: annotation.base, in: dRect)
            let mid = CGPoint(x: (fromPt.x + toPt.x) / 2, y: (fromPt.y + toPt.y) / 2)
            if mid.y < rect.midY {
                return AnnotationPlacement(
                    anchor: CGPoint(x: mid.x, y: mid.y - 4),
                    alignX: 0.5,
                    alignY: 1,
                    stackDirection: .up,
                    key: "cs-\(annotation.base)-up"
                )
            } else {
                return AnnotationPlacement(
                    anchor: CGPoint(x: mid.x, y: mid.y + 4),
                    alignX: 0.5,
                    alignY: 0,
                    stackDirection: .down,
                    key: "cs-\(annotation.base)-down"
                )
            }
        }

        let v = vertex(for: annotation.base, in: dRect)
        switch annotation.base {
        case 1, 3:
            return AnnotationPlacement(
                anchor: CGPoint(x: v.x, y: v.y + 4),
                alignX: 0.5,
                alignY: 0,
                stackDirection: .down,
                key: "base-\(annotation.base)-down"
            )
        default:
            return AnnotationPlacement(
                anchor: CGPoint(x: v.x - 4, y: v.y),
                alignX: 1,
                alignY: 0.5,
                stackDirection: annotation.base == 2 ? .down : .up,
                key: "base-\(annotation.base)-side"
            )
        }
    }
    
    private func computeColumnLayout(for data: ScorecardData, isHome: Bool) -> ColumnLayout {
        let lineup = isHome ? data.lineups.home : data.lineups.away
        let inningCount = max(data.innings.count, data.scheduledInnings)
        var layouts: [InningColumnLayout] = [], runningColumn = 0
        for i in 1...inningCount {
            let events = data.events(inningNum: i, isHomeBatting: isHome)
            var maxABs = 1
            for batter in lineup { maxABs = max(maxABs, events.filter { $0.batterId == batter.id }.count) }
            layouts.append(InningColumnLayout(inningNum: i, subColumnCount: maxABs, startColumn: runningColumn))
            runningColumn += maxABs
        }
        return ColumnLayout(innings: layouts)
    }
}
