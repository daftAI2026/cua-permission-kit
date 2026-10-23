// [INPUT]: 依赖 XCTest 与库的配置、视图和生命周期接口。
// [OUTPUT]: 验证应用隔离、文案覆盖、快照与关闭幂等性。
// [POS]: 独立包回归测试；不申请或重置系统权限。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import XCTest
@testable import CUAPermissionKit

final class ConfigurationTests: XCTestCase {
    @MainActor func testApplicationIdentityIsPerInstance() {
        let first = PermissionConfiguration(applicationURL: URL(fileURLWithPath: "/Applications/Alpha.app"), applicationName: "Alpha")
        let second = PermissionConfiguration(applicationURL: URL(fileURLWithPath: "/Applications/Beta.app"), applicationName: "Beta")
        XCTAssertEqual(first.copy["applicationName"] as? String, "Alpha")
        XCTAssertEqual(second.copy["applicationName"] as? String, "Beta")
        XCTAssertTrue((first.copy["dragInstruction"] as? String ?? "").contains("Alpha"))
        XCTAssertNotEqual(first.applicationURL, second.applicationURL)
    }

    @MainActor func testLocalizedCopyCannotReplaceApplicationIdentity() {
        let config = PermissionConfiguration(applicationURL: URL(fileURLWithPath: "/Applications/Alpha.app"), applicationName: "Alpha", localizedCopy: ["repair": "允许", "applicationName": "Wrong"])
        XCTAssertEqual(config.copy["repair"] as? String, "允许")
        XCTAssertEqual(config.copy["applicationName"] as? String, "Alpha")
    }

    @MainActor func testCloseIsIdempotentAndPreservesHostPolicy() {
        let app = NSApplication.shared
        let policy = app.activationPolicy()
        var events: [PermissionEvent] = []
        let presenter = PermissionPresenter(configuration: .init(applicationURL: URL(fileURLWithPath: "/Applications/Alpha.app"), applicationName: "Alpha"), onEvent: { events.append($0) }, onError: { XCTFail($0) })
        presenter.close()
        presenter.close()
        presenter.update(.granted)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(app.activationPolicy(), policy)
        XCTAssertFalse(presenter.present())
    }

    @MainActor func testHelperCopyPreservesIdentityAndRTL() {
        let config = PermissionConfiguration(applicationURL: URL(fileURLWithPath: "/Applications/Alpha.app"), applicationName: "Alpha", rightToLeft: true)
        let copy = permissionHostNativeCopy(config.copy, layoutDirection: "rightToLeft")
        XCTAssertEqual(copy["applicationName"] as? String, "Alpha")
        XCTAssertEqual(copy["layoutDirection"] as? String, "rightToLeft")
        let view = PCKPermissionHelperView(frame: NSRect(x: 0, y: 0, width: 531, height: 110))
        view.configure(copy: copy, appIcon: nil, actionTarget: nil)
        XCTAssertEqual(view.appRowFrame.minX, 10)
        XCTAssertNotNil(view.snapshotImage(scale: 1))
    }

    @MainActor func testRepeatedSkipEmitsOnce() {
        var events: [PermissionEvent] = []
        let presenter = PermissionPresenter(configuration: .init(applicationURL: URL(fileURLWithPath: "/Applications/Alpha.app"), applicationName: "Alpha"), onEvent: { events.append($0) }, onError: { XCTFail($0) })
        presenter.handleSkip()
        presenter.handleSkip()
        XCTAssertEqual(events, [.later])
    }

    func testSpringRejectsInvalidTimeAndSettles() {
        var spring = PermissionHostSpring()
        XCTAssertEqual(spring.advance(to: .nan), 0)
        XCTAssertEqual(spring.advance(to: -1), 0)
        for frame in 1...600 { _ = spring.advance(to: Double(frame) / 60) }
        XCTAssertTrue(spring.settled)
        XCTAssertEqual(spring.value, 1)
    }

    @MainActor func testWindowlessSnapshotAndInvalidScale() {
        _ = NSApplication.shared
        let config = PermissionConfiguration(applicationURL: URL(fileURLWithPath: "/Applications/Alpha.app"), applicationName: "Alpha")
        let view = PCKPermissionInitialView(frame: NSRect(x: 0, y: 0, width: 600, height: 312))
        view.configure(copy: config.copy, appIcon: nil, permissionIcon: nil, actionTarget: nil)
        XCTAssertNotNil(view.snapshotPermissionCard(scale: 2))
        XCTAssertNil(view.snapshotPermissionCard(scale: 0))
        XCTAssertNil(view.snapshotPermissionCard(scale: .nan))
    }
}
import AppKit
