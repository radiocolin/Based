import UIKit

/// A dedicated service to generate a high-quality, landscape scorecard graphic.
/// Draws directly into a CGContext for maximum precision and to bypass UIKit off-screen rendering limitations.
final class ScorecardImageGenerator {
    
    struct Config {
        let imageWidth: CGFloat = 2400
        let margin: CGFloat = 80
        let columnGap: CGFloat = 100
        let rowHeight: CGFloat = 70
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
        let headerFont = UIFont(name: "PatrickHand-Regular", size: 24) ?? .systemFont(ofSize: 24, weight: .bold)
        let nameFont = UIFont(name: "PermanentMarker-Regular", size: 20) ?? .systemFont(ofSize: 20)
        let posFont = UIFont(name: "PatrickHand-Regular", size: 16) ?? .systemFont(ofSize: 16)
        let resultFont = UIFont(name: "PermanentMarker-Regular", size: 24) ?? .systemFont(ofSize: 24)
        let legibilityFont = UIFont(name: "PatrickHand-Regular", size: 14) ?? .systemFont(ofSize: 14)
        
        let sectionTitleFont = UIFont(name: "PatrickHand-Regular", size: 32) ?? .systemFont(ofSize: 32, weight: .bold)
        let footerHeaderFont = UIFont(name: "PatrickHand-Regular", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        let footerBodyFont = UIFont(name: "PatrickHand-Regular", size: 20) ?? .systemFont(ofSize: 20)
        let footerDataFont = UIFont(name: "PermanentMarker-Regular", size: 18) ?? .systemFont(ofSize: 18)
    }
    
    private let config = Config()
    
    func generate(scorecard: ScorecardData, linescore: Linescore?) async -> UIImage {
        // 1. Filter and Prepare Info
        let importantLabels = ["Venue", "Weather", "Att", "T", "First pitch"]
        let filteredInfo = scorecard.gameInfo.filter { item in
            importantLabels.contains(where: { item.label.contains($0) })
        }
        
        // 2. Pre-calculate layout
        let contentWidth = config.imageWidth - (config.margin * 2)
        let colWidth = (contentWidth - config.columnGap) / 2
        
        let awayLayout = computeColumnLayout(for: scorecard, isHome: false)
        let homeLayout = computeColumnLayout(for: scorecard, isHome: true)
        
        let awayHeight = CGFloat(scorecard.lineups.away.count + 1) * config.rowHeight + config.headerHeight
        let homeHeight = CGFloat(scorecard.lineups.home.count + 1) * config.rowHeight + config.headerHeight
        let scorecardSectionHeight = max(awayHeight, homeHeight)
        
        let awayPHeight = config.headerHeight + CGFloat(scorecard.pitchers.away.count) * config.pRowHeight
        let homePHeight = config.headerHeight + CGFloat(scorecard.pitchers.home.count) * config.pRowHeight
        let pitcherSectionHeight = max(awayPHeight, homePHeight)
        
        let gameInfoHeight: CGFloat = filteredInfo.isEmpty ? 0 : 100
        
        let inningCount = max(9, linescore?.innings?.count ?? 9)
        let sbTeamCol: CGFloat = 140
        let sbInningCol: CGFloat = 65
        let sbStatCol: CGFloat = 70
        let sbSepGap: CGFloat = 15
        let sbWidth: CGFloat = sbTeamCol + CGFloat(inningCount) * sbInningCol + sbSepGap + 3 * sbStatCol
        
        var totalHeight: CGFloat = config.margin
        totalHeight += 120 // Scoreboard
        totalHeight += 80 // Spacing
        totalHeight += 80 // Team Titles
        totalHeight += scorecardSectionHeight
        totalHeight += 80 // Spacing
        totalHeight += 50 // "PITCHERS" titles
        totalHeight += pitcherSectionHeight
        totalHeight += 80 // Spacing
        totalHeight += gameInfoHeight
        totalHeight += config.margin // Bottom margin
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: config.imageWidth, height: totalHeight))
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Background
            config.paperColor.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: config.imageWidth, height: totalHeight))
            
            var currentY = config.margin
            
            // 2. Scoreboard (Top Centered)
            let sbRect = CGRect(x: (config.imageWidth - sbWidth) / 2, y: currentY, width: sbWidth, height: 120)
            drawScoreboard(in: sbRect, linescore: linescore, scorecard: scorecard, ctx: ctx)
            currentY += 200
            
            // 3. Team Titles (Actual names in color, PermanentMarker)
            let titleY = currentY
            let rawAwayName = scorecard.teams.away.name ?? "Away"
            let rawHomeName = scorecard.teams.home.name ?? "Home"
            
            let awayColor = TeamColorProvider.color(for: rawAwayName)
            let homeColor = TeamColorProvider.color(for: rawHomeName)
            
            NSAttributedString(string: rawAwayName.uppercased(), attributes: [.font: config.teamTitleFont, .foregroundColor: awayColor]).draw(at: CGPoint(x: config.margin, y: titleY))
            NSAttributedString(string: rawHomeName.uppercased(), attributes: [.font: config.teamTitleFont, .foregroundColor: homeColor]).draw(at: CGPoint(x: config.margin + colWidth + config.columnGap, y: titleY))
            currentY += 80
            
            // 4. Side-by-Side Scorecards
            let awayRect = CGRect(x: config.margin, y: currentY, width: colWidth, height: scorecardSectionHeight)
            drawScorecard(in: awayRect, data: scorecard, layout: awayLayout, isHome: false, ctx: ctx)
            
            let homeRect = CGRect(x: config.margin + colWidth + config.columnGap, y: currentY, width: colWidth, height: scorecardSectionHeight)
            drawScorecard(in: homeRect, data: scorecard, layout: homeLayout, isHome: true, ctx: ctx)
            
            currentY += scorecardSectionHeight + 80
            
            // 5. Pitcher Tables
            let pTitleY = currentY
            let pTitleAttrs: [NSAttributedString.Key: Any] = [.font: config.sectionTitleFont, .foregroundColor: config.pencilColor]
            NSAttributedString(string: "\(rawAwayName.uppercased()) PITCHERS", attributes: pTitleAttrs).draw(at: CGPoint(x: config.margin, y: pTitleY))
            NSAttributedString(string: "\(rawHomeName.uppercased()) PITCHERS", attributes: pTitleAttrs).draw(at: CGPoint(x: config.margin + colWidth + config.columnGap, y: pTitleY))
            currentY += 50
            
            let awayPRect = CGRect(x: config.margin, y: currentY, width: colWidth, height: pitcherSectionHeight)
            drawPitcherTable(in: awayPRect, pitchers: scorecard.pitchers.away, ctx: ctx)
            
            let homePRect = CGRect(x: config.margin + colWidth + config.columnGap, y: currentY, width: colWidth, height: pitcherSectionHeight)
            drawPitcherTable(in: homePRect, pitchers: scorecard.pitchers.home, ctx: ctx)
            
            currentY += pitcherSectionHeight + 80
            
            // 6. Game Info (Centered Row)
            if !filteredInfo.isEmpty {
                let infoRect = CGRect(x: config.margin, y: currentY, width: contentWidth, height: gameInfoHeight)
                drawSimpleGameInfo(in: infoRect, info: filteredInfo, ctx: ctx)
            }
        }
    }
    
    // MARK: - Drawing Helpers
    
    private func drawScoreboard(in rect: CGRect, linescore: Linescore?, scorecard: ScorecardData, ctx: CGContext) {
        let awayName = linescore?.teams?.away?.team?.name ?? scorecard.teams.away.name ?? "Away"
        let homeName = linescore?.teams?.home?.team?.name ?? scorecard.teams.home.name ?? "Home"
        let awayAbbr = teamAbbreviation(for: awayName)
        let homeAbbr = teamAbbreviation(for: homeName)
        let teamColorA = TeamColorProvider.color(for: awayName)
        let teamColorH = TeamColorProvider.color(for: homeName)
        
        let abbrFont = UIFont(name: "PermanentMarker-Regular", size: 30) ?? .systemFont(ofSize: 30, weight: .bold)
        let scoreFont = UIFont(name: "PermanentMarker-Regular", size: 26) ?? .systemFont(ofSize: 26, weight: .bold)
        let headerFont = UIFont(name: "PatrickHand-Regular", size: 20) ?? .systemFont(ofSize: 20)
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
        
        // Row 2 — Home team
        let homeRowY = tableY + 2 * rowHeight
        drawCentered(homeAbbr, in: CGRect(x: tableX, y: homeRowY, width: teamColWidth, height: rowHeight), attrs: [.font: abbrFont, .foregroundColor: teamColorH])
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
    
    private func teamAbbreviation(for teamName: String) -> String {
        let map = [
            "Arizona Diamondbacks": "AZ", "Atlanta Braves": "ATL", "Baltimore Orioles": "BAL", "Boston Red Sox": "BOS",
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
    
    private func drawScorecard(in rect: CGRect, data: ScorecardData, layout: ColumnLayout, isHome: Bool, ctx: CGContext) {
        let lineup = isHome ? data.lineups.home : data.lineups.away
        
        var actualWidth = config.nameWidth
        for inning in layout.innings { actualWidth += CGFloat(inning.subColumnCount) * config.inningWidth }
        for _ in layout.statColumns { actualWidth += config.statWidth }
        
        config.gridColor.withAlphaComponent(0.05).setFill()
        ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: actualWidth, height: config.headerHeight))
        
        ctx.setStrokeColor(config.gridColor.cgColor); ctx.setLineWidth(0.5)
        let rowCount = lineup.count + 1
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
        
        for (idx, batter) in lineup.enumerated() {
            let rowY = rect.minY + config.headerHeight + CGFloat(idx) * config.rowHeight
            let nameAttrs: [NSAttributedString.Key: Any] = [.font: config.nameFont, .foregroundColor: config.pencilColor]
            let posAttrs: [NSAttributedString.Key: Any] = [.font: config.posFont, .foregroundColor: config.pencilColor.withAlphaComponent(0.6)]
            NSAttributedString(string: batter.abbreviation, attributes: nameAttrs).draw(at: CGPoint(x: rect.minX + 10, y: rowY + 10))
            NSAttributedString(string: batter.position + (batter.jerseyNumber.map { " #\($0)" } ?? ""), attributes: posAttrs).draw(at: CGPoint(x: rect.minX + 10, y: rowY + 38))
            
            var actualX = rect.minX + config.nameWidth
            for col in 0..<(layout.totalColumns - layout.statColumns.count) {
                if let (inningNum, subIndex) = layout.inningInfo(forColumn: col) {
                    let inningObj = data.innings.first { $0.num == inningNum }
                    let batterEvents = (isHome ? inningObj?.home : inningObj?.away)?.filter { $0.batterId == batter.id } ?? []
                    if subIndex < batterEvents.count {
                        drawAtBatCell(in: CGRect(x: actualX, y: rowY, width: config.inningWidth, height: config.rowHeight), event: batterEvents[subIndex], ctx: ctx)
                    }
                }
                actualX += config.inningWidth
            }
            let stats = data.calculatePlayerStats(for: batter.id, isHome: isHome)
            for val in [stats.atBats, stats.runs, stats.hits, stats.rbi] {
                let str = "\(val)", size = (str as NSString).size(withAttributes: nameAttrs)
                NSAttributedString(string: str, attributes: nameAttrs).draw(at: CGPoint(x: actualX + (config.statWidth - size.width)/2, y: rowY + (config.rowHeight - size.height)/2))
                actualX += config.statWidth
            }
        }
        
        let totalsY = rect.minY + config.headerHeight + CGFloat(lineup.count) * config.rowHeight
        let tLabel = "TOTALS", tSize = (tLabel as NSString).size(withAttributes: hAttrs)
        NSAttributedString(string: tLabel, attributes: hAttrs).draw(at: CGPoint(x: rect.minX + (config.nameWidth - tSize.width)/2, y: totalsY + (config.rowHeight - tSize.height)/2))
        
        var tAB = 0, tR = 0, tH = 0, tRBI = 0
        for b in lineup { let s = data.calculatePlayerStats(for: b.id, isHome: isHome); tAB += s.atBats; tR += s.runs; tH += s.hits; tRBI += s.rbi }
        var actualX = rect.minX + config.nameWidth
        for inning in layout.innings { actualX += CGFloat(inning.subColumnCount) * config.inningWidth }
        for val in [tAB, tR, tH, tRBI] {
            let str = "\(val)", sAttrs: [NSAttributedString.Key: Any] = [.font: config.nameFont, .foregroundColor: config.pencilColor]
            let size = (str as NSString).size(withAttributes: sAttrs)
            NSAttributedString(string: str, attributes: sAttrs).draw(at: CGPoint(x: actualX + (config.statWidth - size.width)/2, y: totalsY + (config.rowHeight - size.height)/2))
            actualX += config.statWidth
        }
    }
    
    private func drawPitcherTable(in rect: CGRect, pitchers: [ScorecardPitcher], ctx: CGContext) {
        let tableWidth = config.pNameWidth + 6 * config.pStatWidth
        let totalHeight = config.headerHeight + CGFloat(pitchers.count) * config.pRowHeight
        ctx.setStrokeColor(config.gridColor.cgColor); ctx.setLineWidth(0.5)
        var currentX = rect.minX
        func drawVLine(_ x: CGFloat) { UIBezierPath.pencilLine(from: CGPoint(x: x, y: rect.minY), to: CGPoint(x: x, y: rect.minY + totalHeight), jitter: 0.5).stroke() }
        drawVLine(currentX); currentX += config.pNameWidth; drawVLine(currentX)
        for _ in 0..<6 { currentX += config.pStatWidth; drawVLine(currentX) }
        var currentY = rect.minY
        func drawHLine(_ y: CGFloat) { UIBezierPath.pencilLine(from: CGPoint(x: rect.minX, y: y), to: CGPoint(x: rect.minX + tableWidth, y: y), jitter: 0.5).stroke() }
        drawHLine(currentY); currentY += config.headerHeight; drawHLine(currentY)
        for _ in 0..<pitchers.count { currentY += config.pRowHeight; drawHLine(currentY) }
        let hAttrs: [NSAttributedString.Key: Any] = [.font: config.footerHeaderFont, .foregroundColor: config.pencilColor]
        NSAttributedString(string: "NAME", attributes: hAttrs).draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 10))
        let stats = ["IP", "H", "R", "ER", "BB", "K"]
        for (i, s) in stats.enumerated() {
            let x = rect.minX + config.pNameWidth + CGFloat(i) * config.pStatWidth, size = (s as NSString).size(withAttributes: hAttrs)
            NSAttributedString(string: s, attributes: hAttrs).draw(at: CGPoint(x: x + (config.pStatWidth - size.width)/2, y: rect.minY + 10))
        }
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
    
    private func drawSimpleGameInfo(in rect: CGRect, info: [GameInfoItem], ctx: CGContext) {
        let tAttrs: [NSAttributedString.Key: Any] = [.font: config.sectionTitleFont, .foregroundColor: config.pencilColor]
        let tSize = ("GAME INFO" as NSString).size(withAttributes: tAttrs)
        NSAttributedString(string: "GAME INFO", attributes: tAttrs).draw(at: CGPoint(x: rect.midX - tSize.width/2, y: rect.minY))
        
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: config.footerBodyFont, .foregroundColor: config.pencilColor.withAlphaComponent(0.7)]
        let valAttrs: [NSAttributedString.Key: Any] = [.font: config.footerDataFont, .foregroundColor: config.pencilColor]
        
        let infoStrings: [NSAttributedString] = info.map { item in
            let label = item.label.replacingOccurrences(of: ":", with: "")
            let value = item.value ?? ""
            let ms = NSMutableAttributedString()
            if value.isEmpty {
                ms.append(NSAttributedString(string: label, attributes: valAttrs))
            } else {
                ms.append(NSAttributedString(string: "\(label): ", attributes: labelAttrs))
                ms.append(NSAttributedString(string: value, attributes: valAttrs))
            }
            return ms
        }
        
        let spacing: CGFloat = 60
        let totalWidth = infoStrings.reduce(0) { $0 + $1.size().width } + CGFloat(infoStrings.count - 1) * spacing
        var currentX = rect.midX - totalWidth/2
        let y = rect.minY + 60
        
        for s in infoStrings {
            s.draw(at: CGPoint(x: currentX, y: y))
            currentX += s.size().width + spacing
        }
    }
    
    private func drawAtBatCell(in rect: CGRect, event: AtBatEvent, ctx: CGContext) {
        let dRect = rect.insetBy(dx: 8, dy: 8)
        ctx.setStrokeColor(config.pencilColor.withAlphaComponent(0.2).cgColor)
        UIBezierPath.pencilDiamond(rect: dRect, jitter: 0.5).stroke()
        ctx.setStrokeColor(config.pencilColor.withAlphaComponent(0.8).cgColor); ctx.setLineWidth(1.2)
        if event.bases.first { UIBezierPath.pencilLine(from: CGPoint(x: dRect.midX, y: dRect.maxY), to: CGPoint(x: dRect.maxX, y: dRect.midY), jitter: 0.4).stroke() }
        if event.bases.second { UIBezierPath.pencilLine(from: CGPoint(x: dRect.maxX, y: dRect.midY), to: CGPoint(x: dRect.midX, y: dRect.minY), jitter: 0.4).stroke() }
        if event.bases.third { UIBezierPath.pencilLine(from: CGPoint(x: dRect.midX, y: dRect.minY), to: CGPoint(x: dRect.minX, y: dRect.midY), jitter: 0.4).stroke() }
        if event.bases.home { UIBezierPath.pencilLine(from: CGPoint(x: dRect.minX, y: dRect.midY), to: CGPoint(x: dRect.midX, y: dRect.maxY), jitter: 0.4).stroke() }
        let res = event.result == "Ʞ" ? "K" : event.result
        let attrs: [NSAttributedString.Key: Any] = [.font: config.resultFont, .foregroundColor: config.pencilColor], size = (res as NSString).size(withAttributes: attrs)
        if event.result == "Ʞ" {
            ctx.saveGState(); ctx.translateBy(x: rect.midX, y: rect.midY); ctx.scaleBy(x: -1, y: 1); NSAttributedString(string: res, attributes: attrs).draw(at: CGPoint(x: -size.width/2, y: -size.height/2)); ctx.restoreGState()
        } else { NSAttributedString(string: res, attributes: attrs).draw(at: CGPoint(x: rect.midX - size.width/2, y: rect.midY - size.height/2)) }
        let cAttrs: [NSAttributedString.Key: Any] = [.font: config.legibilityFont, .foregroundColor: config.pencilColor.withAlphaComponent(0.7)]
        if event.balls > 0 { NSAttributedString(string: "\(event.balls)B", attributes: cAttrs).draw(at: CGPoint(x: rect.minX + 4, y: rect.minY + 2)) }
        if event.strikes > 0 { NSAttributedString(string: "\(event.strikes)S", attributes: cAttrs).draw(at: CGPoint(x: rect.maxX - 22, y: rect.minY + 2)) }
        if event.outs > 0 { NSAttributedString(string: "\(event.outs)", attributes: cAttrs).draw(at: CGPoint(x: rect.maxX - 15, y: rect.maxY - 18)) }
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
