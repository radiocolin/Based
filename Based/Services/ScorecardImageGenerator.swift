import UIKit

/// A dedicated service to generate a high-quality, landscape scorecard graphic.
/// Draws directly into a CGContext for maximum precision and to bypass UIKit off-screen rendering limitations.
enum ScorecardExportMode: Int, CaseIterable {
    case blank = 0
    case summary = 1
    case full = 2

    var title: String {
        switch self {
        case .blank: return "Blank Scorecard"
        case .summary: return "Game Summary"
        case .full: return "Full Scorecard"
        }
    }

    var subtitle: String {
        switch self {
        case .blank: return "Structure and labels only — fill in by hand"
        case .summary: return "Score, lineups, game info, and umpires"
        case .full: return "Complete scorecard with play-by-play"
        }
    }

    var showScoreboard: Bool { rawValue >= Self.summary.rawValue }
    var showGameInfo: Bool { rawValue >= Self.summary.rawValue }
    var showLineup: Bool { rawValue >= Self.summary.rawValue }
    var showAtBatResults: Bool { rawValue >= Self.full.rawValue }
    var showPitchers: Bool { rawValue >= Self.full.rawValue }
    var showUmpires: Bool { rawValue >= Self.summary.rawValue }
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
        
        let teamTitleFont = UIFont(name: "PermanentMarker-Regular", size: 48) ?? .systemFont(ofSize: 48, weight: .bold)
        let headerFont = UIFont(name: "IBMPlexSansCond-Bold", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        let nameFont = UIFont(name: "PermanentMarker-Regular", size: 16) ?? .systemFont(ofSize: 16)
        let posFont = UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14)
        let resultFont = UIFont(name: "PermanentMarker-Regular", size: 18) ?? .systemFont(ofSize: 18)
        let legibilityFont = UIFont(name: "PatrickHand-Regular", size: 12) ?? .systemFont(ofSize: 12)

        let sectionTitleFont = UIFont(name: "IBMPlexSansCond-Bold", size: 28) ?? .systemFont(ofSize: 28, weight: .bold)
        let footerHeaderFont = UIFont(name: "IBMPlexSansCond-Bold", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
        let footerBodyFont = UIFont(name: "IBMPlexSansCond-Regular", size: 16) ?? .systemFont(ofSize: 16)
        let footerDataFont = UIFont(name: "PermanentMarker-Regular", size: 16) ?? .systemFont(ofSize: 16)
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

    func generate(scorecard: ScorecardData, linescore: Linescore?, options: ScorecardExportMode = .full) async -> UIImage {
        let pdfData = await generatePDF(scorecard: scorecard, linescore: linescore, options: options)
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
            let ctx = context.cgContext
            self.config.paperColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.translateBy(x: 0, y: size.height)
            ctx.scaleBy(x: scale, y: -scale)
            ctx.drawPDFPage(page)
        }
    }

    func generatePDF(scorecard: ScorecardData, linescore: Linescore?, options: ScorecardExportMode = .full) async -> Data {
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

    private func actualColumnWidth(layout: ColumnLayout) -> CGFloat {
        var w = config.nameWidth
        for inning in layout.innings { w += CGFloat(inning.subColumnCount) * config.inningWidth }
        for _ in layout.statColumns { w += config.statWidth }
        return w
    }

    private func computeLayout(scorecard: ScorecardData, linescore: Linescore?, options: ScorecardExportMode = .full) -> LayoutInfo {
        let importantLabels = ["Venue", "Weather", "Att", "T", "First pitch"]
        var filteredInfo = scorecard.gameInfo.filter { item in
            importantLabels.contains(where: { item.label.contains($0) })
        }
        if let date = scorecard.gameDate {
            filteredInfo.insert(GameInfoItem(label: "Date", value: date), at: 0)
        }

        let awayLayout = computeColumnLayout(for: scorecard, isHome: false)
        let homeLayout = computeColumnLayout(for: scorecard, isHome: true)

        let awayColWidth = actualColumnWidth(layout: awayLayout)
        let homeColWidth = actualColumnWidth(layout: homeLayout)
        let colWidth = max(awayColWidth, homeColWidth)

        let inningCount = max(9, linescore?.innings?.count ?? 9)
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

        let umpireHeight: CGFloat = 24

        var totalHeight: CGFloat = config.margin
        totalHeight += 120                    // scoreboard + game info (side by side)
        totalHeight += 10                     // gap after top section
        totalHeight += 55                     // team titles
        totalHeight += scorecardSectionHeight
        totalHeight += 8                      // gap before pitcher title
        totalHeight += 34                     // pitcher section title
        totalHeight += pitcherSectionHeight
        totalHeight += 8                      // gap before umpires
        totalHeight += umpireHeight
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

        currentY += 8
        let umpires = hasUmpires ? scorecard.umpires : ScorecardImageGenerator.defaultUmpirePositions
        drawUmpireLine(in: CGRect(x: config.margin, y: currentY, width: layout.contentWidth, height: layout.umpireHeight), umpires: umpires, drawData: options.showUmpires && hasUmpires, ctx: ctx)
    }

    // MARK: - Drawing Helpers
    
    private func drawScoreboard(in rect: CGRect, linescore: Linescore?, scorecard: ScorecardData, drawData: Bool = true, ctx: CGContext) {
        let awayName = linescore?.teams?.away?.team?.name ?? scorecard.teams.away.name ?? "Away"
        let homeName = linescore?.teams?.home?.team?.name ?? scorecard.teams.home.name ?? "Home"
        let awayAbbr = teamAbbreviation(for: awayName)
        let homeAbbr = teamAbbreviation(for: homeName)
        let teamColorA = TeamColorProvider.color(for: awayName)
        let teamColorH = TeamColorProvider.color(for: homeName)
        
        let abbrFont = UIFont(name: "PermanentMarker-Regular", size: 30) ?? .systemFont(ofSize: 30, weight: .bold)
        let scoreFont = UIFont(name: "PermanentMarker-Regular", size: 26) ?? .systemFont(ofSize: 26, weight: .bold)
        let headerFont = UIFont(name: "IBMPlexSansCond-Regular", size: 18) ?? .systemFont(ofSize: 18)
        let inningRFont = UIFont(name: "PermanentMarker-Regular", size: 22) ?? .systemFont(ofSize: 22)
        
        // Table dimensions (must match sbWidth calculation)
        let teamColWidth: CGFloat = 140
        let inningColWidth: CGFloat = 65
        let statColWidth: CGFloat = 70
        let separatorGap: CGFloat = 15
        let inningCount = max(9, linescore?.innings?.count ?? 9)
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
            "Minnesota Twins": "MIN", "New York Mets": "NYM", "New York Yankees": "NYY", "Oakland Athletics": "OAK",
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
        
        config.gridColor.withAlphaComponent(0.05).setFill()
        ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: actualWidth, height: config.headerHeight))
        
        ctx.setStrokeColor(config.gridColor.cgColor); ctx.setLineWidth(0.5)
        let totalHeight = CGFloat(rowCount) * config.rowHeight + config.headerHeight
        
        var currentX = rect.minX
        func drawVLine(_ x: CGFloat) { UIBezierPath.pencilLine(from: CGPoint(x: x, y: rect.minY), to: CGPoint(x: x, y: rect.minY + totalHeight), jitter: 0.5).stroke() }
        drawVLine(currentX); currentX += config.nameWidth; drawVLine(currentX)
        for inning in layout.innings { currentX += CGFloat(inning.subColumnCount) * config.inningWidth; drawVLine(currentX) }
        for _ in layout.statColumns { currentX += config.statWidth; drawVLine(currentX) }
        
        var currentY = rect.minY
        func drawHLine(_ y: CGFloat) { UIBezierPath.pencilLine(from: CGPoint(x: rect.minX, y: y), to: CGPoint(x: rect.minX + actualWidth, y: y), jitter: 0.5).stroke() }
        drawHLine(currentY); currentY += config.headerHeight; drawHLine(currentY)
        for _ in 0..<rowCount { currentY += config.rowHeight; drawHLine(currentY) }
        
        let hAttrs: [NSAttributedString.Key: Any] = [.font: config.headerFont, .foregroundColor: config.pencilColor]
        let bLabel = "BATTER", bSize = (bLabel as NSString).size(withAttributes: hAttrs)
        NSAttributedString(string: bLabel, attributes: hAttrs).draw(at: CGPoint(x: rect.minX + (config.nameWidth - bSize.width)/2, y: rect.minY + (config.headerHeight - bSize.height)/2))
        
        currentX = rect.minX + config.nameWidth
        for inning in layout.innings {
            let label = "\(inning.inningNum)", colW = CGFloat(inning.subColumnCount) * config.inningWidth
            let size = (label as NSString).size(withAttributes: hAttrs)
            NSAttributedString(string: label, attributes: hAttrs).draw(at: CGPoint(x: currentX + (colW - size.width)/2, y: rect.minY + (config.headerHeight - bSize.height)/2))
            currentX += colW
        }
        for stat in layout.statColumns {
            let size = (stat as NSString).size(withAttributes: hAttrs)
            NSAttributedString(string: stat, attributes: hAttrs).draw(at: CGPoint(x: currentX + (config.statWidth - size.width)/2, y: rect.minY + (config.headerHeight - bSize.height)/2))
            currentX += config.statWidth
        }
        
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
                        // In full grid mode (blank template or results disabled), fill every batting cell
                        drawEmptyDiamond(in: cellRect, ctx: ctx)
                    }
                } else if let bId = (idx < lineup.count ? lineup[idx].id : nil) {
                    // In sparse grid mode (live game with results), only draw where events exist
                    if let (inningNum, subIndex) = layout.inningInfo(forColumn: col) {
                        let inningObj = data.innings.first { $0.num == inningNum }
                        let allEvents = (isHome ? inningObj?.home : inningObj?.away) ?? []
                        let batterEvents = allEvents.filter { $0.batterId == bId }
                        if subIndex < batterEvents.count {
                            let event = batterEvents[subIndex]

                            var isPitchingChange = false
                            var batterOccurrence = 0
                            for (i, e) in allEvents.enumerated() {
                                if e.batterId == bId {
                                    if batterOccurrence == subIndex {
                                        if i > 0 && e.pitcherId != allEvents[i - 1].pitcherId {
                                            isPitchingChange = true
                                        }
                                        break
                                    }
                                    batterOccurrence += 1
                                }
                            }

                            if isPitchingChange {
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

                            drawAtBatCell(
                                in: cellRect,
                                event: event,
                                accentColor: data.teamAccentColor(isHomeTeam: isHome),
                                ctx: ctx
                            )
                        }
                    }
                }
                actualX += config.inningWidth
            }
            
            if drawResults && drawLineup && idx < lineup.count {
                let batter = lineup[idx]
                var actualStatsX = rect.minX + config.nameWidth + CGFloat(layout.totalColumns - layout.statColumns.count) * config.inningWidth
                let stats = data.calculatePlayerStats(for: batter.id, isHome: isHome)
                let nameAttrs: [NSAttributedString.Key: Any] = [.font: config.nameFont, .foregroundColor: config.pencilColor]
                for val in [stats.atBats, stats.runs, stats.hits, stats.rbi] {
                    let str = "\(val)", size = (str as NSString).size(withAttributes: nameAttrs)
                    NSAttributedString(string: str, attributes: nameAttrs).draw(at: CGPoint(x: actualStatsX + (config.statWidth - size.width)/2, y: rowY + (config.rowHeight - size.height)/2))
                    actualStatsX += config.statWidth
                }
            }
        }


        let totalsY = rect.minY + config.headerHeight + CGFloat(rowCount - 1) * config.rowHeight
        let tLabel = "TOTALS", tSize = (tLabel as NSString).size(withAttributes: hAttrs)
        NSAttributedString(string: tLabel, attributes: hAttrs).draw(at: CGPoint(x: rect.minX + (config.nameWidth - tSize.width)/2, y: totalsY + (config.rowHeight - tSize.height)/2))

        if drawResults {
            var actualX = rect.minX + config.nameWidth
            for inning in layout.innings {
                let inningObj = data.innings.first { $0.num == inning.inningNum }
                let events = isHome ? (inningObj?.home ?? []) : (inningObj?.away ?? [])
                let linescoreRuns = isHome ? inningObj?.homeRuns : inningObj?.awayRuns
                let derivedRuns = events.filter { $0.bases.home }.count
                let runs = linescoreRuns ?? derivedRuns

                if runs > 0 {
                    let str = "\(runs)"
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: config.nameFont,
                        .foregroundColor: data.teamAccentColor(isHomeTeam: isHome)
                    ]
                    let size = (str as NSString).size(withAttributes: attrs)
                    let inningWidth = CGFloat(inning.subColumnCount) * config.inningWidth
                    NSAttributedString(string: str, attributes: attrs).draw(
                        at: CGPoint(
                            x: actualX + (inningWidth - size.width) / 2,
                            y: totalsY + (config.rowHeight - size.height) / 2
                        )
                    )
                }

                actualX += CGFloat(inning.subColumnCount) * config.inningWidth
            }

            var tAB = 0, tR = 0, tH = 0, tRBI = 0
            for b in lineup { let s = data.calculatePlayerStats(for: b.id, isHome: isHome); tAB += s.atBats; tR += s.runs; tH += s.hits; tRBI += s.rbi }
            for val in [tAB, tR, tH, tRBI] {
                let str = "\(val)", sAttrs: [NSAttributedString.Key: Any] = [.font: config.nameFont, .foregroundColor: config.pencilColor]
                let size = (str as NSString).size(withAttributes: sAttrs)
                NSAttributedString(string: str, attributes: sAttrs).draw(at: CGPoint(x: actualX + (config.statWidth - size.width)/2, y: totalsY + (config.rowHeight - size.height)/2))
                actualX += config.statWidth
            }
        }
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
    
    private func drawGameInfoTable(in rect: CGRect, info: [GameInfoItem], drawData: Bool = true, ctx: CGContext) {
        let labelFont = UIFont(name: "IBMPlexSansCond-SemiBold", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: config.pencilColor.withAlphaComponent(0.45)]

        let cleanLabels: [(String, String)] = {
            let labelMap = ["T": "Duration", "Att": "Attendance"]
            return info.compactMap { item in
                let raw = item.label.replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
                let display = labelMap[raw] ?? raw
                let value = (item.value ?? "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: "")
                guard !value.isEmpty else { return nil }
                return (display.uppercased(), value)
            }
        }()

        guard !cleanLabels.isEmpty else { return }

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
                let font = UIFont(name: "PatrickHand-Regular", size: sz) ?? .systemFont(ofSize: sz)
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
        var baseSize: CGFloat = 60
        for pair in cleanLabels {
            let fitted = fittedSize(for: pair.1, maxFontSize: 60)
            baseSize = min(baseSize, fitted)
        }
        // Short single-word values get a small bump (20%) for visual weight balance
        let bumpedSize = min(baseSize * 1.2, 60)

        for (i, pair) in cleanLabels.enumerated() {
            let cellX = tableX + CGFloat(i) * colWidth
            let labelSize = (pair.0 as NSString).size(withAttributes: labelAttrs)
            NSAttributedString(string: pair.0, attributes: labelAttrs).draw(
                at: CGPoint(x: cellX + (colWidth - labelSize.width) / 2, y: tableY + (headerHeight - labelSize.height) / 2)
            )

            if drawData {
                let singleLineFont = UIFont(name: "PatrickHand-Regular", size: baseSize) ?? .systemFont(ofSize: baseSize)
                let singleLineWidth = (pair.1 as NSString).size(withAttributes: [.font: singleLineFont]).width
                let fitsOnOneLine = singleLineWidth <= maxCellWidth
                let fontSize = fitsOnOneLine ? bumpedSize : baseSize
                let valFont = UIFont(name: "PatrickHand-Regular", size: fontSize) ?? .systemFont(ofSize: fontSize)

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
        let dRect = CGRect(
            x: rect.minX + 2,
            y: rect.minY + 4,
            width: rect.width - 4,
            height: rect.height - 8
        )
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

    private func drawAtBatCell(in rect: CGRect, event: AtBatEvent, accentColor: UIColor, ctx: CGContext) {
        let dRect = CGRect(
            x: rect.minX + 2,
            y: rect.minY + 4,
            width: rect.width - 4,
            height: rect.height - 8
        )
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
        drawResultAndCounts(in: rect, dRect: dRect, event: event, diamondColor: diamondColor, ctx: ctx)
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

    private func drawResultAndCounts(in rect: CGRect, dRect: CGRect, event: AtBatEvent, diamondColor: UIColor, ctx: CGContext) {
        let res = event.result.displayText
        var font = config.resultFont
        let maxWidth = rect.width * 0.8
        var size = (res as NSString).size(withAttributes: [.font: font])
        if size.width > maxWidth {
            let scale = max(0.5, maxWidth / size.width)
            font = font.withSize(font.pointSize * scale)
            size = (res as NSString).size(withAttributes: [.font: font])
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: diamondColor]
        if event.result.isCalledStrikeout {
            ctx.saveGState(); ctx.translateBy(x: rect.midX, y: rect.midY); ctx.scaleBy(x: -1, y: 1); NSAttributedString(string: res, attributes: attrs).draw(at: CGPoint(x: -size.width/2, y: -size.height/2)); ctx.restoreGState()
        } else { NSAttributedString(string: res, attributes: attrs).draw(at: CGPoint(x: rect.midX - size.width/2, y: rect.midY - size.height/2)) }
        let cAttrs: [NSAttributedString.Key: Any] = [.font: config.legibilityFont, .foregroundColor: diamondColor.withAlphaComponent(0.7)]
        if event.balls > 0 { NSAttributedString(string: "\(event.balls)B", attributes: cAttrs).draw(at: CGPoint(x: rect.minX + 2, y: rect.minY + 2)) }
        if event.strikes > 0 {
            let sText = "\(event.strikes)S"
            let sSize = (sText as NSString).size(withAttributes: cAttrs)
            NSAttributedString(string: sText, attributes: cAttrs).draw(at: CGPoint(x: rect.maxX - sSize.width - 2, y: rect.minY + 2))
        }
        if event.outs > 0 {
            let oText = "\(event.outs)"
            let oSize = (oText as NSString).size(withAttributes: cAttrs)
            NSAttributedString(string: oText, attributes: cAttrs).draw(at: CGPoint(x: rect.maxX - oSize.width - 2, y: rect.maxY - oSize.height - 2))
        }
        if let annotations = event.bases.annotations {
            drawAnnotations(annotations, in: rect, diamondRect: dRect, color: diamondColor)
        }
    }

    private func drawAnnotations(_ annotations: [BaseAnnotation], in rect: CGRect, diamondRect dRect: CGRect, color: UIColor) {
        let color = color.withAlphaComponent(0.85)
        let font = UIFont(name: "PatrickHand-Regular", size: 10) ?? .systemFont(ofSize: 10, weight: .medium)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        struct AnnotationPlacement {
            enum StackDirection {
                case down
                case up
            }

            let annotation: BaseAnnotation
            let anchor: CGPoint
            let alignX: CGFloat
            let alignY: CGFloat
            let stackDirection: StackDirection
            let key: String
        }

        func vertex(for base: Int) -> CGPoint {
            switch base {
            case 1: return CGPoint(x: dRect.maxX, y: dRect.midY)
            case 2: return CGPoint(x: dRect.midX, y: dRect.minY)
            case 3: return CGPoint(x: dRect.minX, y: dRect.midY)
            default: return CGPoint(x: dRect.midX, y: dRect.maxY)
            }
        }

        func basePath(to base: Int) -> (CGPoint, CGPoint) {
            switch base {
            case 2: return (CGPoint(x: dRect.maxX, y: dRect.midY), CGPoint(x: dRect.midX, y: dRect.minY))
            case 3: return (CGPoint(x: dRect.midX, y: dRect.minY), CGPoint(x: dRect.minX, y: dRect.midY))
            case 4: return (CGPoint(x: dRect.minX, y: dRect.midY), CGPoint(x: dRect.midX, y: dRect.maxY))
            default: return (CGPoint(x: dRect.midX, y: dRect.maxY), CGPoint(x: dRect.maxX, y: dRect.midY))
            }
        }

        func measuredSize(for label: String) -> CGSize {
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

        func placement(for annotation: BaseAnnotation) -> AnnotationPlacement {
            if annotation.kind == .caughtStealing {
                let (fromPt, toPt) = basePath(to: annotation.base)
                let mid = CGPoint(x: (fromPt.x + toPt.x) / 2, y: (fromPt.y + toPt.y) / 2)
                if mid.y < rect.midY {
                    return AnnotationPlacement(
                        annotation: annotation,
                        anchor: CGPoint(x: mid.x, y: mid.y - 4),
                        alignX: 0.5,
                        alignY: 1,
                        stackDirection: .up,
                        key: "cs-\(annotation.base)-up"
                    )
                } else {
                    return AnnotationPlacement(
                        annotation: annotation,
                        anchor: CGPoint(x: mid.x, y: mid.y + 4),
                        alignX: 0.5,
                        alignY: 0,
                        stackDirection: .down,
                        key: "cs-\(annotation.base)-down"
                    )
                }
            }

            let v = vertex(for: annotation.base)
            switch annotation.base {
            case 1, 3:
                return AnnotationPlacement(
                    annotation: annotation,
                    anchor: CGPoint(x: v.x, y: v.y + 4),
                    alignX: 0.5,
                    alignY: 0,
                    stackDirection: .down,
                    key: "base-\(annotation.base)-down"
                )
            default:
                return AnnotationPlacement(
                    annotation: annotation,
                    anchor: CGPoint(x: v.x - 4, y: v.y),
                    alignX: 1,
                    alignY: 0.5,
                    stackDirection: annotation.base == 2 ? .down : .up,
                    key: "base-\(annotation.base)-side"
                )
            }
        }

        var stackedCounts: [String: Int] = [:]
        for placement in annotations.map(placement(for:)) {
            let size = measuredSize(for: placement.annotation.label)
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

            NSString(string: placement.annotation.label).draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
        }
    }
    
    private func computeColumnLayout(for data: ScorecardData, isHome: Bool) -> ColumnLayout {
        let lineup = isHome ? data.lineups.home : data.lineups.away
        let inningCount = max(data.innings.count, 9)
        var layouts: [InningColumnLayout] = [], runningColumn = 0
        for i in 1...inningCount {
            let inningObj = data.innings.first { $0.num == i }
            let events = isHome ? (inningObj?.home ?? []) : (inningObj?.away ?? [])
            var maxABs = 1
            for batter in lineup { maxABs = max(maxABs, events.filter { $0.batterId == batter.id }.count) }
            layouts.append(InningColumnLayout(inningNum: i, subColumnCount: maxABs, startColumn: runningColumn))
            runningColumn += maxABs
        }
        return ColumnLayout(innings: layouts)
    }
}
