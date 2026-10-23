// [INPUT]: 依赖 AppKit、CUAPermissionKit 与安全拖拽落点。
// [OUTPUT]: 提供英文、中文、RTL 演示及模拟结果按钮。
// [POS]: 库的接入示例；真实授权由调用方检查，本例不申请。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit
import CUAPermissionKit
import ApplicationServices
import OSLog

@MainActor
final class DemoController: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var dropTarget: DropTarget?
    private let logger = Logger(subsystem: "org.cuapermissionkit.demo", category: "PermissionCheck")
    private var permissionTimer: Timer?
    private let destination = NSPopUpButton(frame: .zero, pullsDown: false)
    private var usesDemoTarget = true
    private var lastCopy: [String: String] = [:]
    private var lastLanguage = "en"
    private var lastRTL = false
    private let readOnlyCheck = NSButton(checkboxWithTitle: "Read-only permission check", target: nil, action: nil)
    private var presenter: PermissionPresenter?
    private let status = NSTextField(wrappingLabelWithString: "Ready")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentRect: NSRect(x: 60, y: 80, width: 600, height: 540), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "CUA Permission Kit Demo"
        window.backgroundColor = DemoPalette.background
        window.isReleasedWhenClosed = false
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = DemoTokens.gap
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(section("Preview"))
        stack.addArrangedSubview(NSStackView(views: [button("English", #selector(showEnglish)), button("中文", #selector(showChinese)), button("العربية", #selector(showRTL))]))
        destination.addItems(withTitles: ["Demo", "System Settings"])
        destination.font = .systemFont(ofSize: DemoTokens.body)
        stack.addArrangedSubview(NSStackView(views: [section("Drag destination"), destination]))
        readOnlyCheck.state = .on
        readOnlyCheck.font = .systemFont(ofSize: DemoTokens.body)
        readOnlyCheck.contentTintColor = DemoPalette.accent
        readOnlyCheck.toolTip = "Reads the selected permission. Never requests or resets access."
        stack.addArrangedSubview(readOnlyCheck)
        stack.addArrangedSubview(section("Result"))
        stack.addArrangedSubview(NSStackView(views: [button("Simulate Success", #selector(granted)), button("Simulate Error", #selector(failed)), button("Restart", #selector(restart)), button("Close", #selector(closeGuide))]))
        status.font = .systemFont(ofSize: DemoTokens.caption)
        status.textColor = DemoPalette.secondary
        stack.addArrangedSubview(status)
        status.heightAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true
        let drop = DropTarget(frame: .zero)
        dropTarget = drop
        drop.onAccepted = { [weak self] in
            self?.stopPermissionCheck()
            self?.logger.notice("event=safe-drop-accepted")
            self?.status.stringValue = "Drop verified. Demo permission completed."
            self?.presenter?.update(.granted)
        }
        drop.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(drop)
        drop.heightAnchor.constraint(equalToConstant: DemoTokens.dropHeight).isActive = true
        guard let content = window.contentView else { return }
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: DemoTokens.inset),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -DemoTokens.inset),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: DemoTokens.topInset),
            drop.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // 由用户选择语言后打开授权卡；点击接收区不触发窗口。
    }

    func applicationWillTerminate(_ notification: Notification) { stopPermissionCheck(); presenter?.close() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = DemoButton(title: title, target: self, action: action)
        button.isBordered = false
        button.font = .systemFont(ofSize: DemoTokens.body)
        return button
    }

    private func section(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: DemoTokens.caption, weight: .semibold)
        label.textColor = DemoPalette.text
        return label
    }

    @objc private func showEnglish() { show(copy: [:], rtl: false, language: "en") }
    @objc private func showChinese() {
        show(copy: [
            "title": "允许访问", "body": "选择允许 CUA Permission Demo 使用的权限。",
            "repair": "允许", "later": "跳过", "back": "返回", "completeInSettings": "在系统设置中完成",
            "dragInstruction": "将 CUA Permission Demo 拖入下方测试区，验证拖拽，不修改权限。",
            "errorTitle": "模拟授权失败", "errorBody": "这是演示状态，没有修改系统权限。"
         ], rtl: false, language: "zh")
    }
    @objc private func showRTL() {
        show(copy: ["title": "إمكانية الوصول", "body": "عرض توضيحي فقط — لا يتم تغيير الأذونات.", "repair": "السماح", "later": "تخطي", "back": "رجوع", "dragInstruction": "اسحب التطبيق إلى منطقة الاختبار."], rtl: true, language: "ar")
    }

    @objc private func restart() { show(copy: lastCopy, rtl: lastRTL, language: lastLanguage) }

    private func show(copy: [String: String], rtl: Bool, language: String) {
        dropTarget?.reset()
        lastCopy = copy
        lastLanguage = language
        lastRTL = rtl
        stopPermissionCheck()
        presenter?.close()
        usesDemoTarget = destination.indexOfSelectedItem == 0
        var configuration = PermissionConfiguration(applicationURL: Bundle.main.bundleURL, applicationName: "CUA Permission Demo", applicationIcon: NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Demo app"), rightToLeft: rtl, localizedCopy: copy, permissions: [.deviceControl, .screenAndAudioRecording], language: language)
        if usesDemoTarget {
            configuration.localizedCopy["dragInstruction"] = language == "zh" ? "将应用拖入 Demo 接收区。" : "Drag the app into the Demo drop area."
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
            self?.status.stringValue = "Error: \(message)"
        })
        status.stringValue = "Preview open"
        _ = presenter?.present()
    }

    private func handle(_ event: PermissionEvent) {
        status.stringValue = "Event: \(event.rawValue)"
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
    @objc private func granted() {
        stopPermissionCheck()
        presenter?.update(.granted)
        status.stringValue = "Success simulated"
    }
    @objc private func failed() {
        stopPermissionCheck()
        presenter?.update(.error)
        status.stringValue = "Error simulated"
    }
    @objc private func closeGuide() {
        stopPermissionCheck()
        presenter?.close()
        presenter = nil
        status.stringValue = "Guide closed."
    }
    private func startPermissionCheck() {
        stopPermissionCheck()
        guard readOnlyCheck.state == .on else { return }
        let initiallyTrusted = currentPermissionGranted()
        logger.notice("event=read-only-check-start trusted=\(initiallyTrusted)")
        status.stringValue = initiallyTrusted ? "Permission verified" : "Waiting for permission"
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.permissionTimer != nil else { return }
                // 仅查询本进程，不使用会弹窗的 WithOptions(prompt: true)。
                if self.currentPermissionGranted() {
                    self.logger.notice("event=read-only-check-granted")
                    self.stopPermissionCheck()
                    self.status.stringValue = "Permission verified"
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
