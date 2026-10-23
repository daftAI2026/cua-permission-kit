// [INPUT]: 依赖 AppKit 的应用前置请求、定位器与宿主窗口几何。
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
            guard apps.count == 1, let url = apps[0].bundleURL else { return }
            // 非激活面板点击不能保证 activate() 抢到前台。
            // 通过系统打开已有实例；不新建实例、不请求辅助功能权限。
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = false
            configuration.addsToRecentItems = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in }

        }, prepare: { SettingsLocator().prepareHandoff() })
    }
}
