// [INPUT]: 依赖 AppKit 的图像类型与 Foundation 的 URL。
// [OUTPUT]: 提供应用配置、语义文案、授权状态与事件。
// [POS]: 调用方与表现层的边界；调用方执行权限检查。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit

public enum PermissionEvent: String { case allow, retry, later, close }
public enum PermissionState: String {
    case repairing
    case awaitingUser = "awaiting-user"
    case granted
    case error
}

@MainActor
public struct PermissionConfiguration {
    public let applicationURL: URL
    public let applicationName: String
    public var applicationIcon: NSImage?
    public var permissionIcon: NSImage?
    public var rightToLeft: Bool
    public let permissions: [PermissionKind]
    public var language: String
    public var handoffTarget: PermissionHandoffTarget = .systemSettings
    /// 仅独立辅助进程启用；嵌入应用时不得改变宿主激活策略。
    public var managesActivationPolicy = false
    public var localizedCopy: [String: String]

    public init(applicationURL: URL, applicationName: String,
                applicationIcon: NSImage? = nil, permissionIcon: NSImage? = nil,
                rightToLeft: Bool = false, localizedCopy: [String: String] = [:],
                permissions: [PermissionKind] = [.deviceControl], language: String = "en") {
        precondition(!permissions.isEmpty && Set(permissions).count == permissions.count, "Permissions must be nonempty and unique")
        self.permissions = permissions
        self.language = language
        self.applicationURL = applicationURL
        self.applicationName = applicationName
        self.applicationIcon = applicationIcon
        self.permissionIcon = permissionIcon
        self.rightToLeft = rightToLeft
        self.localizedCopy = localizedCopy
    }

    var copy: NSDictionary { copy(for: permissions[0]) }

    func copy(for permission: PermissionKind) -> NSDictionary {
        let name = permission.displayName(language: language)
        // 沿用 Incodex 的逐语言语义片段，只替换应用与权限身份。
        let spans: [(String, String)]
        if language.hasPrefix("zh") {
            // 不拆分末尾操作短语；沿用自然换行，不改原始视图几何。
            let completion = "然后开启对应权限".map(String.init).joined(separator: "\u{2060}")
            spans = [("将 ", "secondary"), (applicationName, "primary"),
                     (" 拖到上方的“", "secondary"), (name, "primary"),
                     ("”列表中，\(completion)", "secondary")]
        } else if language.hasPrefix("ar") {
            spans = [("اسحب ", "secondary"), (applicationName, "primary"),
                     (" إلى القائمة أعلاه لمنحه إذن ", "secondary"), (name, "primary")]
        } else {
            spans = [("Drag ", "secondary"), (applicationName, "primary"),
                     (" to the list above to allow ", "secondary"), (name, "primary")]
        }
        let dragInstruction = spans.map { $0.0 }.joined()
        let runs = spans.map { ["text": $0.0, "role": $0.1] }
        let runsJSON = (try? JSONSerialization.data(withJSONObject: runs))
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        var values = [
            "title": "Allow Access",
            "body": "Choose which access to allow for \(applicationName).",
            "permissionTitle": name,
            "permissionDescription": permission.detail(language: language),
            "repair": "Allow", "later": "Skip", "back": "Back",
            "granted": language.hasPrefix("zh") ? "已完成" : "Allowed",
            "addedTitle": "Complete in System Settings",
            "addedBody": "Add \(applicationName) to the \(name) list.",
            "dragInstruction": dragInstruction,
            "dragInstructionRuns": runsJSON, "completeInSettings": "Complete in System Settings",
            "checking": "Checking…", "repairing": "Opening Settings…",
            "openSettings": "Open System Settings", "errorTitle": "Permission Not Available",
            "errorBody": "Check access in System Settings, then try again."
        ]
        values.merge(localizedCopy) { _, replacement in replacement }
        values["applicationName"] = applicationName
        values["layoutDirection"] = rightToLeft ? "rightToLeft" : "leftToRight"
        return values as NSDictionary
    }
}
