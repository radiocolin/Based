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
    private let baseSize: CGFloat = 8
    
    private var diamondPoints: (home: CGPoint, first: CGPoint, second: CGPoint, third: CGPoint)?
    private var bases: BasesReached?
    private var isRun: Bool = false
    private var style: Style = .scorecard
    
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
        fillTextureLayer.lineWidth = 0.8
        fillTextureLayer.lineCap = .round
        fillTextureLayer.lineJoin = .round
        fillTextureLayer.mask = fillMaskLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        mainDiamondLayer.fillColor = AppColors.diamondFill.cgColor
        drawMainDiamond()
        updateActiveBases()
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
    
    func configure(with bases: BasesReached, style: Style = .scorecard, isRun: Bool = false) {
        self.bases = bases
        self.style = style
        self.isRun = isRun
        setNeedsLayout()
    }
    
    private func updateActiveBases() {
        guard let p = diamondPoints, let bases = bases else { return }
        
        basesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        fillLayer.fillColor = UIColor.clear.cgColor
        fillTextureLayer.strokeColor = UIColor.clear.cgColor
        
        let path = UIBezierPath()
        
        func addSegment(from: CGPoint, to: CGPoint, wasOut: Bool?) {
            if wasOut == true {
                let midX = (from.x + to.x) / 2
                let midY = (from.y + to.y) / 2
                let mid = CGPoint(x: midX, y: midY)
                path.append(UIBezierPath.pencilLine(from: from, to: mid))
                let dx = to.x - from.x, dy = to.y - from.y
                let len = hypot(dx, dy)
                let px = -dy / len * 6, py = dx / len * 6
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
                fillLayer.fillColor = AppColors.pencil.withAlphaComponent(0.08).cgColor
                fillTextureLayer.strokeColor = AppColors.pencil.withAlphaComponent(0.12).cgColor
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
            bLayer.lineWidth = 0.8
            bLayer.strokeColor = pencilColor.withAlphaComponent(0.4).cgColor
            
            if occupied {
                bLayer.fillColor = pencilColor.cgColor
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
        lineLayer.strokeColor = AppColors.lineStroke.cgColor
        lineLayer.lineWidth = 2.5
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
    
    /// Draws a text annotation (E6, SB, CS) near the appropriate base on the diamond.
    /// Font scales with diamond size so labels are legible in both small scorecard cells
    /// and the larger AtBatDetailViewController graphic.
    /// Positions avoid the existing corner labels (balls=top-left, strikes=top-right, outs=bottom-right).
    private func drawAnnotation(_ annotation: BaseAnnotation, points p: (home: CGPoint, first: CGPoint, second: CGPoint, third: CGPoint)) {
        // Scale font with diamond size (8pt at ~48px diamond, ~14pt at ~144px)
        let diamondSize = min(bounds.width, bounds.height) * 0.8
        let fontSize = max(8, min(16, diamondSize * 0.18))
        let font = UIFont(name: "PatrickHand-Regular", size: fontSize) ?? .systemFont(ofSize: fontSize, weight: .medium)
        let color = pencilColor.withAlphaComponent(0.85)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let textSize = (annotation.label as NSString).size(withAttributes: attrs)
        let offset = max(1, diamondSize * 0.02)
        
        // Determine the reference point
        let refPoint: CGPoint
        if annotation.kind == .caughtStealing {
            // Position slightly past the midpoint toward the target base (60% along the path)
            // so the label sits just beyond the perpendicular slash mark
            let (fromPt, toPt) = basePath(to: annotation.base, points: p)
            let t: CGFloat = 0.65
            refPoint = CGPoint(x: fromPt.x + (toPt.x - fromPt.x) * t,
                               y: fromPt.y + (toPt.y - fromPt.y) * t)
        } else {
            refPoint = baseVertex(annotation.base, points: p)
        }
        
        var x: CGFloat
        var y: CGFloat
        
        if annotation.kind == .caughtStealing {
            // Center directly on the base path
            x = refPoint.x - textSize.width / 2
            y = refPoint.y - textSize.height / 2
        } else {
            // Position to avoid corner labels:
            //   Top-left = balls, Top-right = strikes, Bottom-right = outs
            switch annotation.base {
            case 1: // First base (right vertex) — below, centered
                x = refPoint.x - textSize.width / 2
                y = refPoint.y + offset
            case 2: // Second base (top vertex) — to the LEFT (away from strikes corner)
                x = refPoint.x - textSize.width - offset
                y = refPoint.y - textSize.height / 2
            case 3: // Third base (left vertex) — below (toward free bottom-left corner)
                x = refPoint.x - textSize.width / 2
                y = refPoint.y + offset
            default: // Home (bottom vertex) — to the LEFT (away from outs corner)
                x = refPoint.x - textSize.width - offset
                y = refPoint.y - textSize.height / 2
            }
        }
        
        // Clamp within cell bounds
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
