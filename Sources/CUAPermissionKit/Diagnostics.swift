// [INPUT]: 依赖 OSLog 与 Presenter 的本进程窗口状态。
// [OUTPUT]: 输出调试构建的事件顺序与窗口可见性。
// [POS]: 授权卡探针；不记录应用路径、文案或账号数据。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit
import OSLog

private let permissionLogger = Logger(subsystem: "org.cuapermissionkit", category: "Windowing")

@MainActor
extension PermissionPresenter {
    func probe(_ event: String) {
#if DEBUG
        let initialVisible = initialPanel?.isVisible ?? false
        let initialKey = initialPanel?.isKeyWindow ?? false
        let helperVisible = helperPanel?.isVisible ?? false
        let active = NSApp.isActive
        let policy = NSApp.activationPolicy().rawValue
        permissionLogger.notice("event=\(event, privacy: .public) state=\(self.state, privacy: .public) initialVisible=\(initialVisible) initialKey=\(initialKey) helperVisible=\(helperVisible) active=\(active) policy=\(policy) dragging=\(self.dragging)")
#endif
    }
}
