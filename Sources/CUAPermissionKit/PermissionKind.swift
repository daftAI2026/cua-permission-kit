// [INPUT]: 依赖 Foundation 的系统版本与 URL。
// [OUTPUT]: 声明两项权限的显示名称、图标和设置入口。
// [POS]: 区分稳定权限身份与系统版本对应的用户文案。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import Foundation

public enum PermissionKind: String, CaseIterable, Hashable {
    case deviceControl
    case screenAndAudioRecording

    public var settingsURL: URL {
        let pane = self == .deviceControl ? "Privacy_Accessibility" : "Privacy_ScreenCapture"
        return URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(pane)")!
    }

    public func displayName(language: String = "en", majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) -> String {
        if language.hasPrefix("zh") {
            if self == .deviceControl { return majorVersion >= 27 ? "设备控制和数据访问" : "辅助功能" }
            return majorVersion >= 14 ? "录屏与系统录音" : "屏幕录制"
        }
        if language.hasPrefix("ar") {
            if self == .deviceControl { return majorVersion >= 27 ? "التحكم في الأجهزة والوصول إلى البيانات" : "تسهيلات الاستخدام" }
            return "تسجيل الشاشة وصوت النظام"
        }
        if self == .deviceControl { return majorVersion >= 27 ? "Device Control and Data Access" : "Accessibility" }
        return majorVersion >= 14 ? "Screen & System Audio Recording" : "Screen Recording"
    }

    func detail(language: String) -> String {
        if language.hasPrefix("zh") { return self == .deviceControl ? "操作应用与访问设备数据。" : "获取屏幕内容与系统音频。" }
        if language.hasPrefix("ar") { return self == .deviceControl ? "التحكم في التطبيقات والوصول إلى البيانات." : "الوصول إلى الشاشة وصوت النظام." }
        return self == .deviceControl ? "Control apps and access device data." : "Capture the screen and system audio."
    }
}
