// [INPUT]: 依赖 AppKit 的文件 URL 拖拽协议。
// [OUTPUT]: 显示拖拽 URL 是否匹配演示应用。
// [POS]: 无副作用的验收落点；不连接 TCC。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit

@MainActor
final class DropTarget: NSBox {
    var onAccepted: (() -> Void)?
    private let label = NSTextField(wrappingLabelWithString: "Drop app here")

    override init(frame: NSRect) {
        super.init(frame: frame)
        title = ""
        boxType = .custom
        borderColor = DemoPalette.border
        borderWidth = DemoTokens.border
        fillColor = DemoPalette.surface
        cornerRadius = DemoTokens.radius
        label.font = .systemFont(ofSize: DemoTokens.body)
        label.textColor = DemoPalette.secondary
        registerForDraggedTypes([.fileURL])
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(label)
        if let contentView {
            NSLayoutConstraint.activate([
                label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
            ])
        }
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    func reset() { label.stringValue = "Drop app here" }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let raw = sender.draggingPasteboard.string(forType: .fileURL), let url = URL(string: raw) else { return false }
        let matches = url.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
        label.stringValue = matches ? "File URL verified" : "Unexpected file URL"
        if matches { onAccepted?() }
        return matches
    }
}
