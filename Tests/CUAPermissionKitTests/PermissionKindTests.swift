// [INPUT]: 依赖权限类型与配置接口。
// [OUTPUT]: 验证两项权限、版本名称与独立设置入口。
// [POS]: 双卡合同测试，不触碰系统权限。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import XCTest
@testable import CUAPermissionKit
final class PermissionKindTests: XCTestCase {
    func testVersionedDeviceControlName() {
        XCTAssertEqual(PermissionKind.deviceControl.displayName(language: "en", majorVersion: 26), "Accessibility")
        XCTAssertEqual(PermissionKind.deviceControl.displayName(language: "en", majorVersion: 27), "Device Control and Data Access")
        XCTAssertEqual(PermissionKind.deviceControl.displayName(language: "zh", majorVersion: 27), "设备控制和数据访问")
    }
    func testRecordingHasSeparateSettingsRoute() {
        XCTAssertNotEqual(PermissionKind.deviceControl.settingsURL, PermissionKind.screenAndAudioRecording.settingsURL)
        XCTAssertEqual(PermissionKind.screenAndAudioRecording.displayName(language: "zh", majorVersion: 27), "录屏与系统录音")
    }
    @MainActor func testTwoCardsKeepIndependentIdentity() {
        let config = PermissionConfiguration(applicationURL: URL(fileURLWithPath: "/Applications/Test.app"), applicationName: "Test", permissions: [.deviceControl, .screenAndAudioRecording])
        XCTAssertEqual(config.permissions.count, 2)
        XCTAssertNotEqual(config.copy(for: .deviceControl)["permissionTitle"] as? String, config.copy(for: .screenAndAudioRecording)["permissionTitle"] as? String)
    }
}
