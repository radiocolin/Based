import UIKit

class PitchTrackView: UIView {
    
    // Data
    private var pitches: [PitchEvent] = []
    
    // Graphics
    private let zoneLayer = CAShapeLayer()
    private let pitchesLayer = CALayer()
    
    // Constants
    private var pencilColor: UIColor { AppColors.pencil }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayers() {
        layer.addSublayer(zoneLayer)
        layer.addSublayer(pitchesLayer)
        
        zoneLayer.fillColor = AppColors.zoneFill.cgColor
        zoneLayer.strokeColor = pencilColor.withAlphaComponent(0.6).cgColor
        zoneLayer.lineWidth = 1.5
        zoneLayer.lineDashPattern = [4, 4]
    }
    
    func configure(with pitches: [PitchEvent]) {
        self.pitches = pitches
        setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        drawContent()
    }
    
    private func drawContent() {
        pitchesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        zoneLayer.fillColor = AppColors.zoneFill.cgColor
        zoneLayer.strokeColor = pencilColor.withAlphaComponent(0.6).cgColor
        
        // Default zone if no data
        let top = pitches.first?.zoneTop ?? 3.5
        let bottom = pitches.first?.zoneBottom ?? 1.5
        
        // --- Coordinate System ---
        // X: -1.5 to 1.5 (3 ft width)
        // Z: 0.0 to 5.0 (5 ft height)
        
        let margin: CGFloat = 2 // Minimal margins to maximize strike zone
        let w = bounds.width - 2 * margin
        let h = bounds.height - 2 * margin
        
        guard w > 0, h > 0 else { return }
        
        // Scale: Map 3.0ft width to w, 5.0ft height to h.
        // Maintain aspect ratio.
        let scaleX = w / 3.0
        let scaleY = h / 5.0
        let scale = min(scaleX, scaleY)
        
        // Center Origin X (0) -> bounds.midX
        // Ground Origin Z (0) -> bounds.maxY - margin (adjusted for vertical centering)
        
        // We want to center the 3x5 box in the view
        let drawHeight = 5.0 * scale
        
        let originX = bounds.midX
        let originY = bounds.midY + (drawHeight / 2.0) // Bottom of the 5ft box
        
        // Function to map point
        func map(x: Double, z: Double) -> CGPoint {
            let px = originX + CGFloat(x) * scale
            let py = originY - CGFloat(z) * scale
            return CGPoint(x: px, y: py)
        }
        
        // --- Draw Zone ---
        // Width: 17 inches = 1.416 ft. Half = 0.708
        let halfPlate = 0.708
        
        let tl = map(x: -halfPlate, z: top)
        let tr = map(x: halfPlate, z: top)
        let br = map(x: halfPlate, z: bottom)
        let bl = map(x: -halfPlate, z: bottom)
        
        let zonePath = UIBezierPath()
        zonePath.move(to: tl)
        zonePath.addLine(to: tr)
        zonePath.addLine(to: br)
        zonePath.addLine(to: bl)
        zonePath.close()
        
        zoneLayer.path = zonePath.cgPath
        
        // --- Draw Pitches ---
        // Use a fixed readable size for pitch indicators
        let ballDiameter: CGFloat = 16

        for pitch in pitches {
            guard let x = pitch.x, let z = pitch.z else { continue }
            let pt = map(x: x, z: z)
            
            // Check if point is within reasonable bounds (clipping)
            // Allow some overflow for pitches that are way out of the zone
            let padding: CGFloat = 40
            let extendedBounds = bounds.insetBy(dx: -padding, dy: -padding)
            if !extendedBounds.contains(pt) {
                print("Pitch \(pitch.pitchNumber) out of bounds: \(pt)")
                continue
            }

            let dot = CALayer()
            dot.frame = CGRect(x: pt.x - ballDiameter/2, y: pt.y - ballDiameter/2, width: ballDiameter, height: ballDiameter)
            dot.backgroundColor = getColor(outcome: pitch.outcome).cgColor
            dot.cornerRadius = ballDiameter / 2
            dot.borderWidth = 1.5
            dot.borderColor = pencilColor.cgColor

            // Number
            let numLayer = CATextLayer()
            numLayer.string = "\(pitch.pitchNumber)"
            numLayer.fontSize = 10
            numLayer.font = UIFont(name: "PermanentMarker-Regular", size: 10)
            numLayer.alignmentMode = .center
            // Center vertically within the ballDiameter (16)
            // PermanentMarker usually sits a bit low, so we offset upwards slightly
            numLayer.frame = CGRect(x: 0, y: 1, width: ballDiameter, height: ballDiameter)
            numLayer.foregroundColor = UIColor.white.cgColor
            numLayer.contentsScale = traitCollection.displayScale

            dot.addSublayer(numLayer)
            pitchesLayer.addSublayer(dot)
        }
        
    }
    
    private func getColor(outcome: String) -> UIColor {
        let lower = outcome.lowercased()
        if lower.contains("ball") || lower.contains("intent_ball") { return .systemGreen }
        if lower.contains("strike") { return .systemRed }
        if lower.contains("foul") { return .systemOrange }
        if lower.contains("in play") { return .systemBlue }
        return .gray
    }
}
