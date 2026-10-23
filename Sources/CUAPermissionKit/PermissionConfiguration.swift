// [INPUT]: 依赖 AppKit 的图像类型与 Foundation 的 URL。
// [OUTPUT]: 提供应用配置、授权状态与用户事件。
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
        var values = [
            "title": "Allow Access",
            "body": "Choose which access to allow for \(applicationName).",
            "permissionTitle": name,
            "permissionDescription": permission.detail(language: language),
            "repair": "Allow", "later": "Skip", "back": "Back",
            "granted": language.hasPrefix("zh") ? "已完成" : "Allowed",
            "addedTitle": "Complete in System Settings",
            "addedBody": "Add \(applicationName) to the \(name) list.",
            "dragInstruction": "Drag \(applicationName) into the \(name) list, then enable it.",
            "dragInstructionRuns": "", "completeInSettings": "Complete in System Settings",
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
