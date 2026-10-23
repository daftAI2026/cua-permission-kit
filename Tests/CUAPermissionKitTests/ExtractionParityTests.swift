// [INPUT]: 依赖 CryptoKit 与本包源码；基线来自 Incodex c7340c9。
// [OUTPUT]: 锁定原始卡片、按钮、应用行与弹簧代码指纹。
// [POS]: 提取一致性守卫；仅忽略多卡快捷键和应用名注入。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import XCTest
import CryptoKit

final class ExtractionParityTests: XCTestCase {
    func testOriginalVisualAndMotionBlocksRemainUnchanged() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let cases: [(String, String, String, String, String)] = [
        ("allowStyle", "InitialView.swift", "private struct PermissionAllowButtonStyle:", "private struct PermissionAllowButtonFace", "c139629c350dda93688832cb597fa96f204806f2ed7ec790c04eab3cda69bed4"),
        ("allowFace", "InitialView.swift", "private struct PermissionAllowButtonFace", "private struct PermissionCardRoot:", "74857b08756b45f62396b0ea0bb294076500e3cebc15198a20a2d5b0950ad197"),
        ("cardVisual", "InitialView.swift", "private struct PermissionCardRoot:", "private struct PermissionPlaceholderLabel", "33723da07c507d6242fa94d2bd297c23645091360bad86b59bfb4dc5e6d68d8d"),
        ("appRow", "HelperView.swift", "private struct PermissionHelperAppRowRoot:", "// The live draggable row", "1e1bd4bf702329aecf8484ff5c729dffc262689c3a8b555703f66a2b73a166e8"),
        ("spring", "Flight.swift", "struct PermissionHostSpring {", "struct PermissionHostFlightSample", "32484c641750180d4a30612327f89254469c76cf47eca6b3941aa2a1237899c4"),
        ]
        for (name, file, start, end, expected) in cases {
            let source = try String(contentsOf: root.appendingPathComponent("Sources/CUAPermissionKit/\(file)"), encoding: .utf8)
            let first = try XCTUnwrap(source.range(of: start))
            let last = try XCTUnwrap(source.range(of: end, range: first.upperBound..<source.endIndex))
            let block = source[first.lowerBound..<last.lowerBound].components(separatedBy: "\n")
                .filter { !$0.contains(".keyboardShortcut") }.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "Text(\"ChatGPT\")", with: "Text(state.applicationName)")
            let hash = SHA256.hash(data: Data(block.utf8)).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(hash, expected, "Original \(name) changed; review against the extraction baseline")
        }
    }
}
