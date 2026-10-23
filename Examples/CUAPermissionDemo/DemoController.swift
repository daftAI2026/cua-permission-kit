// [INPUT]: 依赖 AppKit、DemoSession 与 Demo 专用视觉 token。
// [OUTPUT]: 提供 Demo 控制面板与接收区。
// [POS]: Demo 窗口组装层；通过会话转发操作，不直接调用库。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit

@MainActor
final class DemoController: NSObject, NSApplicationDelegate {
    private lazy var session = DemoSession(window: window, reportStatus: { [weak self] message in
        self?.status.stringValue = message
    }, shouldCheckPermission: { [weak self] in self?.readOnlyCheck.state == .on })
    private var window: NSWindow?
    private var dropTarget: DropTarget?
    private let destination = NSPopUpButton(frame: .zero, pullsDown: false)
    private var lastCopy: [String: String] = [:]
    private var lastLanguage = "en"
    private var lastRTL = false
    private let readOnlyCheck = NSButton(checkboxWithTitle: "Read-only permission check", target: nil, action: nil)
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
        destination.target = self
        destination.action = #selector(destinationChanged)
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
        drop.onAccepted = { [weak self] in self?.session.acceptDemoDrop() }
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

    func applicationWillTerminate(_ notification: Notification) { session.close() }
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
            "title": "允许访问", "body": "选择允许 \(DemoSession.applicationName) 使用的权限。",
            "repair": "允许", "later": "跳过", "back": "返回", "completeInSettings": "在系统设置中完成",
            "errorTitle": "模拟授权失败", "errorBody": "这是演示状态，没有修改系统权限。"
         ], rtl: false, language: "zh")
    }
    @objc private func showRTL() {
        show(copy: ["title": "إمكانية الوصول", "body": "عرض توضيحي فقط — لا يتم تغيير الأذونات.", "repair": "السماح", "later": "تخطي", "back": "رجوع"], rtl: true, language: "ar")
    }

    @objc private func destinationChanged() {
        guard session.isPresenting else { return }
        restart()
    }

    @objc private func restart() { show(copy: lastCopy, rtl: lastRTL, language: lastLanguage) }

    private func show(copy: [String: String], rtl: Bool, language: String) {
        lastCopy = copy
        lastLanguage = language
        lastRTL = rtl
        let usesDemoTarget = destination.indexOfSelectedItem == 0
        dropTarget?.reset(enabled: usesDemoTarget)
        session.show(copy: copy, rtl: rtl, language: language, usesDemoTarget: usesDemoTarget)
    }

    @objc private func granted() { session.simulateSuccess() }
    @objc private func failed() { session.simulateError() }
    @objc private func closeGuide() { session.close() }
}
