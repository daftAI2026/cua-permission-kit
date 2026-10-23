// [INPUT]: 依赖 AppKit、SwiftUI 与包内视图协作。
// [OUTPUT]: 提供快照、显示时钟与富文本构建。
// [POS]: 授权向导表现层；不读写系统授权数据库。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit
import QuartzCore
import SwiftUI

// Both transition endpoints render their shared SwiftUI foreground, not a
// screenshot of the live material and shadow shell.
@MainActor
func permissionForegroundSnapshot<Content: View>(
    content: Content, size: NSSize, scale: CGFloat, appearance: NSAppearance,
    useHostingView: Bool = false
) -> NSImage? {
    guard scale.isFinite, scale > 0, scale <= 8 else { return nil }
    if #available(macOS 13.0, *), !useHostingView {
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale
        return renderer.nsImage
    }

    // The permission-card Button renders a forbidden-operation glyph when
    // ImageRenderer runs inside the interactive host. Use the same SwiftUI
    // foreground in an offscreen NSHostingView instead; this also covers 12.x.
    let snapshotHost = NSHostingView(rootView: content)
    snapshotHost.appearance = appearance
    snapshotHost.frame = NSRect(origin: .zero, size: size)
    snapshotHost.layoutSubtreeIfNeeded()
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(ceil(size.width * scale)),
        pixelsHigh: Int(ceil(size.height * scale)), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    bitmap.size = size
    snapshotHost.cacheDisplay(in: snapshotHost.bounds, to: bitmap)
    let image = NSImage(size: size)
    image.addRepresentation(bitmap)
    return image
}

// AppKit owns the host lifetime; TypeScript owns the externally sampled motion.
// Keep the concrete SwiftUI root alive across display ticks.
@MainActor
private final class PermissionFlightState: ObservableObject {
    @Published var source: NSImage?
    @Published var target: NSImage?
    @Published var progress: Double = 0
    @Published var cornerRadius: Double = 24
    @Published var reduceTransparency = false
}

private struct PermissionFlightImage: View {
    let image: NSImage?
    let opacity: Double
    let blurRadius: Double

    var body: some View {
        if let image {
            Image(nsImage: image)
                .interpolation(.high)
                .frame(width: image.size.width, height: image.size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .opacity(opacity)
                .blur(radius: blurRadius)
        }
    }
}

private struct PermissionFlightRoot: View {
    @ObservedObject var state: PermissionFlightState

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: state.cornerRadius, style: .continuous)
        // The helper image is larger than the card image. Its intrinsic size
        // must not grow the material and shared clip after Back shrinks the
        // AppKit surface to the card's current frame.
        GeometryReader { geometry in
            shape.fill(.regularMaterial)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .overlay {
                    ZStack {
                        PermissionFlightImage(
                            image: state.source,
                            opacity: 1 - state.progress,
                            blurRadius: state.reduceTransparency ? 0 : 12 * state.progress
                        )
                        PermissionFlightImage(
                            image: state.target,
                            opacity: state.progress,
                            blurRadius: state.reduceTransparency ? 0 : 12 * (1 - state.progress)
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(shape)
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// Only this non-generic ObjC surface crosses the existing objc-js bridge.
// Call on the AppKit main thread; Back already swaps images in TypeScript.
@MainActor
@objc(PCKPermissionFlightView)
public final class PCKPermissionFlightView: NSView {
    private let state: PermissionFlightState
    private let host: NSHostingView<PermissionFlightRoot>

    @objc public var flightProgress: Double { state.progress }
    @objc public var flightCornerRadius: Double { state.cornerRadius }

    public override init(frame frameRect: NSRect) {
        let state = PermissionFlightState()
        self.state = state
        host = NSHostingView(rootView: PermissionFlightRoot(state: state))
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        host.frame = bounds
        host.autoresizingMask = [.width, .height]
        addSubview(host)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("Use init(frame:)")
    }

    public override func layout() {
        super.layout()
        host.frame = bounds
    }

    public override func hitTest(_ point: NSPoint) -> NSView? { nil }

    @objc(setSourceImage:targetImage:)
    public func setSourceImage(_ source: NSImage?, targetImage: NSImage?) {
        withoutImplicitAnimation {
            state.source = source
            state.target = targetImage
        }
    }

    @objc(updateProgress:cornerRadius:reduceTransparency:)
    public func updateProgress(_ progress: Double, cornerRadius: Double, reduceTransparency: Bool) {
        guard progress.isFinite, cornerRadius.isFinite else { return }
        withoutImplicitAnimation {
            state.progress = min(1, max(0, progress))
            state.cornerRadius = max(0, cornerRadius)
            state.reduceTransparency = reduceTransparency
        }
    }

    private func withoutImplicitAnimation(_ update: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, update)
    }
}

// The reference animation engine is driven by AppKit's display link, not a
// wall-clock timer.  Keep this small bridge separate from the SwiftUI flight
// surface so TypeScript can retain the existing spring state and stop it
// deterministically when the owned panels close.
@MainActor
@objc(PCKPermissionDisplayLink)
public final class PCKPermissionDisplayLink: NSObject {
    private var link: AnyObject?
    private var handler: ((Double, Double, Double) -> Void)?

    @objc public private(set) var displayLinked = false

    @objc(startForWindow:handler:)
    public func start(for window: NSWindow, handler: ((Double, Double, Double) -> Void)?) {
        precondition(Thread.isMainThread, "Permission display link must run on the main thread")
        invalidate()
        guard #available(macOS 14.0, *), window.screen != nil else {
            displayLinked = false
            return
        }
        self.handler = handler
        let displayLink = window.displayLink(target: self, selector: #selector(displayLinkFired(_:)))
        displayLink.add(to: .current, forMode: .common)
        link = displayLink
        displayLinked = true
    }

    @objc(startForScreen:handler:)
    public func start(for screen: NSScreen, handler: ((Double, Double, Double) -> Void)?) {
        precondition(Thread.isMainThread, "Permission display link must run on the main thread")
        invalidate()
        guard #available(macOS 14.0, *) else {
            displayLinked = false
            return
        }
        self.handler = handler
        let displayLink = screen.displayLink(target: self, selector: #selector(displayLinkFired(_:)))
        displayLink.add(to: .current, forMode: .common)
        link = displayLink
        displayLinked = true
    }

    @objc public func invalidate() {
        if #available(macOS 14.0, *) {
            (link as? CADisplayLink)?.invalidate()
        }
        link = nil
        handler = nil
        displayLinked = false
    }

    @available(macOS 14.0, *)
    @objc private func displayLinkFired(_ displayLink: CADisplayLink) {
        handler?(displayLink.timestamp, displayLink.duration, displayLink.targetTimestamp)
    }
}

func permissionCopyString(_ copy: NSDictionary, _ key: String) -> String {
    if let value = copy.object(forKey: key) as? String { return value }
    if let value = copy.object(forKey: key) as? NSString { return value as String }
    return ""
}

var permissionBackFill: Color {
    if #available(macOS 14.0, *) {
        return Color(nsColor: .tertiarySystemFill)
    }
    // The original semantic fill API is unavailable on macOS 12/13.
    // Preserve the previous SwiftUI fill there; those OS versions do not
    // claim pixel parity with the macOS 14+ reference.
    return Color.primary.opacity(0.08)
}

private struct PermissionInstructionRun: Decodable {
    enum Role: String, Decodable { case primary, secondary }
    let text: String
    let role: Role
}

// Localized copy supplies semantic runs in its own natural order. Never
// infer names or word boundaries from English substrings in the renderer.
func permissionStyledInstruction(_ text: String, runsJSON: String) -> AttributedString {
    guard runsJSON.utf8.count <= 65_536,
          let data = runsJSON.data(using: .utf8),
          let runs = try? JSONDecoder().decode([PermissionInstructionRun].self, from: data),
          !runs.isEmpty, runs.count <= 128,
          runs.map(\.text).joined() == text else {
        return AttributedString(text)
    }
    var result = AttributedString()
    for run in runs {
        var part = AttributedString(run.text)
        part.foregroundColor = run.role == .primary ? Color.primary : Color.secondary
        result.append(part)
    }
    return result
}


// 单卡保留 Return；双卡只让下一项接收默认快捷键。
extension View {
    @ViewBuilder
    func keyboardShortcutIfDefault(_ enabled: Bool) -> some View {
        if enabled { keyboardShortcut(.defaultAction) }
        else { self }
    }
}
