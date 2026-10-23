// [INPUT]: 依赖 AppKit、SwiftUI 与包内视图协作。
// [OUTPUT]: 提供弹簧插值与跨窗口动画。
// [POS]: 授权向导表现层；不读写系统授权数据库。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit
import QuartzCore

// Extracted reference spring integrator. Keep the native
// host's window ownership separate from the unchanged SwiftUI flight surface.
struct PermissionHostSpring {
    var value = 0.0
    var target = 1.0
    var velocity = 0.0
    var force = 0.0
    var time = 0.0
    var settled = false

    mutating func advance(to targetTime: Double) -> Double {
        guard !settled, targetTime.isFinite, targetTime > time else { return value }
        let dt = 1.0 / 240, halfStep = dt / 2
        let stiffness = min(pow(2 * Double.pi / 0.72, 2), 28800)
        let drag = 2 * sqrt(stiffness)
        if targetTime - time > 1 { time = targetTime - 1 / 60 }
        while time < targetTime {
            let halfVelocity = velocity + force * halfStep
            value += halfVelocity * dt
            force = stiffness * (target - value) - drag * halfVelocity
            velocity = halfVelocity + force * halfStep
            time += dt
        }
        let velocitySquared = velocity * velocity, forceSquared = force * force
        let metric = velocitySquared < forceSquared ? forceSquared : velocitySquared
        let tolerance = pow(target * 0.01, 2), distance = pow(target - value, 2)
        if !(metric > 0.06 * 0.06) && (!(tolerance > 0) || !(distance > tolerance)) {
            value = target
            settled = true
        }
        return value
    }
}

struct PermissionHostFlightSample {
    let progress: Double
    let bounds: CGRect
    let cornerRadius: Double
}

func permissionHostFlightSample(source: CGRect, sourceRadius: Double, target: CGRect, targetRadius: Double, progress: Double) -> PermissionHostFlightSample {
    let p = max(0, min(1, progress))
    func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * p }
    let fromX = Double(source.midX), fromY = Double(source.midY)
    let toX = Double(target.midX), toY = Double(target.midY)
    let apex = min(fromY, toY) - 50
    let controlY = 2 * apex - (fromY + toY) / 2
    let centerY = (1 - p) * (1 - p) * fromY + 2 * (1 - p) * p * controlY + p * p * toY
    let width = lerp(source.width, target.width), height = lerp(source.height, target.height)
    return PermissionHostFlightSample(progress: p, bounds: CGRect(x: lerp(fromX, toX) - width / 2, y: centerY - height / 2, width: width, height: height), cornerRadius: lerp(sourceRadius, targetRadius))
}

@MainActor
struct PermissionHostFlightEndpoint {
    var view: NSView
    var frame: NSRect
    var radius: CGFloat
    var image: NSImage?
    var captureImage: (() -> NSImage?)?

    init(view: NSView, frame: NSRect, radius: CGFloat = 12, image: NSImage? = nil, captureImage: (() -> NSImage?)? = nil) {
        self.view = view; self.frame = frame; self.radius = radius
        self.image = image; self.captureImage = captureImage
    }
}

@MainActor
final class PermissionHostFlight {
    @MainActor private final class Entry {
        let panel: NSPanel
        let screenFrame: NSRect
        let contentView: NSView
        let root: NSView
        let surface: PCKPermissionFlightView
        let strokeView: NSView
        let stroke = CAShapeLayer()
        var shadows: [CALayer] = []
        var masks: [CAShapeLayer] = []
        var shown = false

        init(screen: NSScreen, source: NSImage, target: NSImage) {
            let scale = screen.backingScaleFactor
            func align(_ value: CGFloat) -> CGFloat { (value * scale).rounded(.toNearestOrAwayFromZero) / scale }
            let raw = screen.frame
            screenFrame = NSRect(x: align(raw.minX), y: align(raw.minY), width: max(0, align(raw.maxX) - align(raw.minX)), height: max(0, align(raw.maxY) - align(raw.minY)))
            panel = NSPanel(contentRect: screenFrame, styleMask: [.nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.ignoresMouseEvents = true; panel.level = NSWindow.Level(rawValue: 25)
            panel.hidesOnDeactivate = false
            panel.animationBehavior = .none
            panel.collectionBehavior = NSWindow.CollectionBehavior(rawValue: 0x1149)
            contentView = NSView(frame: NSRect(origin: .zero, size: screenFrame.size))
            contentView.wantsLayer = true
            panel.contentView = contentView
            root = NSView(frame: .zero)
            root.wantsLayer = true; root.layer?.masksToBounds = false
            contentView.addSubview(root)
            surface = PCKPermissionFlightView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
            surface.wantsLayer = true; surface.layer?.contentsScale = scale
            surface.layer?.masksToBounds = false
            for (opacity, radius, y) in [(Float(0.06), CGFloat(2), CGFloat(-3)), (0.09, 15, -5), (0.2, 3, 0)] {
                let layer = CALayer()
                layer.shadowColor = NSColor.black.cgColor
                layer.shadowOpacity = opacity; layer.shadowRadius = radius
                layer.shadowOffset = CGSize(width: 0, height: y); layer.masksToBounds = false
                let mask = CAShapeLayer(); mask.fillRule = .evenOdd; mask.fillColor = NSColor.white.cgColor
                layer.mask = mask; shadows.append(layer); masks.append(mask)
                root.layer?.addSublayer(layer)
            }
            surface.setSourceImage(source, targetImage: target)
            root.addSubview(surface)
            strokeView = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
            strokeView.wantsLayer = true; strokeView.layer?.masksToBounds = false
            stroke.lineWidth = 0.5; stroke.strokeColor = NSColor.black.cgColor
            stroke.fillColor = NSColor.clear.cgColor; stroke.opacity = 0
            strokeView.layer?.addSublayer(stroke); root.addSubview(strokeView)
        }

        func close() {
            surface.setSourceImage(nil, targetImage: nil)
            panel.orderOut(nil); panel.close()
        }
    }

    private let source: PermissionHostFlightEndpoint
    private let target: () -> PermissionHostFlightEndpoint
    private let reverse: Bool
    private let isClosed: () -> Bool
    private let onComplete: () -> Void
    private let onError: (String) -> Void
    private let clock = PCKPermissionDisplayLink()
    private var entries: [Entry] = []
    private var images: (NSImage, NSImage)?
    private var initialTarget: PermissionHostFlightEndpoint?
    private var topology = ""
    private var spring = PermissionHostSpring()
    private var timer: Timer?
    private var displayOrigin: Double?
    private var lastDisplayTimestamp: Double?
    private var startTime = 0.0
    private var started = false
    private var disposed = false
    private var usesDisplayClock = false
    private var reduceTransparency = false

    init(source: PermissionHostFlightEndpoint, target: @escaping () -> PermissionHostFlightEndpoint, reverse: Bool = false, isClosed: @escaping () -> Bool, onComplete: @escaping () -> Void, onError: @escaping (String) -> Void) {
        self.source = source; self.target = target; self.reverse = reverse
        self.isClosed = isClosed; self.onComplete = onComplete; self.onError = onError
    }

    func start() {
        guard !started, !disposed else { return }
        started = true
        if isClosed() || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { dispose(); return }
        let destination = target()
        initialTarget = destination
        let targetImage: NSImage?
        if let capture = destination.captureImage { targetImage = capture() }
        else { targetImage = Self.snapshot(destination.view) }
        guard let sourceImage = source.image, let targetImage else {
            onError("Native permission foreground snapshot is unavailable"); dispose(); return
        }
        images = reverse ? (targetImage, sourceImage) : (sourceImage, targetImage)
        reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        startTime = CACurrentMediaTime()
        rebuild()
        tick(nil)
        guard !disposed else { return }
        if !startDisplayClock() {
            let fallback = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick(nil) }
            }
            timer = fallback
            RunLoop.main.add(fallback, forMode: .common)
        }
    }

    func dispose() {
        guard !disposed else { return }
        disposed = true
        timer?.invalidate(); timer = nil
        clock.invalidate(); usesDisplayClock = false
        entries.forEach { $0.close() }; entries.removeAll(); images = nil
        onComplete()
    }

    private static func snapshot(_ view: NSView) -> NSImage? {
        view.displayIfNeeded()
        guard view.bounds.width > 0, view.bounds.height > 0,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let image = NSImage(size: view.bounds.size); image.addRepresentation(bitmap)
        return image
    }

    private func screenKey() -> String {
        NSScreen.screens.map { "\($0.frame)@\($0.backingScaleFactor)" }.joined(separator: ";")
    }

    private func rebuild() {
        clock.invalidate()
        entries.forEach { $0.close() }; entries.removeAll()
        guard let images else { return }
        entries = NSScreen.screens.map { Entry(screen: $0, source: images.0, target: images.1) }
        topology = screenKey()
    }

    @discardableResult private func startDisplayClock() -> Bool {
        let callback: (Double, Double, Double) -> Void = { [weak self] timestamp, _, _ in self?.tick(timestamp) }
        if let panel = entries.first?.panel { clock.start(for: panel, handler: callback) }
        if !clock.displayLinked, let screen = NSScreen.main { clock.start(for: screen, handler: callback) }
        usesDisplayClock = clock.displayLinked
        return usesDisplayClock
    }

    private func tick(_ displayTimestamp: Double?) {
        guard !disposed else { return }
        if isClosed() { dispose(); return }
        var elapsed = CACurrentMediaTime() - startTime
        if let timestamp = displayTimestamp {
            guard timestamp.isFinite else { return }
            guard let origin = displayOrigin else {
                displayOrigin = timestamp; lastDisplayTimestamp = timestamp; return
            }
            guard timestamp > (lastDisplayTimestamp ?? timestamp) else { return }
            lastDisplayTimestamp = timestamp; elapsed = timestamp - origin
        }
        guard let initialTarget else { dispose(); return }
        let from = reverse ? initialTarget : source
        let to = reverse ? source : target()
        func flip(_ rect: NSRect) -> NSRect { NSRect(x: rect.minX, y: -rect.minY - rect.height, width: rect.width, height: rect.height) }
        let sample = permissionHostFlightSample(source: flip(from.frame), sourceRadius: from.radius, target: flip(to.frame), targetRadius: to.radius, progress: spring.advance(to: elapsed))
        let bounds = NSRect(x: sample.bounds.minX, y: -sample.bounds.minY - sample.bounds.height, width: sample.bounds.width, height: sample.bounds.height)
        render(sample, bounds: bounds)
        if sample.progress == 1 { dispose() }
    }

    private func render(_ sample: PermissionHostFlightSample, bounds: NSRect) {
        let relink = usesDisplayClock
        if topology != screenKey() { rebuild() }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for entry in entries {
            let global = bounds.integral
            let local = NSRect(x: global.minX - entry.screenFrame.minX, y: global.minY - entry.screenFrame.minY, width: global.width, height: global.height).integral
            let inner = NSRect(x: 30, y: 30, width: local.width, height: local.height)
            let outer = NSRect(x: 0, y: 0, width: local.width + 60, height: local.height + 60)
            entry.root.frame = NSRect(x: local.minX - 30, y: local.minY - 30, width: outer.width, height: outer.height)
            entry.root.layer?.cornerRadius = sample.cornerRadius
            entry.surface.frame = inner
            entry.surface.layer?.cornerRadius = sample.cornerRadius
            entry.surface.updateProgress(sample.progress, cornerRadius: sample.cornerRadius, reduceTransparency: reduceTransparency)
            entry.strokeView.frame = inner
            entry.strokeView.layer?.cornerRadius = sample.cornerRadius
            entry.stroke.frame = NSRect(origin: .zero, size: local.size)
            entry.stroke.opacity = Float(0.15 * sample.progress)
            let strokeRadius = max(0, sample.cornerRadius - 0.25)
            entry.stroke.path = CGPath(roundedRect: NSRect(x: 0.25, y: 0.25, width: max(0, local.width - 0.5), height: max(0, local.height - 0.5)), cornerWidth: strokeRadius, cornerHeight: strokeRadius, transform: nil)
            for index in entry.shadows.indices {
                entry.shadows[index].frame = outer; entry.masks[index].frame = outer
                entry.shadows[index].shadowPath = CGPath(roundedRect: inner, cornerWidth: sample.cornerRadius, cornerHeight: sample.cornerRadius, transform: nil)
                let mask = CGMutablePath(); mask.addRect(outer)
                mask.addRoundedRect(in: inner, cornerWidth: sample.cornerRadius, cornerHeight: sample.cornerRadius)
                entry.masks[index].path = mask
            }
            entry.shadows[0].opacity = Float(sample.progress)
        }
        CATransaction.commit()
        for entry in entries where !entry.shown { entry.panel.orderFront(nil); entry.shown = true }
        if relink && !clock.displayLinked { startDisplayClock() }
    }
}
