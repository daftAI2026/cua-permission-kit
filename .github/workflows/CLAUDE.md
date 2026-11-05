# workflows/
> L2 | 父级: ../CLAUDE.md

ci.yml: Ubuntu 识别纯文档提交；有代码变更时在 macOS 执行完整默认测试与 Debug/Release 构建。PR 仅保留最新运行，main 每个提交独立校验；功能分支 push 由 PR 校验，避免双触发。路径识别失败会使 test 失败。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
