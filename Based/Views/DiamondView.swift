import UIKit

class DiamondView: UIView {
    
    enum Style {
        case scorecard
        case liveStatus
    }
    
    private let mainDiamondLayer = CAShapeLayer()
    private let basesLayer = CAShapeLayer()
    private let fillLayer = CAShapeLayer()
    private let fillTextureLayer = CAShapeLayer()
    private let fillMaskLayer = CAShapeLayer()
    
    private var pencilColor: UIColor { AppColors.pencil }
    
    /// Base box size scales with the drawn diamond so proportions stay consistent
    /// across the small scorecard cells, the live-status panel, and the large detail graphic.
    private var baseSize: CGFloat {
        let diamondSize = min(bounds.width, bounds.height) * 0.8
        return max(5, diamondSize * 0.11)
    }
    
    /// Progress-line width scales with diamond size.
    private var progressLineWidth: CGFloat {
        let diamondSize = min(bounds.width, bounds.height) * 0.8
        return max(1.5, min(4, diamondSize * 0.035))
    }
    
    /// Base-box stroke width scales with diamond size.
    private var baseStrokeWidth: CGFloat {
        let diamondSize = min(bounds.width, bounds.height) * 0.8
        return max(0.5, min(1.5, diamondSize * 0.015))
    }
    
    private var diamondPoints: (home: CGPoint, first: CGPoint, second: CGPoint, third: CGPoint)?
    private var bases: BasesReached?
    private var isRun: Bool = false
    private var style: Style = .scorecard
    private var accentColorOverride: UIColor?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayers() {
        layer.addSublayer(mainDiamondLayer)
        layer.addSublayer(fillLayer)
        layer.addSublayer(fillTextureLayer)
        layer.addSublayer(basesLayer)
        
        mainDiamondLayer.fillColor = AppColors.diamondFill.cgColor
        mainDiamondLayer.strokeColor = UIColor.clear.cgColor
        
        fillLayer.fillColor = UIColor.clear.cgColor
        fillLayer.strokeColor = UIColor.clear.cgColor

        fillTextureLayer.fillColor = UIColor.clear.cgColor
        fillTextureLayer.strokeColor = UIColor.clear.cgColor
        fillTextureLayer.lineWidth = 1.0
        fillTextureLayer.lineCap = .round
        fillTextureLayer.lineJoin = .round
        fillTextureLayer.mask = fillMaskLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        mainDiamondLayer.fillColor = AppColors.diamondFill.cgColor
        fillTextureLayer.lineWidth = baseStrokeWidth
        drawMainDiamond()
        updateActiveBases()
        
        // Ensure text layers use correct scale after layout
        basesLayer.sublayers?.compactMap { $0 as? CATextLayer }.forEach {
            $0.contentsScale = traitCollection.displayScale
        }
    }
    
    private func drawMainDiamond() {
        let size = min(bounds.width, bounds.height) * 0.8
        let cx = bounds.midX
        let cy = bounds.midY
        
        let home = CGPoint(x: cx, y: cy + size/2)
        let first = CGPoint(x: cx + size/2, y: cy)
        let second = CGPoint(x: cx, y: cy - size/2)
        let third = CGPoint(x: cx - size/2, y: cy)
        
        self.diamondPoints = (home, first, second, third)
        
        let path = UIBezierPath()
        path.move(to: home)
        path.addLine(to: first)
        path.addLine(to: second)
        path.addLine(to: third)
        path.close()
        
        mainDiamondLayer.path = path.cgPath
        fillLayer.path = path.cgPath
        fillMaskLayer.path = path.cgPath
        fillTextureLayer.frame = bounds
        fillTextureLayer.path = UIBezierPath.pencilScribble(
            in: bounds,
            jitter: 0.8
        ).cgPath
    }
    
    func configure(with bases: BasesReached, style: Style = .scorecard, isRun: Bool = false, accentColor: UIColor? = nil) {
        self.bases = bases
        self.style = style
        self.isRun = isRun
        self.accentColorOverride = accentColor
        setNeedsLayout()
    }
    
    private func updateActiveBases() {
        guard let p = diamondPoints, let bases = bases else { return }
        
        basesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        fillLayer.fillColor = UIColor.clear.cgColor
        fillTextureLayer.strokeColor = UIColor.clear.cgColor

        let shouldUseAccent = style == .scorecard && (isRun || bases.home)
        let accentColor = shouldUseAccent ? (accentColorOverride ?? AppColors.pencil) : AppColors.pencil
        
        let path = UIBezierPath()
        
        func addSegment(from: CGPoint, to: CGPoint, wasOut: Bool?) {
            if wasOut == true {
                let midX = (from.x + to.x) / 2
                let midY = (from.y + to.y) / 2
                let mid = CGPoint(x: midX, y: midY)
                path.append(UIBezierPath.pencilLine(from: from, to: mid))
                let dx = to.x - from.x, dy = to.y - from.y
                let len = hypot(dx, dy)
                let slashSize = max(4, min(bounds.width, bounds.height) * 0.8 * 0.09)
                let px = -dy / len * slashSize, py = dx / len * slashSize
                path.append(UIBezierPath.pencilLine(from: CGPoint(x: mid.x - px, y: mid.y - py), to: CGPoint(x: mid.x + px, y: mid.y + py)))
            } else {
                path.append(UIBezierPath.pencilLine(from: from, to: to))
            }
        }

        // Draw Scorecard Progress Lines
        if style == .scorecard {
            if bases.first || bases.outAtFirst == true { addSegment(from: p.home, to: p.first, wasOut: bases.outAtFirst) }
            if bases.second || bases.outAtSecond == true { addSegment(from: p.first, to: p.second, wasOut: bases.outAtSecond) }
            if bases.third || bases.outAtThird == true { addSegment(from: p.second, to: p.third, wasOut: bases.outAtThird) }
            if bases.home || bases.outAtHome == true {
                addSegment(from: p.third, to: p.home, wasOut: bases.outAtHome)
            }
            
            if isRun || bases.home {
                fillLayer.fillColor = accentColor.withAlphaComponent(0.08).cgColor
                fillTextureLayer.strokeColor = accentColor.withAlphaComponent(0.12).cgColor
            }
        }

        // Draw Base Indicators (The Boxes) - Consistent in both styles
        // Inset them so they sit inside the diamond lines
        func drawBaseBox(at vertex: CGPoint, occupied: Bool, base: Int) {
            let half = baseSize / 2
            let bPath = UIBezierPath()
            
            if base == 0 {
                // Authentic 5-sided Home Plate
                // Pointing down, flat top, vertical sides
                let w = baseSize * 1.2
                let h = baseSize * 1.2
                let topY = vertex.y - h
                let midY = vertex.y - h/2
                
                bPath.move(to: CGPoint(x: vertex.x, y: vertex.y)) // Bottom point
                bPath.addLine(to: CGPoint(x: vertex.x - w/2, y: midY)) // Left middle
                bPath.addLine(to: CGPoint(x: vertex.x - w/2, y: topY)) // Left top
                bPath.addLine(to: CGPoint(x: vertex.x + w/2, y: topY)) // Right top
                bPath.addLine(to: CGPoint(x: vertex.x + w/2, y: midY)) // Right middle
                bPath.close()
            } else {
                // Offset the center so the entire box is inside the diamond
                var center = vertex
                switch base {
                case 1: center.x -= half // Move left from right vertex
                case 2: center.y += half // Move down from top vertex
                case 3: center.x += half // Move right from left vertex
                default: break
                }
                
                bPath.move(to: CGPoint(x: center.x, y: center.y - half))
                bPath.addLine(to: CGPoint(x: center.x + half, y: center.y))
                bPath.addLine(to: CGPoint(x: center.x, y: center.y + half))
                bPath.addLine(to: CGPoint(x: center.x - half, y: center.y))
                bPath.close()
            }
            
            let bLayer = CAShapeLayer()
            bLayer.path = bPath.cgPath
            bLayer.lineWidth = baseStrokeWidth
            bLayer.strokeColor = accentColor.withAlphaComponent(0.4).cgColor
            
            if occupied {
                bLayer.fillColor = accentColor.cgColor
            } else {
                bLayer.fillColor = AppColors.baseEmpty.cgColor
            }
            basesLayer.addSublayer(bLayer)
        }
        
        drawBaseBox(at: p.first, occupied: bases.first, base: 1)
        drawBaseBox(at: p.second, occupied: bases.second, base: 2)
        drawBaseBox(at: p.third, occupied: bases.third, base: 3)
        drawBaseBox(at: p.home, occupied: bases.home, base: 0)
        
        // Draw caught-stealing out indicators (half-line + perpendicular between bases)
        if style == .scorecard, let annotations = bases.annotations {
            for annotation in annotations where annotation.kind == .caughtStealing {
                let (fromPt, toPt) = basePath(to: annotation.base, points: p)
                addSegment(from: fromPt, to: toPt, wasOut: true)
            }
        }
        
        let lineLayer = CAShapeLayer()
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = accentColor.withAlphaComponent(0.8).cgColor
        lineLayer.lineWidth = progressLineWidth
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        basesLayer.addSublayer(lineLayer)
        
        // Draw text annotations (errors, stolen bases, caught stealing)
        if style == .scorecard, let annotations = bases.annotations {
            for annotation in annotations {
                drawAnnotation(annotation, points: p)
            }
        }
    }
    
    // MARK: - Annotation Placement System
    //
    // Every annotation uses: reference point + cardinal offset + text alignment.
    // All gaps derive from `baseSize` / `fontSize` which scale with the diamond,
    // so proportions are identical at every rendering size.
    //
    // Three rules, three directions:
    //
    //   Type          Reference        Offset        Alignment        Why
    //   ───────────── ──────────────── ───────────── ──────────────── ──────────────────────
    //   E/SB at 1B    1B vertex        DOWN          center-X         Clears TR (strikes)
    //   E/SB at 3B    3B vertex        DOWN          center-X         Clears TL (balls)
    //   E/SB at 2B    2B vertex        LEFT          right-align      Clears TR (strikes)
    //   E/SB at Home  Home vertex      LEFT          right-align      Clears BR (outs)
    //   CS            slash midpoint   AWAY from ctr  center-X         Clears slash mark + result
    //
    // Reserved zones the system avoids:
    //   TL corner = balls count,  TR corner = strikes count,
    //   BR corner = outs count,   center = result text.
    //
    //     ┌──────────────────────────┐
    //     │ [B]  ↑CS ◇ 2B  ↑CS [S]  │  CS on upper paths → UP
    //     │        ╱←ann╲           │
    //     │  3B  ◇   ╳    ◇  1B    │
    //     │    ↓ann         ↓ann    │
    //     │        ╲←ann╱      [O]  │
    //     │   ↓CS    ◇ Home  ↓CS    │  CS on lower paths → DOWN
    //     └──────────────────────────┘

    private func drawAnnotation(_ annotation: BaseAnnotation, points p: (home: CGPoint, first: CGPoint, second: CGPoint, third: CGPoint)) {
        let diamondSize = min(bounds.width, bounds.height) * 0.8
        let fontSize = max(8, min(16, diamondSize * 0.18))
        let font = UIFont(name: "PatrickHand-Regular", size: fontSize) ?? .systemFont(ofSize: fontSize, weight: .medium)
        let color = (accentColorOverride ?? pencilColor).withAlphaComponent(0.85)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let textSize = (annotation.label as NSString).size(withAttributes: attrs)

        let anchor: CGPoint
        let alignX: CGFloat   // 0 = left edge at anchor, 0.5 = centered, 1 = right edge
        let alignY: CGFloat   // 0 = top edge at anchor, 0.5 = centered, 1 = bottom edge

        if annotation.kind == .caughtStealing {
            // CS: reference = slash midpoint, offset = away from diamond center on Y axis.
            // Upper basepaths (mid above center) → label goes UP.
            // Lower basepaths (mid below center) → label goes DOWN.
            let (fromPt, toPt) = basePath(to: annotation.base, points: p)
            let midX = (fromPt.x + toPt.x) / 2
            let midY = (fromPt.y + toPt.y) / 2
            let cy = bounds.midY
            let slashExtent = max(4, diamondSize * 0.09)
            let verticalGap = slashExtent + fontSize * 0.6
            if midY < cy {
                // Upper basepath — push UP toward top edge
                anchor = CGPoint(x: midX, y: midY - verticalGap)
                alignX = 0.5; alignY = 1.0
            } else {
                // Lower basepath — push DOWN toward bottom edge
                anchor = CGPoint(x: midX, y: midY + verticalGap)
                alignX = 0.5; alignY = 0
            }
        } else {
            let gap = baseSize
            let vertex = baseVertex(annotation.base, points: p)
            switch annotation.base {
            case 1, 3:
                // Side vertices — DOWN, horizontally centered
                anchor = CGPoint(x: vertex.x, y: vertex.y + gap)
                alignX = 0.5; alignY = 0
            default:
                // Pole vertices (2B, Home) — LEFT, vertically centered
                anchor = CGPoint(x: vertex.x - gap, y: vertex.y)
                alignX = 1.0; alignY = 0.5
            }
        }

        // Derive frame from anchor + alignment
        var x = anchor.x - textSize.width * alignX
        var y = anchor.y - textSize.height * alignY

        // Clamp within view bounds
        x = max(1, min(x, bounds.width - textSize.width - 1))
        y = max(1, min(y, bounds.height - textSize.height - 1))

        let textLayer = CATextLayer()
        textLayer.string = NSAttributedString(string: annotation.label, attributes: attrs)
        textLayer.frame = CGRect(x: x, y: y, width: textSize.width + 2, height: textSize.height)
        textLayer.contentsScale = traitCollection.displayScale
        textLayer.isWrapped = false
        basesLayer.addSublayer(textLayer)
    }
    
    /// Returns the vertex point for a given base number (1=1B, 2=2B, 3=3B, 4=home).
    private func baseVertex(_ base: Int, points p: (home: CGPoint, first: CGPoint, second: CGPoint, third: CGPoint)) -> CGPoint {
        switch base {
        case 1: return p.first
        case 2: return p.second
        case 3: return p.third
        default: return p.home
        }
    }
    
    /// Returns the (from, to) points for the base path leading to a given base.
    private func basePath(to base: Int, points p: (home: CGPoint, first: CGPoint, second: CGPoint, third: CGPoint)) -> (CGPoint, CGPoint) {
        switch base {
        case 2: return (p.first, p.second)   // 1B → 2B
        case 3: return (p.second, p.third)   // 2B → 3B
        case 4: return (p.third, p.home)     // 3B → Home
        default: return (p.home, p.first)    // Home → 1B
        }
    }
}
