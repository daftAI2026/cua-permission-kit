# Assets/
> L2 | 父级: ../CLAUDE.md

DemoIcon.icon/: Icon Composer 源文件，保留用户黑白配色。
DemoIcon.icns: 从源文件编译的旧系统静态图标。
DemoIcon.png: 默认外观预览，随源文件重新导出。
ufo.svg: 用户提供的飞碟轮廓，白色填充与图标留白。

修改图标后，在 Icon Composer 保存源文件。
同步导出 PNG，并用 actool 编译 ICNS。
Xcode 27 构建分层图标；旧工具链使用 ICNS。
图标仅用于 Demo，库不依赖这些资源。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
