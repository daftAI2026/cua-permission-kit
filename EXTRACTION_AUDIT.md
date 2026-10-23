# Incodex 提取差异核对

基线：`c7340c97f4d9ecd7b0035f50bac1f526dc34e477`。
2026-10-23 核对时，Incodex HEAD 与基线相同。
只读对照 Incodex；未修改原仓库。

## 保留项

`ExtractionParityTests` 锁定八个原始代码块。
来源为 `native/macos/permission-views.swift` 和 `permission-host-flight.swift`。
覆盖按钮、卡片、应用行、提示布局、行外框、换行测量和弹簧。
只允许应用名注入及多卡默认快捷键适配。
提示布局保留 531pt 宽度、18pt 左边距及原始间距。
换行沿用原始 SwiftUI 测量，不插入人为换行。

## 已纠正的提取偏差

配置曾改写拖拽提示，并遗漏语义颜色片段。
恢复 `incognito-accessibility-copy-runs.ts` 的中英阿模板。
只替换应用名和当前权限名；保留词序及标点。
Demo 接收区的提示由 DemoSession 注入。
渲染器不推断或重写应用名的颜色片段。

## 明确保留的扩展

原始入口只接入辅助功能；本库支持两张独立权限卡。
应用路径、名称、图标及定位目标由调用方提供。
DemoSession 持有模拟状态和只读探针；库不查询授权。
宿主默认保留自身激活策略，不套用独立辅助进程策略。
修复多卡返回状态、窗口复用及飞行动画期间的返回请求。
Demo 图标与 Radix token 不属于库的视觉实现。

## Demo 实机验收

2026-10-23 使用原生 AX 与鼠标事件复验。
两张卡分别拖入 Demo，第一张回飞并显示“已完成”。
第二张完成后关闭向导；Restart 恢复两张“允许”。
Dock 截图确认显示黑白飞碟，不再显示通用应用图标。
启动入口显式加载本包 ICNS；不刷新全局 Dock 缓存。
测试未授予、重置或撤销任何系统权限。

## 尚未关闭的差异与验收项

原始拖拽使用延迟 pasteboard provider；本库使用文件 URL writer。
本库在小卡 mouseDown 激活目标；原始入口只在 revealHelper 激活。
这两项不属于视觉一致性证明，尚需真实交互核对。
点击小卡前置 Settings 已在当前构建实测通过。
先点击 Demo 控制区，再点小卡，前台切换为 Settings。
真实授权变更、多屏、旧系统和录屏页定位仍需验收。
八个代码块相同不等于整个 CUA 行为或所有像素完全相同。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
