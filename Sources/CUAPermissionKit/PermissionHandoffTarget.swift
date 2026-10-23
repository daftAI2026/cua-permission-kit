// [INPUT]: 依赖 AppKit、SettingsLocator 与调用方的窗口几何。
// [OUTPUT]: 提供设置窗口或演示接收窗口的定位与激活接口。
// [POS]: 复用同一拖拽与动画，不复制另一套向导。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit

@MainActor
public struct PermissionHandoffTarget {
    let locate: () -> PermissionHostSettingsFrame?
    let activate: () -> Void
    let prepare: () -> Void

    public init(locate: @escaping () -> PermissionHostSettingsFrame?, activate: @escaping () -> Void, prepare: @escaping () -> Void = {}) {
        self.locate = locate
        self.activate = activate
        self.prepare = prepare
    }

    public static var systemSettings: PermissionHandoffTarget {
        PermissionHandoffTarget(locate: { SettingsLocator().locate() }, activate: {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: SettingsLocator.bundleIdentifier)
            if apps.count == 1 { _ = apps[0].activate(options: .activateAllWindows) }
        }, prepare: { SettingsLocator().prepareHandoff() })
    }
}
