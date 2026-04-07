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

    static func pencilShareIcon(rect: CGRect, jitter: CGFloat = 0.8) -> UIBezierPath {
        let path = UIBezierPath()
        let inset: CGFloat = 4
        let r = rect.insetBy(dx: inset, dy: inset)
        
        let boxTop = r.minY + r.height * 0.3
        let boxRect = CGRect(x: r.minX, y: boxTop, width: r.width, height: r.height * 0.7)
        
        let tl = CGPoint(x: boxRect.minX, y: boxRect.minY)
        let bl = CGPoint(x: boxRect.minX, y: boxRect.maxY)
        let br = CGPoint(x: boxRect.maxX, y: boxRect.maxY)
        let tr = CGPoint(x: boxRect.maxX, y: boxRect.minY)
        
        path.append(.pencilLine(from: tl, to: bl, jitter: jitter))
        path.append(.pencilLine(from: bl, to: br, jitter: jitter))
        path.append(.pencilLine(from: br, to: tr, jitter: jitter))
        
        let midX = r.midX
        let arrowTop = r.minY
        let arrowBottom = r.minY + r.height * 0.55
        
        path.append(.pencilLine(from: CGPoint(x: midX, y: arrowBottom), 
                               to: CGPoint(x: midX, y: arrowTop), jitter: jitter))
        
        let headSize = r.width * 0.3
        let headL = CGPoint(x: midX - headSize, y: arrowTop + headSize)
        let headR = CGPoint(x: midX + headSize, y: arrowTop + headSize)
        
        path.append(.pencilLine(from: CGPoint(x: midX, y: arrowTop), to: headL, jitter: jitter))
        path.append(.pencilLine(from: CGPoint(x: midX, y: arrowTop), to: headR, jitter: jitter))
        
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

    static func sketchImage(size: CGSize, strokeColor: UIColor, lineWidth: CGFloat = 1.2, pathProvider: (CGRect) -> UIBezierPath) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = pathProvider(rect)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            strokeColor.setStroke()
            path.stroke()
        }
    }

    private static var iconCache: [String: UIImage] = [:]
    
    static func pencilStyledIcon(named name: String, color: UIColor, size: CGSize = CGSize(width: 24, height: 24), offset: CGPoint = .zero, scaleMultiplier: CGFloat = 1.0) -> UIImage? {
        let cacheKey = "\(name)-\(color.hashValue)-\(size.width)x\(size.height)-\(offset.x)-\(offset.y)-\(scaleMultiplier)"
        if let cached = iconCache[cacheKey] {
            return cached
        }

        // 1. Get the vector path for the icon
        guard let path = PencilIcons.path(for: name) else {
            return UIImage(named: name)?.withRenderingMode(.alwaysTemplate)
        }
        
        // 2. Scale and Center based on a standard 24x24 coordinate system
        // This preserves the original artist's alignment/whitespace.
        let refSize: CGFloat = 24.0
        let baseScale = min(size.width, size.height) / refSize
        let finalScale = baseScale * scaleMultiplier
        
        // Center the 24x24 box in the target size, then apply custom offset
        let tx = (size.width - refSize * finalScale) / 2 + (offset.x * finalScale)
        let ty = (size.height - refSize * finalScale) / 2 + (offset.y * finalScale)
        
        let transform = CGAffineTransform(scaleX: finalScale, y: finalScale)
            .concatenating(CGAffineTransform(translationX: tx, y: ty))
        
        path.apply(transform)
        path.usesEvenOddFillRule = true
        
        // 3. Apply more noticeable pencil wobble to match segmented picker
        let wobbledPath = path.wobbled(jitter: 0.6)
        
        // 4. Render as a simple fill
        let renderer = UIGraphicsImageRenderer(size: size)
        let finalImage = renderer.image { context in
            color.setFill()
            wobbledPath.fill()
        }
        
        iconCache[cacheKey] = finalImage
        return finalImage
    }
}

// MARK: - SVG Path Parsing & Wobble

extension UIBezierPath {
    func wobbled(jitter: CGFloat = 0.5) -> UIBezierPath {
        let wobbledPath = UIBezierPath()
        var currentPoint: CGPoint = .zero
        var subpathStart: CGPoint = .zero
        
        self.cgPath.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                wobbledPath.move(to: points[0])
                currentPoint = points[0]
                subpathStart = points[0]
            case .addLineToPoint:
                addWobbledLine(from: currentPoint, to: points[0], into: wobbledPath, jitter: jitter)
                currentPoint = points[0]
            case .addQuadCurveToPoint:
                let p1 = points[0]
                let p2 = points[1]
                let steps = 10
                for i in 1...steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    let next = CGPoint(
                        x: (1-t)*(1-t)*currentPoint.x + 2*(1-t)*t*p1.x + t*t*p2.x,
                        y: (1-t)*(1-t)*currentPoint.y + 2*(1-t)*t*p1.y + t*t*p2.y
                    )
                    addWobbledLine(from: currentPoint, to: next, into: wobbledPath, jitter: jitter)
                    currentPoint = next
                }
            case .addCurveToPoint:
                let p1 = points[0]
                let p2 = points[1]
                let p3 = points[2]
                let steps = 15
                for i in 1...steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    let next = CGPoint(
                        x: pow(1-t, 3)*currentPoint.x + 3*pow(1-t, 2)*t*p1.x + 3*(1-t)*t*t*p2.x + pow(t, 3)*p3.x,
                        y: pow(1-t, 3)*currentPoint.y + 3*pow(1-t, 2)*t*p1.y + 3*(1-t)*t*t*p2.y + pow(t, 3)*p3.y
                    )
                    addWobbledLine(from: currentPoint, to: next, into: wobbledPath, jitter: jitter)
                    currentPoint = next
                }
            case .closeSubpath:
                if currentPoint != subpathStart {
                    addWobbledLine(from: currentPoint, to: subpathStart, into: wobbledPath, jitter: jitter)
                }
                wobbledPath.close()
            @unknown default:
                break
            }
        }
        return wobbledPath
    }
    
    private func addWobbledLine(from start: CGPoint, to end: CGPoint, into path: UIBezierPath, jitter: CGFloat) {
        let dist = hypot(end.x - start.x, end.y - start.y)
        guard dist.isFinite && dist > 0 else {
            if dist == 0 { path.addLine(to: end) }
            return
        }
        
        let segments = max(2, Int(min(dist / 6, 50)))
        
        var seed = UInt64(abs(start.x * 1000 + start.y * 100 + end.x * 10 + end.y))
        func nextJitter() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return (CGFloat(Double(seed >> 33) / Double(1 << 31)) - 1.0) * jitter
        }
        
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            if i == segments {
                path.addLine(to: end)
            } else {
                let target = CGPoint(x: start.x + (end.x - start.x) * t, 
                                     y: start.y + (end.y - start.y) * t)
                let jp = CGPoint(x: target.x + nextJitter(), y: target.y + nextJitter())
                path.addLine(to: jp)
            }
        }
    }
}

struct PencilIcons {
    static func path(for name: String) -> UIBezierPath? {
        switch name {
        case "square.grid.3x2":
            let d = "M5.23-9.41L10.57-9.41C12.06-9.41 12.81-10.16 12.81-11.71L12.81-16.95C12.81-18.49 12.06-19.23 10.57-19.23L5.23-19.23C3.74-19.23 2.99-18.49 2.99-16.95L2.99-11.71C2.99-10.16 3.74-9.41 5.23-9.41ZM16.99-9.41L22.32-9.41C23.81-9.41 24.56-10.16 24.56-11.71L24.56-16.95C24.56-18.49 23.81-19.23 22.32-19.23L16.99-19.23C15.49-19.23 14.74-18.49 14.74-16.95L14.74-11.71C14.74-10.16 15.49-9.41 16.99-9.41ZM28.75-9.41L34.09-9.41C35.58-9.41 36.33-10.16 36.33-11.71L36.33-16.95C36.33-18.49 35.58-19.23 34.09-19.23L28.75-19.23C27.26-19.23 26.51-18.49 26.51-16.95L26.51-11.71C26.51-10.16 27.26-9.41 28.75-9.41ZM5.25-11.06C4.84-11.06 4.64-11.27 4.64-11.71L4.64-16.95C4.64-17.37 4.84-17.58 5.25-17.58L10.54-17.58C10.95-17.58 11.16-17.37 11.16-16.95L11.16-11.71C11.16-11.27 10.95-11.06 10.54-11.06ZM17.02-11.06C16.59-11.06 16.39-11.27 16.39-11.71L16.39-16.95C16.39-17.37 16.59-17.58 17.02-17.58L22.30-17.58C22.71-17.58 22.91-17.37 22.91-16.95L22.91-11.71C22.91-11.27 22.71-11.06 22.30-11.06ZM28.77-11.06C28.36-11.06 28.16-11.27 28.16-11.71L28.16-16.95C28.16-17.37 28.36-17.58 28.77-17.58L34.05-17.58C34.48-17.58 34.68-17.37 34.68-16.95L34.68-11.71C34.68-11.27 34.48-11.06 34.05-11.06ZM5.23 2.34L10.57 2.34C12.06 2.34 12.81 1.61 12.81 0.06L12.81-5.19C12.81-6.73 12.06-7.48 10.57-7.48L5.23-7.48C3.74-7.48 2.99-6.73 2.99-5.19L2.99 0.06C2.99 1.61 3.74 2.34 5.23 2.34ZM16.99 2.34L22.32 2.34C23.81 2.34 24.56 1.61 24.56 0.06L24.56-5.19C24.56-6.73 23.81-7.48 22.32-7.48L16.99-7.48C15.49-7.48 14.74-6.73 14.74-5.19L14.74 0.06C14.74 1.61 15.49 2.34 16.99 2.34ZM28.75 2.34L34.09 2.34C35.58 2.34 36.33 1.61 36.33 0.06L36.33-5.19C36.33-6.73 35.58-7.48 34.09-7.48L28.75-7.48C27.26-7.48 26.51-6.73 26.51-5.19L26.51 0.06C26.51 1.61 27.26 2.34 28.75 2.34ZM5.25 0.69C4.84 0.69 4.64 0.48 4.64 0.06L4.64-5.18C4.64-5.61 4.84-5.82 5.25-5.82L10.54-5.82C10.95-5.82 11.16-5.61 11.16-5.18L11.16 0.06C11.16 0.48 10.95 0.69 10.54 0.69ZM17.02 0.69C16.59 0.69 16.39 0.48 16.39 0.06L16.39-5.18C16.39-5.61 16.59-5.82 17.02-5.82L22.30-5.82C22.71-5.82 22.91-5.61 22.91-5.18L22.91 0.06C22.91 0.48 22.71 0.69 22.30 0.69ZM28.77 0.69C28.36 0.69 28.16 0.48 28.16 0.06L28.16-5.18C28.16-5.61 28.36-5.82 28.77-5.82L34.05-5.82C34.48-5.82 34.68-5.61 34.68-5.18L34.68 0.06C34.68 0.48 34.48 0.69 34.05 0.69Z"
            let t = CGAffineTransform(a: 0.59988, b: 0, c: 0, d: 0.59988, tx: 0.20738, ty: 17.0650)
            return parseSVG(d, transform: t)
        case "square.and.arrow.up":
            let d = "M13.38-5.58C13.89-5.58 14.32-5.99 14.32-6.48L14.32-18.40L14.24-20.17L14.91-19.46L16.71-17.53C16.88-17.34 17.12-17.25 17.34-17.25C17.84-17.25 18.20-17.59 18.20-18.07C18.20-18.33 18.11-18.52 17.93-18.69L14.06-22.42C13.83-22.65 13.63-22.72 13.38-22.72C13.15-22.72 12.95-22.65 12.70-22.42L8.85-18.69C8.67-18.52 8.57-18.33 8.57-18.07C8.57-17.59 8.92-17.25 9.41-17.25C9.63-17.25 9.89-17.34 10.05-17.53L11.87-19.46L12.54-20.17L12.46-18.40L12.46-6.48C12.46-5.99 12.88-5.58 13.38-5.58ZM7.89 3.60L18.88 3.60C22.03 3.60 23.79 1.85 23.79-1.30L23.79-10.32C23.79-13.46 22.03-15.22 18.88-15.22L16.51-15.22L16.51-13.34L18.88-13.34C20.81-13.34 21.90-12.25 21.90-10.32L21.90-1.30C21.90 0.63 20.81 1.71 18.88 1.71L7.89 1.71C5.96 1.71 4.88 0.63 4.88-1.30L4.88-10.32C4.88-12.25 5.96-13.34 7.89-13.34L10.25-13.34L10.25-15.22L7.89-15.22C4.73-15.22 2.99-13.46 2.99-10.32L2.99-1.30C2.99 1.85 4.73 3.60 7.89 3.60Z"
            let t = CGAffineTransform(a: 0.75987, b: 0, c: 0, d: 0.75987, tx: 1.82636, ty: 19.26625)
            return parseSVG(d, transform: t)
        case "calendar.day.timeline.left":
            let d = "M7.96-10.88L9.84-10.88L9.84-15.70C9.84-16.79 10.43-17.34 11.47-17.34L27.81-17.34C28.85-17.34 29.43-16.79 29.43-15.70L29.43-10.88L31.31-10.88L31.31-15.60C31.31-18.02 30.08-19.23 27.63-19.23L11.63-19.23C9.18-19.23 7.96-18.01 7.96-15.60ZM4.59-16.35C5.38-16.35 6.01-16.98 6.01-17.78C6.01-18.56 5.38-19.20 4.59-19.20C3.81-19.20 3.16-18.56 3.16-17.78C3.16-16.98 3.81-16.35 4.59-16.35ZM4.59-11.70C5.38-11.70 6.01-12.34 6.01-13.13C6.01-13.91 5.38-14.54 4.59-14.54C3.81-14.54 3.16-13.91 3.16-13.13C3.16-12.34 3.81-11.70 4.59-11.70ZM32.14-8.45C32.14-8.91 31.77-9.27 31.31-9.27L5.95-9.27C5.68-9.75 5.16-10.05 4.59-10.05C3.71-10.05 2.99-9.34 2.99-8.46C2.99-7.58 3.71-6.87 4.59-6.87C5.16-6.87 5.66-7.16 5.93-7.62L31.31-7.62C31.77-7.62 32.14-7.99 32.14-8.45ZM9.84-6.02L7.96-6.02L7.96-1.29C7.96 1.13 9.18 2.34 11.63 2.34L27.63 2.34C30.08 2.34 31.31 1.14 31.31-1.29L31.31-6.02L29.43-6.02L29.43-1.18C29.43-0.09 28.85 0.46 27.81 0.46L11.47 0.46C10.43 0.46 9.84-0.09 9.84-1.18ZM4.59-2.41C5.38-2.41 6.01-3.05 6.01-3.83C6.01-4.63 5.38-5.26 4.59-5.26C3.81-5.26 3.16-4.63 3.16-3.83C3.16-3.05 3.81-2.41 4.59-2.41ZM4.59 2.24C5.38 2.24 6.01 1.59 6.01 0.81C6.01 0.02 5.38-0.61 4.59-0.61C3.81-0.61 3.16 0.02 3.16 0.81C3.16 1.59 3.81 2.24 4.59 2.24Z"
            let t = CGAffineTransform(a: 0.68596, b: 0, c: 0, d: 0.68596, tx: -0.04984, ty: 17.7918)
            return parseSVG(d, transform: t)
        case "chevron.backward":
            let d = "M1.50-8.46C1.50-8.17 1.61-7.91 1.83-7.69L11.12 1.39C11.32 1.61 11.58 1.71 11.88 1.71C12.49 1.71 12.96 1.25 12.96 0.64C12.96 0.34 12.83 0.08 12.64-0.12L4.11-8.46L12.64-16.80C12.83-17.00 12.96-17.27 12.96-17.57C12.96-18.18 12.49-18.63 11.88-18.63C11.58-18.63 11.32-18.53 11.12-18.33L1.83-9.23C1.61-9.02 1.50-8.75 1.50-8.46Z"
            let t = CGAffineTransform(a: 0.98310, b: 0, c: 0, d: 0.98310, tx: 4.89171, ty: 20.31797)
            return parseSVG(d, transform: t)
        case "arrow.left":
            let d = "M8.89-7.42L23.72-7.42C24.33-7.42 24.75-7.85 24.75-8.46C24.75-9.07 24.33-9.50 23.72-9.50L8.89-9.50L6.07-9.33L10.01-12.93L12.63-15.60C12.82-15.79 12.93-16.05 12.93-16.34C12.93-16.92 12.47-17.34 11.89-17.34C11.61-17.34 11.37-17.25 11.11-16.99L3.35-9.25C3.12-9.02 2.99-8.75 2.99-8.46C2.99-8.17 3.12-7.90 3.35-7.68L11.13 0.09C11.37 0.32 11.61 0.42 11.89 0.42C12.47 0.42 12.93 0 12.93-0.59C12.93-0.87 12.82-1.15 12.63-1.32L10.01-4.00L6.07-7.59Z"
            let t = CGAffineTransform(a: 0.91905, b: 0, c: 0, d: 0.91905, tx: -0.74637, ty: 19.77598)
            return parseSVG(d, transform: t)
        case "arrow.right":
            let d = "M4.02-7.42L18.84-7.42L21.67-7.59L17.73-4.00L15.11-1.32C14.92-1.15 14.82-0.87 14.82-0.59C14.82 0 15.27 0.42 15.84 0.42C16.13 0.42 16.37 0.32 16.61 0.09L24.40-7.68C24.63-7.90 24.75-8.17 24.75-8.46C24.75-8.75 24.63-9.02 24.40-9.25L16.63-16.99C16.37-17.25 16.13-17.34 15.84-17.34C15.27-17.34 14.82-16.92 14.82-16.34C14.82-16.05 14.92-15.79 15.11-15.60L17.73-12.93L21.67-9.33L18.84-9.50L4.02-9.50C3.41-9.50 2.99-9.07 2.99-8.46C2.99-7.85 3.41-7.42 4.02-7.42Z"
            let t = CGAffineTransform(a: 0.91905, b: 0, c: 0, d: 0.91905, tx: -0.74637, ty: 19.77598)
            return parseSVG(d, transform: t)
        default:
            return nil
        }
    }
    
    private static func parseSVG(_ d: String, transform: CGAffineTransform) -> UIBezierPath {
        let path = UIBezierPath()
        let scanner = Scanner(string: d)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: " ,")
        
        var currentPoint = CGPoint.zero
        var lastCommand: Character?
        
        while !scanner.isAtEnd {
            let startLoc = scanner.currentIndex
            
            // Only scan ONE character for the command to avoid swallowing "ZM" etc.
            let nextChar = String(d[scanner.currentIndex])
            let command: Character
            if CharacterSet.letters.contains(nextChar.unicodeScalars.first!) {
                command = nextChar.first!
                _ = scanner.scanCharacter()
            } else {
                command = lastCommand ?? " "
            }
            lastCommand = command
            
            func scanPoint() -> CGPoint {
                let x = CGFloat(scanner.scanDouble() ?? 0)
                let y = CGFloat(scanner.scanDouble() ?? 0)
                return CGPoint(x: x, y: y).applying(transform)
            }
            
            switch command {
            case "M", "m":
                currentPoint = scanPoint()
                path.move(to: currentPoint)
            case "L", "l":
                let next = scanPoint()
                path.addLine(to: next)
                currentPoint = next
            case "C", "c":
                let cp1 = scanPoint()
                let cp2 = scanPoint()
                let end = scanPoint()
                path.addCurve(to: end, controlPoint1: cp1, controlPoint2: cp2)
                currentPoint = end
            case "Z", "z":
                path.close()
            default:
                break
            }
            
            if scanner.currentIndex == startLoc && !scanner.isAtEnd {
                _ = scanner.scanCharacter()
            }
        }
        return path
    }
}

// MARK: - Pencil Overlay for UISegmentedControl

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
