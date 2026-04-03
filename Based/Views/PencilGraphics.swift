import UIKit

extension UIBezierPath {
    /// Creates a "rough" hand-drawn path between two points.
    static func pencilLine(from start: CGPoint, to end: CGPoint, jitter: CGFloat = 0.6) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: start)
        
        let distance = hypot(end.x - start.x, end.y - start.y)
        guard distance.isFinite && distance > 0 else { return path }
        
        let segments = max(3, Int(distance / 10))
        
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            
            if i == segments {
                path.addLine(to: end)
            } else {
                let offX = CGFloat.random(in: -jitter...jitter)
                let offY = CGFloat.random(in: -jitter...jitter)
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

    /// Creates a dense back-and-forth scribble shading effect.
    static func pencilScribble(in rect: CGRect, jitter: CGFloat = 1.0) -> UIBezierPath {
        let path = UIBezierPath()
        guard rect.width.isFinite && rect.width > 2 && rect.height.isFinite && rect.height > 2 else { return path }
        
        let spacing: CGFloat = 1.5
        let totalWidth = rect.width + rect.height
        let steps = Int(totalWidth / spacing)
        
        for i in 0...steps {
            let offset = CGFloat(i) * spacing
            let start = CGPoint(x: rect.minX + offset - rect.height, y: rect.maxY)
            let end = CGPoint(x: rect.minX + offset, y: rect.minY)
            
            let cs = CGPoint(x: max(rect.minX, min(rect.maxX, start.x)), y: max(rect.minY, min(rect.maxY, start.y)))
            let ce = CGPoint(x: max(rect.minX, min(rect.maxX, end.x)), y: max(rect.minY, min(rect.maxY, end.y)))
            
            if cs != ce {
                path.move(to: cs)
                let mid = CGPoint(x: (cs.x + ce.x)/2 + CGFloat.random(in: -jitter...jitter),
                                 y: (cs.y + ce.y)/2 + CGFloat.random(in: -jitter...jitter))
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
        
        for _ in 0..<Int(size.width * size.height * density) {
            let startX = CGFloat.random(in: -5...size.width)
            let startY = CGFloat.random(in: -5...size.height)
            let length = CGFloat.random(in: 4...12)
            let angle = CGFloat.pi / 4 + CGFloat.random(in: -0.2...0.2)
            
            let endX = startX + length * cos(angle)
            let endY = startY + length * sin(angle)
            
            let alpha = CGFloat.random(in: 0.05...0.25)
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

// MARK: - Overhauled Custom Pencil Segmented Control

class PencilSegmentedControl: UIControl {
    private var items: [String] = []
    var selectedIndex: Int = 0 {
        didSet {
            updateSelectedState(animated: true)
            sendActions(for: .valueChanged)
        }
    }
    
    private let containerView = UIView()
    private let selectionView = UIView()
    private let selectionScribble = UIView()
    
    private let containerBorder = CAShapeLayer()
    private let selectionBorder = CAShapeLayer()
    private let selectionMask = CAShapeLayer()
    
    private let stackView = UIStackView()
    private var buttons: [UIButton] = []
    
    private let pencilColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
    private let headerFont = "PermanentMarker-Regular"
    
    init(items: [String]) {
        super.init(frame: .zero)
        self.items = items
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // Main container box - matches system picker feel
        containerView.isUserInteractionEnabled = false
        containerView.backgroundColor = UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 0.5)
        containerView.layer.addSublayer(containerBorder)
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Sliding selection highlight
        selectionView.isUserInteractionEnabled = false
        selectionView.layer.addSublayer(selectionBorder)
        selectionView.layer.mask = selectionMask
        
        selectionScribble.backgroundColor = UIColor(patternImage: UIImage.pencilTexture(color: .darkGray, density: 0.25))
        selectionScribble.alpha = 0.7
        selectionView.addSubview(selectionScribble)
        selectionScribble.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(selectionView)
        
        // Buttons
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            selectionScribble.topAnchor.constraint(equalTo: selectionView.topAnchor),
            selectionScribble.leadingAnchor.constraint(equalTo: selectionView.leadingAnchor),
            selectionScribble.trailingAnchor.constraint(equalTo: selectionView.trailingAnchor),
            selectionScribble.bottomAnchor.constraint(equalTo: selectionView.bottomAnchor)
        ])
        
        for (index, title) in items.enumerated() {
            let btn = UIButton(type: .custom)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = UIFont(name: headerFont, size: 16)
            btn.setTitleColor(pencilColor.withAlphaComponent(0.6), for: .normal)
            btn.setTitleColor(pencilColor, for: .selected)
            btn.tag = index
            btn.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(btn)
            buttons.append(btn)
        }
        
        updateSelectedState(animated: false)
    }
    
    @objc private func buttonTapped(_ sender: UIButton) {
        selectedIndex = sender.tag
    }
    
    private func updateSelectedState(animated: Bool) {
        let work = {
            for (index, btn) in self.buttons.enumerated() {
                btn.isSelected = (index == self.selectedIndex)
            }
            self.layoutSelection()
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.beginFromCurrentState], animations: work)
        } else {
            work()
        }
    }
    
    private func layoutSelection() {
        guard selectedIndex < buttons.count else { return }
        let selectedBtn = buttons[selectedIndex]
        
        // Update selection frame to match button exactly
        selectionView.frame = selectedBtn.frame.insetBy(dx: 4, dy: 4)
        
        // Update paths for the new size
        selectionMask.path = UIBezierPath.pencilRoughRect(rect: selectionView.bounds, jitter: 1.5).cgPath
        selectionBorder.path = UIBezierPath.pencilRoughRect(rect: selectionView.bounds, jitter: 1.5).cgPath
        selectionBorder.strokeColor = pencilColor.withAlphaComponent(0.4).cgColor
        selectionBorder.fillColor = UIColor.clear.cgColor
        selectionBorder.lineWidth = 1.0
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Container border
        containerBorder.path = UIBezierPath.pencilRoughRect(rect: containerView.bounds, jitter: 1.0).cgPath
        containerBorder.strokeColor = pencilColor.withAlphaComponent(0.3).cgColor
        containerBorder.fillColor = UIColor.clear.cgColor
        containerBorder.lineWidth = 1.0
        
        layoutSelection()
    }
    
    func setTitle(_ title: String, forSegmentAt index: Int) {
        guard index < buttons.count else { return }
        buttons[index].setTitle(title, for: .normal)
    }
}
