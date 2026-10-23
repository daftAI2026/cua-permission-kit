// [INPUT]: 依赖 AppKit 与 Radix Gray、Blue 的明暗色阶。
// [OUTPUT]: 提供演示面板语义颜色与无阴影按钮。
// [POS]: 仅约束 Demo 样式，不覆盖授权卡视觉。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit

enum DemoTokens {
    static let body: CGFloat = 13
    static let caption: CGFloat = 12
    static let gap: CGFloat = 14
    static let inset: CGFloat = 28
    static let topInset: CGFloat = 24
    static let radius: CGFloat = 6
    static let border: CGFloat = 0.5
    static let controlHeight: CGFloat = 30
    static let horizontalButtonPadding: CGFloat = 24
    static let dropHeight: CGFloat = 120
}

enum DemoPalette {
    static let background = color("fcfcfc", "111111") // Gray 1
    static let surface = color("f9f9f9", "191919") // Gray 2
    static let control = color("f0f0f0", "222222") // Gray 3
    static let pressed = color("e0e0e0", "313131") // Gray 5
    static let border = color("cecece", "484848") // Gray 7
    static let secondary = color("646464", "b4b4b4") // Gray 11
    static let text = color("202020", "eeeeee") // Gray 12
    static let accent = color("0d74ce", "70b8ff") // Blue 11

    private static func color(_ light: String, _ dark: String) -> NSColor {
        NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            let number = UInt32(hex, radix: 16)!
            return NSColor(srgbRed: CGFloat((number >> 16) & 255) / 255, green: CGFloat((number >> 8) & 255) / 255, blue: CGFloat(number & 255) / 255, alpha: 1)
        }
    }
}

final class DemoButton: NSButton {
    override var intrinsicContentSize: NSSize {
        let text = (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: DemoTokens.body)])
        return NSSize(width: ceil(text.width) + DemoTokens.horizontalButtonPadding, height: DemoTokens.controlHeight)
    }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: DemoTokens.border / 2, dy: DemoTokens.border / 2), xRadius: DemoTokens.radius, yRadius: DemoTokens.radius)
        (isHighlighted ? DemoPalette.pressed : DemoPalette.control).setFill()
        path.fill()
        DemoPalette.border.setStroke()
        path.lineWidth = DemoTokens.border
        path.stroke()
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: DemoTokens.body), .foregroundColor: DemoPalette.text]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
}
