// [INPUT]: 依赖 AppKit、SwiftUI 与包内视图协作。
// [OUTPUT]: 提供向导状态入口、窗口生命周期与事件回调。
// [POS]: 授权向导表现层；不读写系统授权数据库。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit
import Foundation
import UniformTypeIdentifiers
@MainActor
public final class PermissionPresenter: NSObject {
    let configuration: PermissionConfiguration
    var copy: NSDictionary
    let layoutDirection: String
    let onEvent: (String) -> Void
    let onError: (String) -> Void
    lazy var actionTarget = PermissionHostActionTarget(owner: self)

    var initialPanel: NSWindow?
    var initialView: PCKPermissionInitialView?
    var cardView: NSView?
    var helperPanel: NSPanel?
    var helperView: PCKPermissionHelperView?
    var appRowView: NSView?
    var dragView: PermissionHostDragView?
    var dragSession: NSDraggingSession?
    var terminalDragPanel: NSPanel?
    var terminalDragSession: NSDraggingSession?
    var arrowPanel: NSPanel?
    var arrowView: PCKPermissionArrowView?
    var arrowTracker: PermissionHostArrowTrackerView?
    var initialDelegate: PermissionHostWindowDelegate?
    var helperDelegate: PermissionHostWindowDelegate?
    var arrowDelegate: PermissionHostWindowDelegate?
    var trackingTimer: Timer?
    var arrowTimer: Timer?
    var arrowReturnTimer: Timer?
    var backFlightTimer: Timer?
    var flight: PermissionHostFlight?
    var sourceEndpoint: PermissionHostFlightEndpoint?
    var state = "pending"
    var closed = false
    var presented = false
    var settled = false
    var retryReady = false
    public private(set) var activePermission: PermissionKind
    var grantedPermissions: Set<PermissionKind> = []
    var completionRequested = false
    var returnRequested = false
    var returning = false
    var dragging = false
    var locatingAttempts = 0
    var forwardSequence = 0
    var returnSequence = 0

    public init(
        configuration: PermissionConfiguration,
        onEvent: @escaping (PermissionEvent) -> Void,
        onError: @escaping (String) -> Void,
    ) {
        self.activePermission = configuration.permissions[0]
        self.configuration = configuration
        self.copy = configuration.copy
        self.layoutDirection = configuration.rightToLeft ? "rightToLeft" : "leftToRight"
        self.onEvent = { value in
            if let event = PermissionEvent(rawValue: value) { onEvent(event) }
        }
        self.onError = onError
        super.init()
    }

    public func update(_ state: PermissionState) { setState(state.rawValue) }

    /// 返回授权卡，不声称权限已通过；拖拽未结束时延后执行。
    public func returnToCard() {
        guard !closed, state == "awaiting-user" else { return }
        if dragging { returnRequested = true; return }
        startBackFlight()
    }

    func finishGranted() {
        guard !closed, !dragging else { return }
        if returning || flight != nil { return }
        if state == "awaiting-user", helperPanel != nil { startBackFlight() }
        else if initialPanel != nil { restoreInitialPage() }
        else { close() }
    }

    public var canStartDrag: Bool {
        !closed && !dragging && state == "awaiting-user" && helperPanel != nil
    }

    @discardableResult
    public func present() -> Bool {
        guard !closed, !presented else { return !closed }
        guard let appIcon = configuration.applicationIcon ?? NSWorkspace.shared.icon(forFile: configuration.applicationURL.path) as NSImage? else {
            reportMessage("Application icon is unavailable")
            return false
        }
        _ = NSApplication.shared
            let panel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: permissionHostInitialWidth, height: 312),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false,
            )
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.level = NSWindow.Level(rawValue: 3)
            panel.title = permissionHostString(self.copy, "title")
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.isOpaque = false
            panel.backgroundColor = NSColor.white.withAlphaComponent(0.001)
            let delegate = PermissionHostWindowDelegate { [weak self] in self?.handleWindowClosed() }
            panel.delegate = delegate

            let view = PCKPermissionInitialView(frame: panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: permissionHostInitialWidth, height: 312))
            let permissionIcon = configuration.permissionIcon ?? permissionHostPermissionIcon(title: permissionHostString(self.copy, "permissionTitle"))
            view.configure(
                copy: permissionHostNativeCopy(self.copy, layoutDirection: layoutDirection),
                appIcon: appIcon,
                permissionIcon: permissionIcon,
                actionTarget: actionTarget,
            )
            view.configureCards(copies: configuration.permissions.map { configuration.copy(for: $0) }, icons: configuration.permissions.map { kind in
                if kind == .deviceControl { return configuration.permissionIcon ?? permissionIcon }
                if let type = UTType("com.apple.graphic-icon.screen-recording") { return NSWorkspace.shared.icon(for: type) }
                return NSImage(systemSymbolName: "record.circle", accessibilityDescription: kind.displayName(language: configuration.language))
            }, onAllow: { [weak self] index in self?.selectPermission(at: index) })
            let card = view.permissionCardView
            view.setContent(
                title: permissionHostString(self.copy, "title"),
                body: permissionHostString(self.copy, "body"),
                allowEnabled: true,
                settingsPlaceholder: false,
            )
            panel.contentView = view
            initialPanel = panel
            initialView = view
            cardView = card
            initialDelegate = delegate
            guard fitInitialPage() else {
                panel.delegate = nil
                panel.close()
                initialPanel = nil
                initialView = nil
                cardView = nil
                initialDelegate = nil
                return false
            }
            panel.center()
            presented = true
            NSApplication.shared.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        return true
    }

    func setState(_ nextState: String, message: String? = nil) {
        guard !closed else { return }
        probe("state-request-\(nextState)")
        switch nextState {
        case "repairing":
            state = nextState
            initialPanel?.level = .normal
            stopTracking()
            // Match the reference transition: keep the original card until
            // the same-height Settings placeholder takes its place.
        case "awaiting-user":
            let enteringAwaitingUser = state != "awaiting-user"
            state = nextState
            initialPanel?.level = .normal
            setInitialContent(
                title: permissionHostString(copy, "title"),
                body: permissionHostString(copy, "body"),
                allowEnabled: false,
                settingsPlaceholder: true,
            )
            cardView?.isHidden = true
            if enteringAwaitingUser { configuration.handoffTarget.prepare() }
            startSettingsTracking()
        case "granted":
            completionRequested = true
            finishGranted()
        case "error":
            guard setGuideActivationPolicy(.accessory) else { return }
            state = nextState
            returning = false
            stopTracking()
            stopBackFlightTimer()
            disposeActiveFlight()
            disposeHelper()
            initialPanel?.level = .floating
            cardView?.isHidden = false
            setInitialContent(
                title: permissionHostString(copy, "errorTitle"),
                body: permissionHostString(copy, "errorBody"),
                allowEnabled: false,
                settingsPlaceholder: false,
            )
            fitInitialPage()
            initialPanel?.orderFront(nil)
        default:
            reportMessage("unsupported native permission state: \(nextState)")
        }
    }

    public func close() {
        guard !closed else { return }
        // AppKit can reorder the dragging source even after a close request.
        // Keep that source alive, but retire every pixel until ended arrives.
        if (dragging || dragSession != nil), let helperPanel {
            terminalDragPanel = helperPanel
            terminalDragSession = dragSession
            terminalDragPanel?.alphaValue = 0
        }
        probe("close")
        closed = true
        returnRequested = false
        presented = false
        returning = false
        retryReady = false
        dragging = false
        dragSession = nil
        stopTracking()
        stopArrow()
        stopBackFlightTimer()
        disposeActiveFlight()
        if helperPanel !== terminalDragPanel { dragView?.removeFromSuperview() }
        dragView = nil

        if let arrowPanel {
            helperPanel?.removeChildWindow(arrowPanel)
            arrowPanel.delegate = nil
            arrowPanel.orderOut(nil)
            arrowPanel.close()
        }
        arrowPanel = nil
        arrowView = nil
        arrowTracker = nil

        if let helperPanel {
            helperPanel.delegate = nil
            helperPanel.orderOut(nil)
            if helperPanel !== terminalDragPanel { helperPanel.close() }
        }
        helperPanel = nil
        helperView = nil
        appRowView = nil

        if let initialPanel {
            initialPanel.delegate = nil
            initialPanel.orderOut(nil)
            initialPanel.close()
        }
        initialPanel = nil
        initialView = nil
        cardView = nil
        // Close can arrive directly from the CLI or after a grant without a
        // Back transition. No guide window remains visible at this point.
        if configuration.managesActivationPolicy && NSApplication.shared.activationPolicy() == .prohibited {
            _ = NSApplication.shared.setActivationPolicy(.accessory)
        }
    }

    func selectPermission(at index: Int) {
        guard !closed, !returning, state == "pending", configuration.permissions.indices.contains(index) else { return }
        let permission = configuration.permissions[index]
        guard !grantedPermissions.contains(permission) else { return }
        if activePermission != permission { settled = false; retryReady = false }
        activePermission = permission
        copy = configuration.copy(for: permission)
        initialView?.selectCard(at: index)
        cardView = initialView?.permissionCardView
        handleAllow()
    }

    func handleAllow() {
        probe("allow")
        guard !closed, !returning, !dragging else { return }
        if state == "pending" && !settled {
            sourceEndpoint = captureInitialEndpoint()
            settled = true
            onEvent("allow")
            return
        }
        guard state == "pending", settled, retryReady else { return }
        retryReady = false
        guard let endpoint = captureInitialEndpoint() else {
            sourceEndpoint = nil
            restoreInitialPage()
            return
        }
        sourceEndpoint = endpoint
        setState("repairing", message: nil)
        onEvent("retry")
    }

    func handleSkip() {
        guard !closed, helperPanel == nil else { return }
        onEvent("later")
        close()
    }

    func handleResumeSettings() {
        guard !closed, !returning, !dragging, state == "awaiting-user" else { return }
        onEvent("retry")
    }

    func handleLater() {
        guard !closed else { return }
        if state == "awaiting-user", helperPanel != nil {
            startBackFlight()
        } else {
            onEvent("later")
            close()
        }
    }

    func handleArrowEntered() {
        guard presented, !closed else { return }
        stretchArrow()
    }

    func handleDragBegan() {
        probe("drag-began")
        guard !closed else { return }
        dragging = true
        stopArrow()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            arrowView?.resetToIdentity()
        } else {
            arrowView?.animate(toScaleX: 1, scaleY: 1)
        }
        appRowView?.isHidden = true
    }

    func handleDragEnded() {
        probe("drag-ended")
        dragging = false
        dragSession = nil
        if closed { finishTerminalDrag(); return }
        appRowView?.isHidden = false
        if completionRequested { finishGranted(); return }
        if returnRequested { returnRequested = false; startBackFlight(); return }
        scheduleArrow(after: 4)
    }

    func recordDragSession(_ session: NSDraggingSession) {
        if closed {
            terminalDragSession = session
        } else {
            dragSession = session
        }
    }

    func finishTerminalDrag() {
        guard let panel = terminalDragPanel else { return }
        terminalDragPanel = nil
        terminalDragSession = nil
        panel.delegate = nil
        panel.orderOut(nil)
        panel.close()
    }

    func report(_ error: Error) { reportMessage(error.localizedDescription) }

    func reportMessage(_ message: String) {
        onError(String(message.prefix(512)))
    }

    @discardableResult
    func setGuideActivationPolicy(_ policy: NSApplication.ActivationPolicy) -> Bool {
        guard configuration.managesActivationPolicy else { return true }
        let application = NSApplication.shared
        if application.activationPolicy() == policy { return true }
        guard application.setActivationPolicy(policy) else {
            reportMessage("native permission guide could not change its activation policy")
            return false
        }
        return true
    }

    func handleWindowClosed() {
        probe("window-close")
        guard !closed else { return }
        onEvent("later")
        close()
    }

    @discardableResult
    func fitInitialPage() -> Bool {
        guard let initialView, let initialPanel else { return false }
        let preferred = initialView.preferredContentSize
        guard preferred.width.isFinite, preferred.width > 0, preferred.height > 0, preferred.height.isFinite else {
            reportMessage("native permission initial view has invalid preferred size")
            return false
        }
        initialView.setFrameSize(preferred)
        initialPanel.setContentSize(preferred)
        initialView.layoutSubtreeIfNeeded()
        return true
    }

    func setInitialContent(title: String, body: String, allowEnabled: Bool, settingsPlaceholder: Bool) {
        initialView?.setContent(
            title: title,
            body: body,
            allowEnabled: allowEnabled,
            settingsPlaceholder: settingsPlaceholder,
        )
        cardView?.isHidden = settingsPlaceholder
    }

    func captureInitialEndpoint() -> PermissionHostFlightEndpoint? {
        guard let initialView, let cardView else { return nil }
        let scale = initialView.window?.backingScaleFactor ?? 1
        var image = initialView.snapshotPermissionCard(scale: scale)
        if image == nil {
            initialView.displayIfNeeded()
            image = initialView.snapshotPermissionCard(scale: scale)
        }
        guard let image else { return nil }
        return PermissionHostFlightEndpoint(
            view: cardView,
            frame: permissionHostScreenFrame(cardView),
            radius: 24,
            image: image,
        )
    }

    func helperEndpoint() -> PermissionHostFlightEndpoint? {
        guard let helperView, let helperPanel else { return nil }
        let frame = permissionHostScreenFrame(helperView)
        let scale = helperPanel.backingScaleFactor
        return PermissionHostFlightEndpoint(
            view: helperView,
            frame: frame,
            radius: 14,
            image: nil,
            captureImage: { [weak helperView] in
                guard let helperView else { return nil }
                return helperView.snapshotImage(scale: scale)
            },
        )
    }

}
