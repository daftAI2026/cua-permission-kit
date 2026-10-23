// swift-tools-version: 5.9
// [INPUT]: 依赖 SwiftPM 的包描述 API。
// [OUTPUT]: 提供库、演示 App 与测试目标。
// [POS]: 独立包入口；不依赖提取来源的工作区。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import PackageDescription
let package = Package(
    name: "CUAPermissionKit",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "CUAPermissionKit", targets: ["CUAPermissionKit"]),
        .executable(name: "CUAPermissionDemo", targets: ["CUAPermissionDemo"])
    ],
    targets: [
        .target(name: "CUAPermissionKit", exclude: ["CLAUDE.md"]),
        .executableTarget(name: "CUAPermissionDemo", dependencies: ["CUAPermissionKit"], path: "Examples/CUAPermissionDemo", exclude: ["CLAUDE.md"]),
        .testTarget(name: "CUAPermissionKitTests", dependencies: ["CUAPermissionKit"], exclude: ["CLAUDE.md"])
    ]
)
