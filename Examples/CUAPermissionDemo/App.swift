// [INPUT]: 依赖 AppKit 与 DemoController。
// [OUTPUT]: 提供演示 App 的进程入口与退出菜单。
// [POS]: 演示生命周期入口；不申请系统权限。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit

@main
@MainActor
enum DemoApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let menu = NSMenu()
        let item = NSMenuItem()
        let actions = NSMenu()
        actions.addItem(withTitle: "Quit CUA Permission Demo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = actions
        menu.addItem(item)
        app.mainMenu = menu
        let controller = DemoController()
        app.delegate = controller
        withExtendedLifetime(controller) { app.run() }
    }
}
