// [INPUT]: 依赖 CUAPermissionKit 公共接口与系统只读权限查询。
// [OUTPUT]: 提供 Demo 向导会话、模拟结果与目标适配。
// [POS]: Demo 到库的单向接入层；不定义授权卡视觉。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit
import CUAPermissionKit
import ApplicationServices
import OSLog

@MainActor
final class DemoSession {
    private weak var window: NSWindow?
    private let reportStatus: (String) -> Void
    private let shouldCheckPermission: () -> Bool
    private let logger = Logger(subsystem: "org.cuapermissionkit.demo", category: "PermissionCheck")
    private var permissionTimer: Timer?
    private var presenter: PermissionPresenter?
    private var usesDemoTarget = true

    var isPresenting: Bool { presenter != nil }

    init(window: NSWindow?, reportStatus: @escaping (String) -> Void,
         shouldCheckPermission: @escaping () -> Bool) {
        self.window = window
        self.reportStatus = reportStatus
        self.shouldCheckPermission = shouldCheckPermission
    }

    func acceptDemoDrop() {
        guard usesDemoTarget else { return }
        stopPermissionCheck()
        logger.notice("event=safe-drop-accepted")
        reportStatus("Drop verified. Demo permission completed.")
        presenter?.update(.granted)
    }

    func show(copy: [String: String], rtl: Bool, language: String, usesDemoTarget: Bool) {
        stopPermissionCheck()
        presenter?.close()
        self.usesDemoTarget = usesDemoTarget
        var configuration = PermissionConfiguration(applicationURL: Bundle.main.bundleURL, applicationName: "CUA Permission Demo", rightToLeft: rtl, localizedCopy: copy, permissions: [.deviceControl, .screenAndAudioRecording], language: language)
        if usesDemoTarget {
            configuration.localizedCopy["dragInstruction"] = language == "zh" ? "将应用拖入 Demo 接收区。" : language == "ar" ? "اسحب التطبيق إلى منطقة الاختبار." : "Drag the app into the Demo drop area."
            configuration.handoffTarget = PermissionHandoffTarget(locate: { [weak self] in
                guard let window = self?.window, let primary = NSScreen.screens.first else { return nil }
                let frame = window.frame
                return PermissionHostSettingsFrame(frame: NSRect(x: frame.minX, y: primary.frame.maxY - frame.maxY, width: frame.width, height: frame.height), pid: ProcessInfo.processInfo.processIdentifier, windowID: CGWindowID(window.windowNumber))
            }, activate: { [weak self] in
                NSApp.activate(ignoringOtherApps: true)
                self?.window?.makeKeyAndOrderFront(nil)
            })
        }
        presenter = PermissionPresenter(configuration: configuration, onEvent: { [weak self] event in
            self?.handle(event)
        }, onError: { [weak self] message in
            self?.reportStatus("Error: \(message)")
        })
        reportStatus("Preview open")
        _ = presenter?.present()
    }

    private func handle(_ event: PermissionEvent) {
        reportStatus("Event: \(event.rawValue)")
        logger.notice("event=\(event.rawValue, privacy: .public)")
        switch event {
        case .allow, .retry:
            presenter?.update(.repairing)
            if usesDemoTarget {
                window?.makeKeyAndOrderFront(nil)
                presenter?.update(.awaitingUser)
            } else if let permission = presenter?.activePermission, NSWorkspace.shared.open(permission.settingsURL) {
                presenter?.update(.awaitingUser)
                startPermissionCheck()
            } else { presenter?.update(.error) }
        case .later, .close:
            stopPermissionCheck()
            presenter?.close()
            presenter = nil
        }
    }
    func simulateSuccess() {
        stopPermissionCheck()
        presenter?.update(.granted)
        reportStatus("Success simulated")
    }
    func simulateError() {
        stopPermissionCheck()
        presenter?.update(.error)
        reportStatus("Error simulated")
    }
    func close() {
        stopPermissionCheck()
        presenter?.close()
        presenter = nil
        reportStatus("Guide closed.")
    }
    private func startPermissionCheck() {
        stopPermissionCheck()
        guard shouldCheckPermission() else { return }
        let initiallyTrusted = currentPermissionGranted()
        logger.notice("event=read-only-check-start trusted=\(initiallyTrusted)")
        reportStatus(initiallyTrusted ? "Permission verified" : "Waiting for permission")
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.permissionTimer != nil else { return }
                // 仅查询本进程，不使用会弹窗的 WithOptions(prompt: true)。
                if self.currentPermissionGranted() {
                    self.logger.notice("event=read-only-check-granted")
                    self.stopPermissionCheck()
                    self.reportStatus("Permission verified")
                    self.presenter?.update(.granted)
                }
            }
        }
        permissionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func currentPermissionGranted() -> Bool {
        switch presenter?.activePermission {
        case .deviceControl: return AXIsProcessTrusted()
        case .screenAndAudioRecording: return CGPreflightScreenCaptureAccess()
        case nil: return false
        }
    }

    private func stopPermissionCheck() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

}
