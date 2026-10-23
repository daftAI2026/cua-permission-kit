# CUAPermissionKit/
> L2 | 父级: ../CLAUDE.md

成员清单
PermissionKind.swift: 稳定权限身份、版本化文案与独立设置路由。
PermissionHandoffTarget.swift: 注入目标窗口几何与激活动作。
Diagnostics.swift: OSLog 调试探针，仅记录本进程事件与窗口布尔状态。
PermissionConfiguration.swift: 声明应用身份与状态；沿用原始提示模板；中文末尾短语保持整体换行。
PermissionPresenter.swift: 持有窗口与向导状态；返回动作等待当前飞行结束。
PresenterTracking.swift: 扩展 Presenter，定位目标窗口；恢复时清除本轮动作并复用初始窗口。
PresenterSupport.swift: 提供窗口代理、拖拽源和坐标转换。
InitialView.swift: 渲染初始授权卡与设置占位页。
HelperView.swift: 渲染配置中的应用身份、拖拽行与箭头。
ViewSupport.swift: 提供透明前景快照、显示时钟和富文本。
Flight.swift: 驱动过渡窗口与弹簧插值，不执行权限动作。
SettingsLocator.swift: 读取系统设置窗口几何，不读取权限状态。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
