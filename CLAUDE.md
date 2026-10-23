# CUA Permission Kit - macOS 双授权卡与拖拽向导
Swift 5.9 + SwiftUI + AppKit + Swift Package Manager

<directory>
Sources/ - 原生库源码（1 子目录：CUAPermissionKit）
Examples/ - 双卡演示与只读权限探针
script/ - 缓存目录构建与启动入口
.github/ - macOS 构建测试工作流
.codex/ - 本地运行入口配置
Tests/ - 源码一致性与可选窗口回归测试（1 子目录：CUAPermissionKitTests）
</directory>
<config>
Package.swift - 声明 macOS 12+ 库和测试目标。
README.md - 英文接入、文案协议与安全边界。
README.zh-CN.md - 中文能力与验收边界。
LICENSE - 保留提取来源的 MIT 版权声明。
.gitignore - 排除构建缓存与本机状态。
</config>

调用方执行权限检查；本库只呈现状态。
禁止加入 TCC 重置、安装器或官方二进制。
默认保持宿主激活策略不变。
先写失败测试，再修改实现。
每个源码文件不超过 800 行。
验证命令：`swift build`、`swift test`。
真实拖拽与动画验收必须单独执行。
