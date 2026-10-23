# CUAPermissionDemo/
> L2 | 父级: ../CLAUDE.md

App.swift: AppKit 入口，加载本包 Dock 图标、菜单与控制器。
DemoController.swift: 组装控制面板；向会话转发用户操作。
DemoSession.swift: 统一演示显示名；独占库接入、目标适配和只读探针。
DemoPalette.swift: Radix 语义色阶与 0.5pt 边框按钮。
DropTarget.swift: 仅在 Demo 模式接收应用 URL；系统设置模式拒收。

依赖方向：控制面板 → DemoSession → CUAPermissionKit。
Demo token、图标、接收区和模拟结果不进入库。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
