// [INPUT]: 依赖 AppKit、SwiftUI 与包内视图协作。
// [OUTPUT]: 提供设置跟随、前后过渡与箭头计时。
// [POS]: 授权向导表现层；不读写系统授权数据库。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit
import Foundation
@MainActor
extension PermissionPresenter {
    func startSettingsTracking() {
        guard trackingTimer == nil else { return }
        locatingAttempts = 0
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.placeHelper()
            }
        }
        placeHelper()
    }

    func stopTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        locatingAttempts = 0
    }

    func placeHelper() {
        guard !closed, state == "awaiting-user", !returning, !dragging else { return }
        // The locator returns the selected Settings window in Quartz global
        // coordinates.  Convert only its frame here; keeping the PID/window
        // identity in the locator prevents a same-bundle or stale window from
        // being treated as the current target.
        guard let target = configuration.handoffTarget.locate() else {
            locatingAttempts += 1
            if helperPanel != nil {
                if locatingAttempts >= 10, !dragging {
                    onEvent("later")
                    close()
                }
            } else if locatingAttempts >= 50 {
                setState("error", message: permissionHostString(copy, "errorBody"))
            }
            return
        }
        locatingAttempts = 0
        if let helperPanel, let helperView {
            if let frame = permissionHostFrame(target.frame, size: helperView.preferredContentSize) {
                helperPanel.setFrame(frame, display: false)
                positionArrow(from: frame)
            }
            return
        }
        guard let frame = permissionHostFrame(target.frame, size: NSSize(width: permissionHostHelperWidth, height: permissionHostHelperHeight)) else {
            setState("error", message: "no display is available for the permission guide")
            return
        }
        createHelper(frame: frame)
        if let helperPanel, let helperView,
           let fittedFrame = permissionHostFrame(target.frame, size: helperView.preferredContentSize) {
            helperPanel.setFrame(fittedFrame, display: false)
            positionArrow(from: fittedFrame)
            if sourceEndpoint != nil {
                startForwardFlight()
            } else {
                revealHelper()
            }
        }
    }

    func createHelper(frame: NSRect) {
        guard let appIcon = configuration.applicationIcon ?? NSWorkspace.shared.icon(forFile: configuration.applicationURL.path) as NSImage? else {
            setState("error", message: "Application icon is unavailable")
            return
        }
        let panel = PermissionHostHelperPanel(
            contentRect: frame,
            styleMask: [.titled, .utilityWindow, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false,
        )
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = NSColor.white.withAlphaComponent(0.001)
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false
        panel.isMovable = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        if #available(macOS 11.0, *) { panel.toolbarStyle = .unifiedCompact }
        panel.collectionBehavior = NSWindow.CollectionBehavior(rawValue: 0x24a)
        panel.level = NSWindow.Level(rawValue: 3)
        panel.hidesOnDeactivate = false
        let delegate = PermissionHostWindowDelegate { [weak self] in self?.handleWindowClosed() }
        panel.delegate = delegate

        let view = PCKPermissionHelperView(frame: NSRect(x: 0, y: 0, width: permissionHostHelperWidth, height: permissionHostHelperHeight))
        view.configure(
            copy: permissionHostNativeCopy(copy, layoutDirection: layoutDirection),
            appIcon: appIcon,
            actionTarget: actionTarget,
        )
        let preferred = view.preferredContentSize
        guard preferred.width.isFinite, preferred.width > 0, preferred.height > 0, preferred.height.isFinite else {
            panel.delegate = nil
            panel.close()
            setState("error", message: "native permission helper has invalid preferred size")
            return
        }
        view.frame = NSRect(origin: .zero, size: preferred)
        let controller = NSViewController()
        controller.view = view
        panel.contentViewController = controller

        let row = PermissionHostDragView(frame: view.appRowFrame)
        row.owner = self
        row.rowView = view.appRowView
        view.addSubview(row)

        let arrowPanel = PermissionHostArrowPanel(
            contentRect: NSRect(x: 0, y: 0, width: permissionHostArrowWindowSize, height: permissionHostArrowWindowSize),
            styleMask: [],
            backing: .buffered,
            defer: false,
        )
        arrowPanel.isReleasedWhenClosed = false
        arrowPanel.isOpaque = false
        arrowPanel.backgroundColor = .clear
        arrowPanel.hasShadow = false
        arrowPanel.ignoresMouseEvents = false
        arrowPanel.collectionBehavior = NSWindow.CollectionBehavior(rawValue: 4)
        arrowPanel.level = NSWindow.Level(rawValue: 3)
        arrowPanel.hidesOnDeactivate = false
        let arrowDelegate = PermissionHostWindowDelegate { [weak self] in self?.handleWindowClosed() }
        arrowPanel.delegate = arrowDelegate
        let canvas = NSView(frame: NSRect(x: 0, y: 0, width: permissionHostArrowWindowSize, height: permissionHostArrowWindowSize))
        canvas.wantsLayer = true
        canvas.layer?.masksToBounds = false
        let arrow = PCKPermissionArrowView(frame: NSRect(x: 36, y: 10, width: permissionHostArrowGraphicSize, height: permissionHostArrowGraphicSize))
        let tracker = PermissionHostArrowTrackerView(frame: arrow.frame)
        tracker.owner = self
        canvas.addSubview(arrow)
        canvas.addSubview(tracker)
        arrowPanel.contentView = canvas
        panel.addChildWindow(arrowPanel, ordered: .above)

        self.helperPanel = panel
        self.helperView = view
        self.appRowView = view.appRowView
        self.dragView = row
        self.arrowPanel = arrowPanel
        self.arrowView = arrow
        self.arrowTracker = tracker
        self.helperDelegate = delegate
        self.arrowDelegate = arrowDelegate
        positionArrow(from: frame)
    }

    func positionArrow(from frame: NSRect) {
        guard let arrowPanel else { return }
        let x = layoutDirection == "rightToLeft"
            ? frame.width - permissionHostArrowWindowX - permissionHostArrowWindowSize
            : permissionHostArrowWindowX
        arrowPanel.setFrame(
            NSRect(
                x: frame.minX + x,
                y: frame.minY + permissionHostArrowWindowY,
                width: permissionHostArrowWindowSize,
                height: permissionHostArrowWindowSize,
            ),
            display: false,
        )
    }

    func revealHelper() {
        probe("reveal-helper")
        guard !closed, state == "awaiting-user", !returning else { return }
        // 只退场本向导的初始窗口，不改变宿主的激活策略。
        initialPanel?.orderOut(nil)
        presented = true
        helperPanel?.orderFrontRegardless()
        arrowPanel?.orderFront(nil)
        configuration.handoffTarget.activate()
        // A mouse press on the nonactivating helper can still activate this
        // process before the drag view receives mouseDown.  That activation
        // raises the separate initial NSWindow above Settings.  During the
        // guide, keep the existing windows and native drag, but disallow
        // process activation; Back restores the ordinary policy before its
        // existing activation and reverse flight.
        guard setGuideActivationPolicy(.prohibited) else { return }
        probe("helper-ready")
        scheduleArrow(after: 0.5)
    }

    func startForwardFlight() {
        guard let sourceEndpoint, let targetEndpoint = helperEndpoint() else {
            revealHelper()
            return
        }
        forwardSequence += 1
        let sequence = forwardSequence
        let active = PermissionHostFlight(
            source: sourceEndpoint,
            target: { [weak self] in self?.helperEndpoint() ?? targetEndpoint },
            reverse: false,
            isClosed: { [weak self] in self?.closed ?? true },
            onComplete: { [weak self] in self?.finishForwardFlight(sequence: sequence) },
            onError: { [weak self] _ in self?.noteFlightFallback() },
        )
        flight = active
        active.start()
    }

    func finishForwardFlight(sequence: Int) {
        guard !closed, !returning, state == "awaiting-user", forwardSequence == sequence, flight != nil else { return }
        flight = nil
        revealHelper()
        if completionRequested { finishGranted() }
    }

    func startBackFlight() {
        probe("back-start")
        guard !closed, !returning, !dragging, state == "awaiting-user",
              let initialView,
              let cardView else { return }
        guard setGuideActivationPolicy(.accessory) else { return }
        returning = true
        returnSequence += 1
        let sequence = returnSequence
        stopTracking()
        stopArrow()
        retryReady = false
        NSApplication.shared.activate(ignoringOtherApps: false)
        setInitialContent(
            title: permissionHostString(copy, "title"),
            body: permissionHostString(copy, "body"),
            allowEnabled: true,
            settingsPlaceholder: true,
        )
        fitInitialPage()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            fallbackToInitial()
            return
        }
        guard let helperEndpoint = helperEndpoint() else {
            fallbackToInitial()
            return
        }
        cardView.isHidden = false
        guard let targetEndpoint = captureInitialEndpoint() else {
            cardView.isHidden = true
            fallbackToInitial()
            return
        }
        cardView.isHidden = true
        initialPanel?.orderFront(nil)
        // The flight's `reverse` flag swaps the captured source/target image
        // order internally.  Pass the card as the source (it owns the
        // concrete image) and the helper as the destination; this produces a
        // helper-to-card reverse flight without asking the helper endpoint to
        // provide a source image it intentionally does not own.
        let active = PermissionHostFlight(
            source: targetEndpoint,
            target: { [weak self] in self?.helperEndpoint() ?? helperEndpoint },
            reverse: true,
            isClosed: { [weak self] in self?.closed ?? true },
            onComplete: { [weak self] in self?.finishBackFlight(sequence: sequence) },
            onError: { [weak self] _ in self?.noteFlightFallback() },
        )
        flight = active
        helperPanel?.alphaValue = 0
        helperView?.alphaValue = 0
        arrowPanel?.alphaValue = 0
        active.start()
        guard flight === active, returning, !closed else { return }
        arrowPanel?.orderOut(nil)
        backFlightTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self, weak active] _ in
            Task { @MainActor [weak self, weak active] in
                guard let self, let active,
                      !self.closed, self.returnSequence == sequence, self.flight === active else { return }
                self.fallbackToInitial()
            }
        }
        _ = initialView
    }

    func finishBackFlight(sequence: Int) {
        guard !closed, returnSequence == sequence, flight != nil else { return }
        flight = nil
        stopBackFlightTimer()
        restoreInitialPage(raiseBeforeHelperDisposal: true)
    }

    func fallbackToInitial() {
        returnSequence += 1
        stopBackFlightTimer()
        disposeActiveFlight()
        restoreInitialPage()
    }

    func restoreInitialPage(raiseBeforeHelperDisposal: Bool = false) {
        probe("restore-initial")
        guard !closed else { return }
        if completionRequested {
            grantedPermissions.insert(activePermission)
            probe("grant-return-complete")
            if grantedPermissions.count == configuration.permissions.count { close(); return }
            completionRequested = false
            initialView?.markCompleted(Set(configuration.permissions.indices.filter { grantedPermissions.contains(configuration.permissions[$0]) }))
        }
        guard setGuideActivationPolicy(.accessory) else { return }
        if raiseBeforeHelperDisposal { initialPanel?.level = .floating }
        disposeHelper()
        returning = false
        state = "pending"
        retryReady = true
        setInitialContent(
            title: permissionHostString(copy, "title"),
            body: permissionHostString(copy, "body"),
            allowEnabled: true,
            settingsPlaceholder: false,
        )
        fitInitialPage()
        if !raiseBeforeHelperDisposal { initialPanel?.level = .floating }
        NSApplication.shared.activate(ignoringOtherApps: true)
        initialPanel?.makeKeyAndOrderFront(nil)
    }

    func disposeActiveFlight() {
        // Clear the strong reference before disposing.  PermissionHostFlight
        // may synchronously call onComplete/onError during dispose; clearing
        // first prevents a stale callback from re-showing a closed page or
        // from entering the next state transition.
        let active = flight
        flight = nil
        active?.dispose()
    }

    func noteFlightFallback() {
        // A replica failure is visual-only: dispose settles its completion
        // callback, which reveals the helper or restores the initial card.
        // The controller must not treat it as a permission transaction error.
        NSLog("permission flight fallback")
    }

    func disposeHelper() {
        stopArrow()
        dragView?.removeFromSuperview()
        dragView = nil
        if let arrowPanel {
            helperPanel?.removeChildWindow(arrowPanel)
            arrowPanel.delegate = nil
            arrowPanel.orderOut(nil)
            arrowPanel.close()
        }
        if let helperPanel {
            helperPanel.delegate = nil
            helperPanel.orderOut(nil)
            helperPanel.close()
        }
        arrowPanel = nil
        arrowView = nil
        arrowTracker = nil
        helperPanel = nil
        helperView = nil
        appRowView = nil
        helperDelegate = nil
        arrowDelegate = nil
        presented = false
        dragging = false
    }

    func stopBackFlightTimer() {
        backFlightTimer?.invalidate()
        backFlightTimer = nil
    }

    func scheduleArrow(after delay: TimeInterval) {
        stopArrow()
        guard !closed else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            arrowView?.resetToIdentity()
            return
        }
        arrowTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stretchArrow()
            }
        }
    }

    func stretchArrow() {
        stopArrow()
        guard !closed, presented else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            arrowView?.resetToIdentity()
            return
        }
        if dragging {
            scheduleArrow(after: 4)
            return
        }
        arrowView?.animate(toScaleX: 1.15, scaleY: 1.6)
        arrowReturnTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.closed, !self.dragging else { return }
                if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    self.arrowView?.resetToIdentity()
                    return
                }
                self.arrowView?.animate(toScaleX: 1, scaleY: 1)
                self.scheduleArrow(after: 4)
            }
        }
    }

    func stopArrow() {
        arrowTimer?.invalidate()
        arrowTimer = nil
        arrowReturnTimer?.invalidate()
        arrowReturnTimer = nil
    }
}
