// [INPUT]: 依赖权限类型与配置接口。
// [OUTPUT]: 验证双卡名称、原句、不拆短语与设置入口。
// [POS]: 双卡合同测试，不触碰系统权限。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import XCTest
@testable import CUAPermissionKit
final class PermissionKindTests: XCTestCase {
    @MainActor func testChineseSettingsInstructionNamesSelectedPermission() {
        let config = PermissionConfiguration(applicationURL: URL(fileURLWithPath: "/Applications/Test.app"), applicationName: "Test", permissions: [.deviceControl, .screenAndAudioRecording], language: "zh")
        for permission in config.permissions {
            let instruction = config.copy(for: permission)["dragInstruction"] as? String ?? ""
            XCTAssertEqual(instruction.replacingOccurrences(of: "\u{2060}", with: ""), "将 Test 拖到上方的“\(permission.displayName(language: "zh"))”列表中，然后开启对应权限")
            XCTAssertTrue(instruction.hasSuffix("然后开启对应权限".map(String.init).joined(separator: "\u{2060}")))
            XCTAssertFalse(instruction.contains("\n"))
            let json = config.copy(for: permission)["dragInstructionRuns"] as? String ?? ""
            let runs = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [[String: String]]
            XCTAssertEqual(runs?.compactMap { $0["text"] }.joined(), instruction)
            XCTAssertEqual(runs?.filter { $0["role"] == "primary" }.compactMap { $0["text"] }, ["Test", permission.displayName(language: "zh")])
            XCTAssertTrue(instruction.contains(permission.displayName(language: "zh")))
            XCTAssertTrue(instruction.contains("Test"))
        }
    }
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
