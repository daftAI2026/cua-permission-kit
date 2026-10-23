// [INPUT]: 依赖 AppKit、SwiftUI 与包内视图协作。
// [OUTPUT]: 提供窗口代理、拖拽源与坐标转换。
// [POS]: 授权向导表现层；不读写系统授权数据库。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit
import Foundation

// The SwiftUI views in permission-views.swift are the renderer.  This file is
// deliberately limited to the short-lived AppKit presenter: panel lifetime,
// screen/window geometry, drag tracking, and the native guide state machine.
// TCC inspection, reset, and Settings launching remain in the CLI process.

let permissionHostInitialWidth: CGFloat = 600
let permissionHostHelperWidth: CGFloat = 531
let permissionHostHelperHeight: CGFloat = 110
let permissionHostRowWidth: CGFloat = 459
let permissionHostRowHeight: CGFloat = 42
let permissionHostArrowWindowSize: CGFloat = 100
let permissionHostArrowWindowX: CGFloat = 31
let permissionHostArrowWindowY: CGFloat = 60
let permissionHostArrowGraphicSize: CGFloat = 28

@MainActor
func permissionHostPermissionIcon(title: String) -> NSImage? {
    NSImage(contentsOfFile: "/System/Library/ExtensionKit/Extensions/AccessibilitySettingsExtension.appex/Contents/Resources/UniversalAccessPref.icns")
        ?? NSImage(contentsOfFile: "/System/Library/PreferencePanes/UniversalAccessPref.prefPane/Contents/Resources/UniversalAccessPref.icns")
        ?? NSImage(systemSymbolName: "accessibility", accessibilityDescription: title)
}

func permissionHostString(_ copy: NSDictionary, _ key: String) -> String {
    if let value = copy[key] as? String { return value }
    if let value = copy[key] as? NSString { return value as String }
    return ""
}

func permissionHostNativeCopy(_ copy: NSDictionary, layoutDirection: String) -> NSDictionary {
    let keys = [
        "applicationName", "title", "body", "permissionTitle", "permissionDescription", "repair", "later", "back",
        "addedTitle", "addedBody", "dragInstruction", "dragInstructionRuns", "completeInSettings",
        "checking", "repairing", "openSettings", "errorTitle", "errorBody",
    ]
    let result = NSMutableDictionary(capacity: keys.count + 1)
    for key in keys { result[key] = permissionHostString(copy, key) }
    result["layoutDirection"] = layoutDirection == "rightToLeft" ? "rightToLeft" : "leftToRight"
    return result
}

func permissionHostCachedImage(_ view: NSView) -> NSImage? {
    view.layoutSubtreeIfNeeded()
    let bounds = view.bounds
    guard bounds.width > 0, bounds.height > 0,
          let representation = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
    view.displayIfNeeded()
    view.cacheDisplay(in: bounds, to: representation)
    let image = NSImage(size: bounds.size)
    image.addRepresentation(representation)
    return image
}

func permissionHostScreenFrame(_ view: NSView) -> NSRect {
    guard let window = view.window else { return view.bounds }
    let windowRect = view.convert(view.bounds, to: nil)
    return window.convertToScreen(windowRect)
}

func permissionHostIntegral(_ value: CGFloat) -> CGFloat { floor(value) }

func permissionHostFrame(_ target: NSRect, size: NSSize) -> NSRect? {
    guard let screen = NSScreen.screens.first else { return nil }
    let screenFrame = screen.frame
    guard target.origin.x.isFinite, target.origin.y.isFinite,
          target.width.isFinite, target.width > 0,
          target.height.isFinite, target.height > 0,
          size.width.isFinite, size.width > 0,
          size.height.isFinite, size.height > 0,
          screenFrame.origin.x.isFinite, screenFrame.origin.y.isFinite,
          screenFrame.width.isFinite, screenFrame.width > 0,
          screenFrame.height.isFinite, screenFrame.height > 0 else { return nil }

    let x = target.minX + target.width - size.width - 10
    let y = screenFrame.minY + screenFrame.height - target.minY - target.height + 10
    let maxX = x + size.width
    let maxY = y + size.height
    guard x.isFinite, y.isFinite, maxX.isFinite, maxY.isFinite else { return nil }
    let left = permissionHostIntegral(x)
    let bottom = permissionHostIntegral(y)
    let width = ceil(maxX) - left
    let height = ceil(maxY) - bottom
    guard left.isFinite, bottom.isFinite,
          width.isFinite, width > 0,
          height.isFinite, height > 0 else { return nil }
    return NSRect(
        x: left,
        y: bottom,
        width: width,
        height: height,
    )
}

@MainActor
final class PermissionHostWindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }

    func windowWillClose(_ notification: Notification) { onClose() }
}

@MainActor
final class PermissionHostActionTarget: NSObject {
    weak var owner: PermissionPresenter?

    init(owner: PermissionPresenter) {
        self.owner = owner
        super.init()
    }

    @objc(allow:)
    func allow(_ sender: Any?) { owner?.handleAllow() }

    @objc(skip:)
    func skip(_ sender: Any?) { owner?.handleSkip() }

    @objc(resumeSettings:)
    func resumeSettings(_ sender: Any?) { owner?.handleResumeSettings() }

    @objc(later:)
    func later(_ sender: Any?) { owner?.handleLater() }
}

@MainActor
final class PermissionHostHelperPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PermissionHostArrowPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PermissionHostArrowTrackerView: NSView {
    weak var owner: PermissionPresenter?

    override func mouseEntered(with event: NSEvent) { owner?.handleArrowEntered() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil,
            )
        )
    }
}

@MainActor
final class PermissionHostDragView: NSView, NSDraggingSource {
    weak var owner: PermissionPresenter?
    weak var rowView: NSView?

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let owner, owner.canStartDrag, let rowView else { return }
        owner.configuration.handoffTarget.activate()
        owner.probe("drag-mousedown")
        let item = NSPasteboardItem()
        item.setString(owner.configuration.applicationURL.absoluteString, forType: .fileURL)
        let draggingItem = NSDraggingItem(pasteboardWriter: item)
        let frame = rowView.convert(rowView.bounds, to: self)
        draggingItem.setDraggingFrame(frame, contents: permissionHostCachedImage(rowView))
        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        owner.recordDragSession(session)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        owner?.handleDragBegan()
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        owner?.handleDragEnded()
    }
}
