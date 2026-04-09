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
        case "gear":
            let d = "M15.05 2.74C15.34 2.74 15.62 2.73 15.90 2.71L16.55 3.91C16.70 4.22 16.97 4.34 17.30 4.30C17.64 4.24 17.84 4.02 17.87 3.69L18.07 2.33C18.63 2.18 19.16 1.98 19.68 1.75L20.68 2.66C20.93 2.89 21.23 2.91 21.53 2.75C21.82 2.59 21.94 2.31 21.87 1.98L21.57 0.64C22.04 0.32 22.48-0.06 22.89-0.45L24.14 0.07C24.46 0.19 24.75 0.12 24.97-0.14C25.20-0.40 25.22-0.69 25.03-0.98L24.30-2.13C24.62-2.61 24.90-3.11 25.16-3.61L26.51-3.56C26.85-3.55 27.11-3.71 27.22-4.04C27.34-4.35 27.26-4.64 26.99-4.84L25.90-5.67C26.05-6.22 26.14-6.79 26.20-7.37L27.49-7.78C27.82-7.89 28.01-8.12 28.01-8.46C28.01-8.80 27.82-9.05 27.49-9.14L26.20-9.55C26.14-10.14 26.05-10.70 25.90-11.25L26.98-12.08C27.26-12.28 27.33-12.57 27.22-12.89C27.11-13.22 26.85-13.37 26.51-13.36L25.16-13.32C24.90-13.83 24.62-14.33 24.30-14.80L25.02-15.94C25.21-16.23 25.18-16.54 24.98-16.79C24.75-17.05 24.46-17.11 24.15-16.99L22.89-16.48C22.48-16.89 22.03-17.25 21.57-17.58L21.87-18.90C21.94-19.24 21.82-19.51 21.54-19.68C21.23-19.85 20.93-19.80 20.68-19.58L19.66-18.68C19.16-18.91 18.62-19.10 18.06-19.27L17.87-20.61C17.84-20.94 17.63-21.15 17.31-21.22C16.97-21.28 16.70-21.14 16.55-20.85L15.90-19.64C15.62-19.65 15.34-19.66 15.05-19.66C14.77-19.66 14.48-19.65 14.19-19.64L13.56-20.84C13.39-21.14 13.13-21.27 12.81-21.22C12.47-21.16 12.27-20.94 12.22-20.61L12.02-19.27C11.47-19.10 10.93-18.90 10.42-18.67L9.42-19.58C9.18-19.82 8.87-19.84 8.57-19.68C8.27-19.51 8.17-19.23 8.24-18.90L8.52-17.57C8.05-17.24 7.62-16.88 7.21-16.48L5.95-16.99C5.65-17.12 5.34-17.04 5.12-16.78C4.90-16.54 4.89-16.23 5.07-15.94L5.80-14.79C5.47-14.32 5.19-13.82 4.95-13.31L3.60-13.36C3.25-13.38 3-13.21 2.88-12.89C2.75-12.57 2.85-12.28 3.12-12.08L4.20-11.25C4.05-10.70 3.95-10.14 3.90-9.55L2.60-9.14C2.27-9.05 2.10-8.80 2.10-8.46C2.10-8.12 2.27-7.89 2.60-7.78L3.90-7.37C3.95-6.79 4.05-6.22 4.20-5.67L3.12-4.84C2.85-4.64 2.78-4.35 2.87-4.03C3-3.70 3.25-3.55 3.59-3.56L4.95-3.61C5.19-3.09 5.47-2.60 5.80-2.12L5.07-0.98C4.89-0.69 4.92-0.39 5.12-0.14C5.36 0.13 5.65 0.19 5.95 0.07L7.21-0.46C7.62-0.05 8.06 0.32 8.52 0.66L8.24 1.98C8.17 2.31 8.29 2.59 8.57 2.75C8.87 2.93 9.18 2.89 9.41 2.66L10.43 1.75C10.95 1.99 11.48 2.18 12.04 2.33L12.22 3.68C12.27 4.02 12.48 4.23 12.80 4.30C13.14 4.36 13.39 4.22 13.56 3.91L14.19 2.71C14.48 2.73 14.77 2.74 15.05 2.74ZM15.06-11.53C14.77-11.53 14.48-11.50 14.23-11.43L11.07-16.83C12.28-17.40 13.63-17.72 15.05-17.72C19.89-17.72 23.86-14.02 24.27-9.28L18.01-9.28C17.66-10.58 16.46-11.53 15.06-11.53ZM5.79-8.46C5.79-11.57 7.31-14.31 9.64-15.98L12.82-10.57C12.30-10.02 11.99-9.28 11.99-8.46C11.99-7.64 12.32-6.88 12.84-6.33L9.57-0.98C7.28-2.67 5.79-5.39 5.79-8.46ZM15.06-7.15C14.33-7.15 13.75-7.73 13.75-8.46C13.75-9.19 14.33-9.77 15.06-9.77C15.79-9.77 16.37-9.19 16.37-8.46C16.37-7.73 15.79-7.15 15.06-7.15ZM15.05 0.80C13.59 0.80 12.22 0.46 10.99-0.14L14.25-5.50C14.51-5.43 14.78-5.39 15.06-5.39C16.48-5.39 17.67-6.35 18.02-7.66L24.28-7.66C23.87-2.92 19.90 0.80 15.05 0.80Z"
            let t = CGAffineTransform(a: 0.7718980853309212, b: 0, c: 0, d: 0.7718980853309212, tx: 0.38082315694255975, ty: 18.530996525145106)
            return parseSVG(d, transform: t)
        case "baseball":
            let d = "M14.05 3.49C20.65 3.49 26.00-1.86 26.00-8.46C26.00-15.06 20.65-20.41 14.05-20.41C7.45-20.41 2.10-15.06 2.10-8.46C2.10-1.86 7.45 3.49 14.05 3.49ZM14.05 1.90C13.61 1.90 13.17 1.88 12.74 1.82C12.91 1.15 13.02 0.46 13.08-0.23L13.63-0.22C13.93-0.21 14.17-0.46 14.17-0.75C14.18-1.03 13.95-1.28 13.65-1.29L13.11-1.30C13.10-2.03 13.03-2.75 12.88-3.47L13.41-3.60C13.69-3.68 13.85-3.97 13.78-4.25C13.70-4.55 13.43-4.72 13.13-4.64L12.62-4.51C12.42-5.21 12.14-5.91 11.80-6.57L12.30-6.86C12.59-7.01 12.66-7.34 12.50-7.58C12.35-7.84 12.04-7.95 11.78-7.79L11.26-7.50C10.83-8.17 10.35-8.77 9.82-9.32L10.25-9.76C10.48-9.98 10.46-10.31 10.25-10.50C10.04-10.72 9.71-10.75 9.49-10.52L9.04-10.07C8.52-10.51 7.97-10.91 7.38-11.26L7.62-11.70C7.76-11.95 7.68-12.27 7.42-12.40C7.15-12.55 6.82-12.48 6.68-12.21L6.43-11.77C5.81-12.07 5.17-12.32 4.51-12.52C6.09-16.22 9.77-18.82 14.05-18.82C14.47-18.82 14.88-18.80 15.28-18.75C15.12-18.07 15.01-17.39 14.95-16.69L14.44-16.71C14.13-16.70 13.90-16.46 13.90-16.16C13.89-15.87 14.11-15.63 14.41-15.63L14.93-15.62C14.94-14.93 15.01-14.25 15.14-13.57L14.50-13.41C14.19-13.32 14.05-13.03 14.14-12.75C14.19-12.46 14.47-12.29 14.77-12.38L15.39-12.53C15.60-11.80 15.88-11.07 16.24-10.38L15.73-10.09C15.47-9.95 15.40-9.62 15.55-9.36C15.67-9.12 16.00-9 16.25-9.16L16.78-9.46C17.19-8.81 17.65-8.23 18.16-7.69L17.80-7.32C17.59-7.13 17.60-6.79 17.82-6.59C18.02-6.39 18.35-6.38 18.56-6.59L18.94-6.95C19.49-6.47 20.07-6.05 20.70-5.68L20.45-5.23C20.30-4.97 20.39-4.64 20.65-4.50C20.89-4.36 21.25-4.44 21.38-4.71L21.63-5.18C22.27-4.88 22.92-4.63 23.60-4.43C22.02-0.71 18.34 1.90 14.05 1.90ZM18.21-10.28C18.48-10.43 18.55-10.72 18.41-11.00C18.27-11.25 17.95-11.37 17.70-11.20L17.32-10.99C17.00-11.59 16.76-12.21 16.57-12.83L16.95-12.93C17.24-13.01 17.40-13.29 17.31-13.57C17.25-13.86 16.97-14.04 16.68-13.96L16.32-13.88C16.21-14.44 16.15-15.01 16.13-15.59L16.66-15.57C16.97-15.56 17.19-15.79 17.19-16.09C17.20-16.38 16.97-16.63 16.68-16.64L16.15-16.65C16.20-17.30 16.29-17.93 16.44-18.54C21.01-17.46 24.41-13.36 24.41-8.46C24.41-7.45 24.27-6.47 23.99-5.54C23.38-5.72 22.78-5.94 22.21-6.22L22.45-6.67C22.61-6.94 22.50-7.24 22.24-7.41C21.98-7.54 21.66-7.45 21.53-7.20L21.27-6.73C20.75-7.04 20.25-7.41 19.79-7.82L20.14-8.17C20.37-8.40 20.36-8.73 20.13-8.94C19.93-9.14 19.59-9.15 19.38-8.93L19.02-8.57C18.60-9.02 18.20-9.53 17.85-10.07ZM11.39-0.28L11.88-0.27C11.84 0.36 11.73 0.98 11.58 1.61C7.05 0.49 3.69-3.60 3.69-8.46C3.69-9.48 3.84-10.46 4.11-11.40C4.71-11.23 5.31-11.00 5.87-10.72L5.61-10.24C5.46-9.97 5.55-9.64 5.82-9.52C6.08-9.36 6.39-9.45 6.54-9.71L6.81-10.21C7.29-9.90 7.75-9.56 8.18-9.19L7.92-8.92C7.70-8.71 7.71-8.36 7.93-8.17C8.14-7.96 8.46-7.95 8.68-8.16L8.96-8.45C9.41-7.98 9.81-7.45 10.17-6.90L9.82-6.70C9.55-6.55 9.47-6.21 9.63-5.96C9.79-5.71 10.08-5.61 10.35-5.75L10.71-5.96C11.02-5.39 11.25-4.80 11.44-4.21L10.96-4.08C10.66-4.01 10.50-3.71 10.57-3.43C10.65-3.14 10.93-2.96 11.23-3.04L11.71-3.16C11.82-2.55 11.89-1.95 11.91-1.34L11.41-1.35C11.11-1.36 10.88-1.11 10.86-0.82C10.86-0.53 11.10-0.29 11.39-0.28Z"
            let t = CGAffineTransform(a: 0.8366013071895425, b: 0, c: 0, d: 0.8366013071895425, tx: 0.2450980392156863, ty: 19.07843137254902)
            return parseSVG(d, transform: t)
        case "xmark":
            // Crossing rectangles for a "bold" filled X
            let path = UIBezierPath()
            // Bar 1
            path.move(to: CGPoint(x: 4, y: 6))
            path.addLine(to: CGPoint(x: 6, y: 4))
            path.addLine(to: CGPoint(x: 20, y: 18))
            path.addLine(to: CGPoint(x: 18, y: 20))
            path.close()
            // Bar 2
            path.move(to: CGPoint(x: 18, y: 4))
            path.addLine(to: CGPoint(x: 20, y: 6))
            path.addLine(to: CGPoint(x: 6, y: 20))
            path.addLine(to: CGPoint(x: 4, y: 18))
            path.close()
            return path
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

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: PencilSegmentedOverlay, _) in
            self.lastRenderedIndex = -1
            self.setNeedsLayout()
        }
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

// MARK: - Pencil Background for TableView Sections

class PencilSectionBackgroundView: UIView {
    enum Position {
        case top, middle, bottom, single
    }
    
    var position: Position = .single {
        didSet { setNeedsLayout() }
    }
    
    private let borderLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 1.2
        borderLayer.lineCap = .round
        layer.addSublayer(borderLayer)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: PencilSectionBackgroundView, _) in
            self.updatePath()
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updatePath()
    }
    
    private func updatePath() {
        let path = UIBezierPath()
        let b = bounds.insetBy(dx: 1, dy: 0) // Slight inset to avoid clipping
        let jitter: CGFloat = 0.8
        
        let tl = CGPoint(x: b.minX, y: b.minY)
        let tr = CGPoint(x: b.maxX, y: b.minY)
        let bl = CGPoint(x: b.minX, y: b.maxY)
        let br = CGPoint(x: b.maxX, y: b.maxY)
        
        switch position {
        case .top:
            path.append(.pencilLine(from: bl, to: tl, jitter: jitter))
            path.append(.pencilLine(from: tl, to: tr, jitter: jitter))
            path.append(.pencilLine(from: tr, to: br, jitter: jitter))
        case .middle:
            path.append(.pencilLine(from: bl, to: tl, jitter: jitter))
            path.append(.pencilLine(from: tr, to: br, jitter: jitter))
        case .bottom:
            path.append(.pencilLine(from: tl, to: bl, jitter: jitter))
            path.append(.pencilLine(from: bl, to: br, jitter: jitter))
            path.append(.pencilLine(from: br, to: tr, jitter: jitter))
        case .single:
            path.append(.pencilRoughRect(rect: b, jitter: jitter))
        }
        
        borderLayer.path = path.cgPath
        borderLayer.strokeColor = AppColors.pencil.withAlphaComponent(0.4).cgColor
    }
    
}
