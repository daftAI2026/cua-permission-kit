// [INPUT]: 依赖 XCTest 与真实 AppKit 窗口。
// [OUTPUT]: 验证小卡片接管、获权返回与宿主激活策略。
// [POS]: 显式启用的窗口回归测试，不读取或修改系统授权。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit
import XCTest
@testable import CUAPermissionKit

final class HandoffWindowTests: XCTestCase {
    @MainActor func testHandoffHidesInitialWithoutChangingHostPolicy() throws {
        guard ProcessInfo.processInfo.environment["CUA_RUN_WINDOW_TESTS"] == "1" else { throw XCTSkip("Opt-in visible window test") }
        let app = NSApplication.shared
        let policy = app.activationPolicy()
        let presenter = PermissionPresenter(configuration: .init(applicationURL: Bundle.main.bundleURL, applicationName: "Fixture"), onEvent: { _ in }, onError: { XCTFail($0) })
        defer { presenter.close() }
        XCTAssertTrue(presenter.present())
        XCTAssertTrue(presenter.initialPanel?.isVisible == true)
        presenter.state = "awaiting-user"
        presenter.revealHelper()
        XCTAssertFalse(presenter.initialPanel?.isVisible == true, "Handoff must retire the old window before the first drag click")
        XCTAssertEqual(app.activationPolicy(), policy)
        presenter.restoreInitialPage()
        XCTAssertTrue(presenter.initialPanel?.isVisible == true)
        XCTAssertEqual(presenter.state, "pending")
    }

    @MainActor func testTwoCardsCompleteIndependently() throws {
        guard ProcessInfo.processInfo.environment["CUA_RUN_WINDOW_TESTS"] == "1" else { throw XCTSkip("Opt-in visible window test") }
        _ = NSApplication.shared
        let config = PermissionConfiguration(applicationURL: Bundle.main.bundleURL, applicationName: "Fixture", permissions: [.deviceControl, .screenAndAudioRecording])
        let presenter = PermissionPresenter(configuration: config, onEvent: { _ in }, onError: { XCTFail($0) })
        defer { presenter.close() }
        XCTAssertTrue(presenter.present())
        XCTAssertGreaterThan(presenter.initialView!.preferredContentSize.height, 380)
        presenter.completionRequested = true
        presenter.restoreInitialPage()
        XCTAssertFalse(presenter.closed)
        XCTAssertEqual(presenter.grantedPermissions, [.deviceControl])
        presenter.selectPermission(at: 1)
        XCTAssertEqual(presenter.activePermission, .screenAndAudioRecording)
        presenter.completionRequested = true
        presenter.restoreInitialPage()
        XCTAssertTrue(presenter.closed)
    }

    @MainActor func testGrantedHandoffStartsReturnBeforeClosing() throws {
        guard ProcessInfo.processInfo.environment["CUA_RUN_WINDOW_TESTS"] == "1" else { throw XCTSkip("Opt-in visible window test") }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { throw XCTSkip("Reduced motion uses immediate completion") }
        _ = NSApplication.shared
        let presenter = PermissionPresenter(configuration: .init(applicationURL: Bundle.main.bundleURL, applicationName: "Fixture"), onEvent: { _ in }, onError: { XCTFail($0) })
        defer { presenter.close() }
        XCTAssertTrue(presenter.present())
        presenter.state = "awaiting-user"
        presenter.createHelper(frame: NSRect(x: 100, y: 100, width: 531, height: 110))
        presenter.helperPanel?.orderFront(nil)
        presenter.update(.granted)
        XCTAssertTrue(presenter.returning, "Granted must return the visible helper instead of abruptly disposing it")
        XCTAssertFalse(presenter.closed)
        presenter.fallbackToInitial()
        XCTAssertTrue(presenter.closed, "Completion must close rather than show a new Allow prompt")
    }
}
