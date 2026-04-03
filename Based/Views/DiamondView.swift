import UIKit

class DiamondView: UIView {
    
    enum Style {
        case scorecard
        case liveStatus
    }
    
    private let mainDiamondLayer = CAShapeLayer()
    private let basesLayer = CAShapeLayer()
    private let fillLayer = CAShapeLayer() // Use shape layer for pattern fill
    
    private let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
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
        layer.addSublayer(basesLayer)
        
        mainDiamondLayer.fillColor = UIColor(white: 0.9, alpha: 1.0).cgColor
        mainDiamondLayer.strokeColor = UIColor.clear.cgColor
        
        fillLayer.fillColor = UIColor.clear.cgColor
        fillLayer.strokeColor = UIColor.clear.cgColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
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
                let texture = UIImage.pencilTexture(color: .darkGray)
                fillLayer.fillColor = UIColor(patternImage: texture).cgColor
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
                bLayer.fillColor = UIColor.white.withAlphaComponent(0.6).cgColor
            }
            basesLayer.addSublayer(bLayer)
        }
        
        drawBaseBox(at: p.first, occupied: bases.first, base: 1)
        drawBaseBox(at: p.second, occupied: bases.second, base: 2)
        drawBaseBox(at: p.third, occupied: bases.third, base: 3)
        drawBaseBox(at: p.home, occupied: bases.home, base: 0)
        
        let lineLayer = CAShapeLayer()
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = UIColor(white: 0.1, alpha: 0.8).cgColor
        lineLayer.lineWidth = 2.5
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        basesLayer.addSublayer(lineLayer)
    }
}
