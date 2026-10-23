// [INPUT]: 依赖 XCTest、AppKit 与演示目标。
// [OUTPUT]: 验证 Dock 图标来源与设置模式拒绝模拟完成。
// [POS]: 演示与真实授权状态的隔离回归测试。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit
import XCTest
@testable import CUAPermissionDemo

final class DemoIsolationTests: XCTestCase {
    @MainActor func testDockIconUsesExplicitResource() throws {
        let app = NSApplication.shared
        let previous = app.applicationIconImage
        defer { app.applicationIconImage = previous }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Assets/DemoIcon.icns")
        XCTAssertTrue(DemoApp.installDockIcon(at: url))
        let installed = try XCTUnwrap(app.applicationIconImage?.tiffRepresentation)
        XCTAssertFalse(DemoApp.installDockIcon(at: nil))
        XCTAssertEqual(app.applicationIconImage?.tiffRepresentation, installed)
        XCTAssertFalse(DemoApp.installDockIcon(at: root.appendingPathComponent("missing.icns")))
        XCTAssertEqual(app.applicationIconImage?.tiffRepresentation, installed)
        // Dock 的系统渲染不等于 ICNS 原始像素；真实外观另做截图验收。
    }

    @MainActor func testSettingsModeRejectsDemoDropCompletion() throws {
        guard ProcessInfo.processInfo.environment["CUA_RUN_WINDOW_TESTS"] == "1" else { throw XCTSkip("Opt-in visible window test") }
        _ = NSApplication.shared
        let controller = DemoController()
        controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        defer {
            _ = controller.perform(Selector(("closeGuide")))
            NSApp.windows.filter { $0.title == "CUA Permission Kit Demo" }.forEach { $0.close() }
        }
        let window = try XCTUnwrap(NSApp.windows.first { $0.title == "CUA Permission Kit Demo" })
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let views = descendants(try XCTUnwrap(window.contentView))
        let destination = try XCTUnwrap(views.compactMap { $0 as? NSPopUpButton }.first)
        let drop = try XCTUnwrap(views.compactMap { $0 as? DropTarget }.first)
        _ = controller.perform(Selector(("showEnglish")))
        destination.selectItem(at: 1)
        if let action = destination.action { NSApp.sendAction(action, to: destination.target, from: destination) }
        let status = try XCTUnwrap(views.compactMap { $0 as? NSTextField }.first { $0.stringValue == "Preview open" })
        drop.onAccepted?()
        XCTAssertEqual(status.stringValue, "Preview open", "Settings mode must not accept simulated authorization")
        // 对照组：默认 Demo 模式必须继续支持模拟完成。
        destination.selectItem(at: 0)
        if let action = destination.action { NSApp.sendAction(action, to: destination.target, from: destination) }
        drop.onAccepted?()
        XCTAssertEqual(status.stringValue, "Drop verified. Demo permission completed.")
    }
}
