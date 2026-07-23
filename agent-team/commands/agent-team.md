---
description: 启动专家团：先分析需求，再按需派遣相关智能体（含万事通 Atlas；Kane 仅编码）
argument-hint: "<你的目标或需求>"
---

按 `agent-team` skill 执行专家团编排：

此文件仅供 Cursor slash command 使用；Codex 请直接调用 `$agent-team`。

1. 读取本 skill 的 `SKILL.md`（或已安装的 `~/.cursor/skills/agent-team/SKILL.md`）并严格遵循
2. 专家人设：`references/experts/` 或 `~/.cursor/agents/agent-team-*.md`

用户目标：
$ARGUMENTS

先分析需求，决定本次需要哪些专家。Kane 只负责写改代码；文档/杂务/串联/兜底派 Atlas。不必全员、不必固定顺序。立刻执行并播报进展。
