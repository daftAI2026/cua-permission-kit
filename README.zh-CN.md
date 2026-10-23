# CUA Permission Kit

从 Incodex 提取的 macOS 原生授权卡。独立社区项目，不代表 OpenAI。

## 使用

```sh
./script/build_and_run.sh
swift test
CUA_RUN_WINDOW_TESTS=1 swift test
```

完整接入代码与 API 见 [英文说明](README.md)。

- 两张卡：设备控制和数据访问、录屏与系统录音。
- 旧系统按版本显示辅助功能、屏幕录制。
- 默认保留单卡接入；通过 `permissions` 启用双卡。
- 保留原始卡片 token、拖拽行和弹簧动画。
- 录屏图标从系统读取；缺失时使用 SF Symbol。
- Demo 控制区独立使用 Radix 色阶与集中式 token。

## 演示与真实授权

默认拖入 Demo 接收区，验证本应用的文件 URL。
接收成功只模拟当前卡完成，不修改系统权限。
卡片回飞后显示“已完成”，另一张卡继续可用。
两张完成后关闭向导。Restart 仅重置演示状态。

选择 System Settings 后再打开预览，可进入对应设置页。
可选只读探针检查设备控制或屏幕捕获权限。
屏幕捕获探针不单独证明仅音频权限。
库不申请权限，不重置 TCC，不提权。
Demo 从用户缓存目录运行，避免 Desktop 拖拽授权弹窗。

## 已验证与边界

macOS 27.0.1 arm64 上实测两次原生拖拽、逐卡完成与重来。
14 项测试通过，包含三项真实窗口测试。
五个原始视觉和动画代码块通过指纹校验。
该校验不等于所有系统版本上的像素一致。

Incodex 原始实现只接入辅助功能卡，双卡是本次扩展。
真实系统授权变更、录屏页专属定位、多屏及旧系统仍需验收。
不宣称复制了未公开的 CUA 实现。

提取基线：`c7340c97f4d9ecd7b0035f50bac1f526dc34e477`。
版权见 [LICENSE](LICENSE)，色板声明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
