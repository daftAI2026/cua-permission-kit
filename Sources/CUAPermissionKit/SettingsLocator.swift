// [INPUT]: 依赖 AppKit、SwiftUI 与包内视图协作。
// [OUTPUT]: 提供系统设置窗口的只读定位。
// [POS]: 授权向导表现层；不读写系统授权数据库。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit
import CoreGraphics

/// A window returned by the System Settings locator.
///
/// `frame` uses Quartz global screen coordinates, matching the dictionaries
/// returned by `CGWindowListCopyWindowInfo`.  The presenter converts this
/// value to AppKit coordinates only when it positions its helper panel.
@MainActor
public struct PermissionHostSettingsFrame {
    public let frame: NSRect
    public let pid: pid_t
    public let windowID: CGWindowID

    public init(frame: NSRect, pid: pid_t, windowID: CGWindowID) {
        self.frame = frame
        self.pid = pid
        self.windowID = windowID
    }
}

/// Read-only System Settings window discovery used by the short-lived host.
///
/// Normal tracking follows the shared Runtime locator: it keeps CG's visible
/// window order and ignores small transient Settings surfaces. A separate
/// one-shot handoff may reveal an already-running Settings instance with no
/// visible main window; neither path launches Settings or reads user data.
@MainActor
public final class SettingsLocator {
    public static let bundleIdentifier = "com.apple.systempreferences"

    public init() {}

    public func locate() -> PermissionHostSettingsFrame? {
        precondition(Thread.isMainThread, "Settings location must run on the main thread")

        let applications = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.bundleIdentifier,
        )
        let pids = Set(
            applications
                .map(\.processIdentifier)
                .filter { $0 > 0 },
        )
        guard !pids.isEmpty else { return nil }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
            as? [[String: Any]] else {
            return nil
        }

        for window in rawWindows {
            guard let ownerPID = number(window[kCGWindowOwnerPID as String]),
                  pids.contains(pid_t(ownerPID)),
                  let bounds = windowBounds(window[kCGWindowBounds as String]),
                  bounds.width > 600,
                  bounds.height >= 470,
                  let rawWindowID = number(window[kCGWindowNumber as String]) else {
                continue
            }
            return PermissionHostSettingsFrame(
                frame: bounds,
                pid: pid_t(ownerPID),
                windowID: CGWindowID(rawWindowID),
            )
        }
        return nil
    }

    /// Match the shared Runtime's one-shot hidden-window reveal before normal
    /// read-only tracking. The CLI owns the actual Settings URL open request.
    public func prepareHandoff() {
        let applications = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier)
        guard applications.count == 1, let application = applications.first,
              application.processIdentifier > 0,
              let windows = CGWindowListCopyWindowInfo(CGWindowListOption(rawValue: 16), kCGNullWindowID)
                as? [[String: Any]] else { return }
        let owned = windows.filter {
            number($0[kCGWindowOwnerPID as String]) == Int(application.processIdentifier)
        }
        let visibleMain = owned.contains { window in
            guard let bounds = windowBounds(window[kCGWindowBounds as String]) else { return false }
            return bounds.width > 600 && bounds.height >= 470 &&
                number(window[kCGWindowIsOnscreen as String]) == 1
        }
        if !owned.isEmpty && !visibleMain { _ = application.activate(options: []) }
    }

    private func number(_ value: Any?) -> Int? {
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? Int { return value }
        if let value = value as? Int32 { return Int(value) }
        if let value = value as? UInt32 { return Int(value) }
        return nil
    }

    private func windowBounds(_ value: Any?) -> NSRect? {
        guard let dictionary = value as? NSDictionary,
              let x = double(dictionary["X"]),
              let y = double(dictionary["Y"]),
              let width = double(dictionary["Width"]),
              let height = double(dictionary["Height"]),
              x.isFinite,
              y.isFinite,
              width.isFinite,
              height.isFinite else {
            return nil
        }
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func double(_ value: Any?) -> CGFloat? {
        if let value = value as? NSNumber { return CGFloat(value.doubleValue) }
        if let value = value as? Double { return CGFloat(value) }
        if let value = value as? CGFloat { return value }
        return nil
    }
}
