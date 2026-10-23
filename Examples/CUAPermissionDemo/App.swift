// [INPUT]: 依赖 AppKit、DemoController 与包内 DemoIcon.icns。
// [OUTPUT]: 提供演示入口、Dock 图标与退出菜单。
// [POS]: 演示生命周期入口；不申请系统权限。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit

@main
@MainActor
enum DemoApp {
    // 手工打包的 Demo 显式设置进程图标，不依赖 Dock 缓存刷新。
    @discardableResult
    static func installDockIcon(at url: URL?) -> Bool {
        guard let url, let image = NSImage(contentsOf: url) else { return false }
        NSApplication.shared.applicationIconImage = image
        return true
    }

    static func main() {
        let app = NSApplication.shared
        installDockIcon(at: Bundle.main.url(forResource: "DemoIcon", withExtension: "icns"))
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
