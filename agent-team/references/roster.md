# 专家团花名册

本包提供 **1 个编排 Skill + 7 位专家人设**。编排入口是 `SKILL.md`（`/agent-team`）；人设在 `experts/`；交接格式见 [handoff.md](handoff.md)。

## 分工速记

| 需求类型 | 优先派遣 |
|----------|----------|
| 写改代码、实现功能、联调 | Kane |
| 文档、清单、杂务、串联、边界不清先推进 | Atlas |
| 陌生库摸底、依赖/环境核查 | Mira |
| 跑测试/构建并收集证据 | Vera |
| Code review / 合并前把关 | Reed |
| 浏览器点选、视觉复现 | Lina |
| 报错复现与根因 | Orin |

## 按需原则

- 不是固定流水线，也不是全员必上。
- 主控根据用户目标选人；计划中应简述「为何不用某人」。
- Kane 不是万事通；非编码主场交给 Atlas 或其他专家。
- 派遣/回报统一走交接协议，避免上下文丢失。
- **开发主场默认精简工程**：实现/审查/排障改码遵循 [lean.md](lean.md)（内化极简实现与过度工程审查，不依赖外部 skill）。
- **域外知识工作（小说/论文/纪要/方案等）不扩编花名册**；主控先 grill-me 式**选项题**（一次一问、★ 推荐、总题≤5、答完第 1 问后公布还剩几问）追问到准确共识，再只派 Atlas（禁止三档填表、禁止无上限连环问）。

## 停手边界（摘要）

| 角色 | 默认停手 |
|------|----------|
| Kane | 不接文档杂务；根因不清 → Orin；系统化测试 → Vera |
| Orin | 默认只诊断开处方；大改实现 → Kane |
| Vera | 先取证不修产品代码；产品缺陷 → Orin/Kane |

## 人设文件

| 花名 | 文件 |
|------|------|
| 万事通 Atlas | [experts/generalist.md](experts/generalist.md) |
| 调研员 Mira | [experts/researcher.md](experts/researcher.md) |
| 全栈工程师 Kane | [experts/fullstack-engineer.md](experts/fullstack-engineer.md) |
| QA Vera | [experts/qa.md](experts/qa.md) |
| 代码审查员 Reed | [experts/code-reviewer.md](experts/code-reviewer.md) |
| UI 操作者 Lina | [experts/ui-operator.md](experts/ui-operator.md) |
| 故障诊断工程师 Orin | [experts/troubleshooter.md](experts/troubleshooter.md) |
