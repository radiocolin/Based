import UIKit

extension UIBezierPath {
    /// Creates a "rough" hand-drawn path between two points.
    /// Jitter is deterministic so the path looks identical for the same endpoints.
    static func pencilLine(from start: CGPoint, to end: CGPoint, jitter: CGFloat = 0.6) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: start)
        
        let distance = hypot(end.x - start.x, end.y - start.y)
        guard distance.isFinite && distance > 0 else { return path }
        
        let segments = max(3, Int(distance / 10))
        
        // Seed from endpoints so the same line always produces the same wobble
        var seed: UInt64 = 5381
        seed = ((seed &<< 5) &+ seed) &+ UInt64(bitPattern: Int64((start.x * 100).rounded()))
        seed = ((seed &<< 5) &+ seed) &+ UInt64(bitPattern: Int64((start.y * 100).rounded()))
        seed = ((seed &<< 5) &+ seed) &+ UInt64(bitPattern: Int64((end.x * 100).rounded()))
        seed = ((seed &<< 5) &+ seed) &+ UInt64(bitPattern: Int64((end.y * 100).rounded()))
        
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            
            if i == segments {
                path.addLine(to: end)
            } else {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let r1 = CGFloat(Double(seed >> 33) / Double(1 << 31)) - 1.0
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let r2 = CGFloat(Double(seed >> 33) / Double(1 << 31)) - 1.0
                let offX = r1 * jitter
                let offY = r2 * jitter
                path.addLine(to: CGPoint(x: x + offX, y: y + offY))
            }
        }
        return path
    }
    
    /// Creates a wobbly, imperfect rectangle path.
    static func pencilRoughRect(rect: CGRect, jitter: CGFloat = 2.0) -> UIBezierPath {
        let path = UIBezierPath()
        guard rect.width.isFinite && rect.height.isFinite && rect.width > 0 && rect.height > 0 else { return path }
        
        let tl = CGPoint(x: rect.minX, y: rect.minY)
        let tr = CGPoint(x: rect.maxX, y: rect.minY)
        let br = CGPoint(x: rect.maxX, y: rect.maxY)
        let bl = CGPoint(x: rect.minX, y: rect.maxY)
        
        path.append(pencilLine(from: tl, to: tr, jitter: jitter))
        path.append(pencilLine(from: tr, to: br, jitter: jitter))
        path.append(pencilLine(from: br, to: bl, jitter: jitter))
        path.append(pencilLine(from: bl, to: tl, jitter: jitter))
        path.close()
        
        return path
    }
    
    static func pencilDiamond(rect: CGRect, jitter: CGFloat = 0.8) -> UIBezierPath {
        let path = UIBezierPath()
        guard rect.width.isFinite && rect.height.isFinite else { return path }
        let home = CGPoint(x: rect.midX, y: rect.maxY), first = CGPoint(x: rect.maxX, y: rect.midY)
        let second = CGPoint(x: rect.midX, y: rect.minY), third = CGPoint(x: rect.minX, y: rect.midY)
        path.append(pencilLine(from: home, to: first, jitter: jitter))
        path.append(pencilLine(from: first, to: second, jitter: jitter))
        path.append(pencilLine(from: second, to: third, jitter: jitter))
        path.append(pencilLine(from: third, to: home, jitter: jitter))
        path.close()
        return path
    }

    /// Creates a wobbly, imperfect circle path.
    static func pencilRoughCircle(center: CGPoint, radius: CGFloat, jitter: CGFloat = 1.0) -> UIBezierPath {
        let path = UIBezierPath()
        guard radius > 0 else { return path }
        let segments = 24
        var seed: UInt64 = 5381
        seed = ((seed &<< 5) &+ seed) &+ UInt64(bitPattern: Int64((center.x * 100).rounded()))
        seed = ((seed &<< 5) &+ seed) &+ UInt64(bitPattern: Int64((center.y * 100).rounded()))
        seed = ((seed &<< 5) &+ seed) &+ UInt64(bitPattern: Int64((radius * 100).rounded()))

        for i in 0...segments {
            let angle = CGFloat(i) / CGFloat(segments) * 2 * .pi
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let r = CGFloat(Double(seed >> 33) / Double(1 << 31)) - 1.0
            let rOff = r * jitter
            let x = center.x + (radius + rOff) * cos(angle)
            let y = center.y + (radius + rOff) * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.close()
        return path
    }

    /// Creates a dense back-and-forth scribble shading effect.
    /// Jitter is deterministic for the same rect.
    static func pencilScribble(in rect: CGRect, jitter: CGFloat = 1.0, spacing: CGFloat = 1.5) -> UIBezierPath {
        let path = UIBezierPath()
        guard rect.width.isFinite && rect.width > 2 && rect.height.isFinite && rect.height > 2 else { return path }
        
        var seed: UInt64 = 5381
        seed = ((seed &<< 5) &+ seed) &+ UInt64(bitPattern: Int64((rect.minX * 100).rounded()))
        seed = ((seed &<< 5) &+ seed) &+ UInt64(bitPattern: Int64((rect.minY * 100).rounded()))
        seed = ((seed &<< 5) &+ seed) &+ UInt64(bitPattern: Int64((rect.width * 100).rounded()))
        seed = ((seed &<< 5) &+ seed) &+ UInt64(bitPattern: Int64((rect.height * 100).rounded()))
        
        let lineSpacing = max(0.8, spacing)
        let totalWidth = rect.width + rect.height
        let steps = Int(totalWidth / lineSpacing)
        
        for i in 0...steps {
            let offset = CGFloat(i) * lineSpacing
            let start = CGPoint(x: rect.minX + offset - rect.height, y: rect.maxY)
            let end = CGPoint(x: rect.minX + offset, y: rect.minY)
            
            let cs = CGPoint(x: max(rect.minX, min(rect.maxX, start.x)), y: max(rect.minY, min(rect.maxY, start.y)))
            let ce = CGPoint(x: max(rect.minX, min(rect.maxX, end.x)), y: max(rect.minY, min(rect.maxY, end.y)))
            
            if cs != ce {
                path.move(to: cs)
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let r1 = CGFloat(Double(seed >> 33) / Double(1 << 31)) - 1.0
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let r2 = CGFloat(Double(seed >> 33) / Double(1 << 31)) - 1.0
                let mid = CGPoint(x: (cs.x + ce.x)/2 + r1 * jitter,
                                 y: (cs.y + ce.y)/2 + r2 * jitter)
                path.addLine(to: mid)
                path.addLine(to: ce)
            }
        }
        return path
    }
}

extension UIImage {
    static func pencilTexture(color: UIColor, size: CGSize = CGSize(width: 128, height: 128), density: Double = 0.1) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
        
        let rect = CGRect(origin: .zero, size: size)
        color.withAlphaComponent(0.08).setFill()
        context.fill(rect)
        
        context.setLineWidth(0.5)
        context.setLineCap(.round)
        
        // Use a deterministic sequence so the texture doesn't change between redraws
        var seed: UInt64 = 48271
        func nextRandom(in range: ClosedRange<CGFloat>) -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let normalized = CGFloat(Double(seed >> 33) / Double(1 << 31)) // 0..~2
            return range.lowerBound + (normalized / 2.0) * (range.upperBound - range.lowerBound)
        }
        
        for _ in 0..<Int(size.width * size.height * density) {
            let startX = nextRandom(in: -5...size.width)
            let startY = nextRandom(in: -5...size.height)
            let length = nextRandom(in: 4...12)
            let angle = CGFloat.pi / 4 + nextRandom(in: -0.2...0.2)
            
            let endX = startX + length * cos(angle)
            let endY = startY + length * sin(angle)
            
            let alpha = nextRandom(in: 0.05...0.25)
            color.withAlphaComponent(alpha).setStroke()
            
            context.move(to: CGPoint(x: startX, y: startY))
            context.addLine(to: CGPoint(x: endX, y: endY))
            context.strokePath()
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: - Pencil Overlay for UISegmentedControl

/// A transparent overlay that draws hand-drawn pencil borders on top of a
/// standard UISegmentedControl. Passes all touches through so the native
/// control keeps working normally.
class PencilSegmentedOverlay: UIView {

    private weak var segmentedControl: UISegmentedControl?
    private let borderLayer = CAShapeLayer()
    private let selectionView = UIView()
    private let scribbleLayer = CAShapeLayer()
    private var lastRenderedIndex: Int = -1

    init(segmentedControl: UISegmentedControl) {
        self.segmentedControl = segmentedControl
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 1.2
        borderLayer.lineCap = .round
        layer.addSublayer(borderLayer)

        // Selection view slides; scribble is drawn inside it
        selectionView.isUserInteractionEnabled = false
        scribbleLayer.lineWidth = 0.8
        scribbleLayer.fillColor = UIColor.clear.cgColor
        scribbleLayer.opacity = 0.25
        selectionView.layer.addSublayer(scribbleLayer)
        addSubview(selectionView)

        segmentedControl.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func selectionChanged() {
        animateSelection()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        redrawBorder()
        // Position without animation on layout
        moveSelection(animated: false)
    }

    private func redrawBorder() {
        guard let sc = segmentedControl else { return }
        let path = UIBezierPath()

        // Outer rough rect
        path.append(.pencilRoughRect(rect: bounds, jitter: 1.2))

        // Vertical dividers between segments
        let count = sc.numberOfSegments
        guard count > 1 else { return }
        let segW = bounds.width / CGFloat(count)
        for i in 1..<count {
            let x = segW * CGFloat(i)
            path.append(.pencilLine(
                from: CGPoint(x: x, y: bounds.minY + 4),
                to: CGPoint(x: x, y: bounds.maxY - 4),
                jitter: 0.8
            ))
        }

        borderLayer.path = path.cgPath
        borderLayer.strokeColor = AppColors.pencil.withAlphaComponent(0.4).cgColor
    }

    private func animateSelection() {
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .beginFromCurrentState) {
            self.moveSelection(animated: true)
        }
    }

    private func moveSelection(animated: Bool) {
        guard let sc = segmentedControl, sc.selectedSegmentIndex >= 0 else {
            selectionView.isHidden = true
            return
        }
        selectionView.isHidden = false

        let count = sc.numberOfSegments
        let segW = bounds.width / CGFloat(count)
        let targetFrame = CGRect(
            x: segW * CGFloat(sc.selectedSegmentIndex) + 3,
            y: 3,
            width: segW - 6,
            height: bounds.height - 6
        )
        selectionView.frame = targetFrame

        // Only regenerate the scribble when the segment size changes or on first draw
        if lastRenderedIndex != sc.selectedSegmentIndex || scribbleLayer.path == nil {
            let localRect = CGRect(origin: .zero, size: targetFrame.size)
            scribbleLayer.path = UIBezierPath.pencilScribble(in: localRect, jitter: 0.8).cgPath
            scribbleLayer.strokeColor = AppColors.pencil.cgColor
            scribbleLayer.frame = localRect
            lastRenderedIndex = sc.selectedSegmentIndex
        }
    }
}
