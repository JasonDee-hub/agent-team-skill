# Agent Team Skills

[中文](#中文) · [English](#english)

面向软件开发的多智能体专家团技能包，可用于 **Cursor** / **Claude Code** / **Codex**。

A multi-agent expert-team skill pack for software development. Works with **Cursor**, **Claude Code**, and **Codex**.

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Cursor-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/Platform-Claude%20Code-orange?style=flat-square" />
  <img src="https://img.shields.io/badge/Platform-Codex-brightgreen?style=flat-square" />
  <img src="https://img.shields.io/badge/Language-ZH%20%2F%20EN-red?style=flat-square" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square" />
</p>

---

## 中文

### 设计初衷

一个人开发时，往往要在「查代码、写实现、跑测试、审 diff、点界面、排故障、写说明」之间来回切换。上下文容易乱，角色也容易混——写代码的顺手改文档，排错的又开始大重构。

**Agent Team** 的目标很简单：

- 你只说清目标；
- 由主控按任务需要召唤合适的专家；
- 专家各司其职，协作完成，而不是一个模型包办所有角色。

它不是让你手动轮岗点名；按平台使用对应入口，就能启动一整场分工明确的协作。

### 它如何运作

1. **你提出目标**  
   例如：「给登录页加验证码，并补上验证证据」。

2. **主控分析需求**  
   判断这次真正需要谁：调研？写代码？测试？审查？点 UI？排障？写文档？

3. **按需派遣专家**  
   只叫需要的人，不必全员上场，也没有固定流水线顺序。能并行则并行，有依赖则串行。

4. **边做边汇报**  
   你会看到类似「正在派遣全栈工程师 Kane…」「QA Vera 正在收集测试证据…」的进展。

5. **收口验收**  
   汇总改动、验证结果与残留风险，必要时再补派。

### 专家一览

| 专家 | 职责 |
|------|------|
| 万事通 Atlas | 文档、清单、说明、综合杂务 |
| 调研员 Mira | 摸清代码与环境、定位入口 |
| 全栈工程师 Kane | 前后端实现与改码 |
| QA Vera | 执行测试/构建并整理结果 |
| 代码审查员 Reed | 代码审查与风险提醒 |
| UI 操作者 Lina | 浏览器操作与界面问题复现 |
| 故障诊断工程师 Orin | 复现问题、分析根因 |

### 如何应用

适合这些场景：

- 功能开发与小迭代  
- Bug 修复与回归验证  
- 提交前的代码审查  
- 界面问题复现  
- 发布说明、检查清单等文档杂务  
- 陌生仓库的快速摸底  

不同平台的调用方式如下。

**Cursor**

```text
/agent-team 把登录页改成支持验证码，并补上关键测试证据
```

**Claude Code**

```text
/agent-team 审查最近 diff 的安全风险
```

**Codex**

```text
$agent-team 写一份本周发布说明和上线检查清单
```

Codex 也支持自然语言触发，例如：`请用专家团帮我定位这个报错的根因，并给出最小修复建议。`

### 安装

把本仓库地址发给别人后，用下面命令安装即可（**无需密钥，需要 Git**）。

**Cursor（推荐）**

```bash
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash
```

Cursor 专家人设会安装为 `~/.cursor/agents/agent-team-*.md`，不会占用 `qa.md` 等通用文件名。

若 `curl` 拉到旧缓存，可改用：

```bash
git clone --depth 1 https://github.com/JasonDee-hub/agent-team-skill.git /tmp/agent-team-skill \
  && bash /tmp/agent-team-skill/install.sh
```

**Claude Code**

```bash
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash -s -- --claude
```

**Codex**

```bash
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash -s -- --codex
```

一次装全部目标：

```bash
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash -s -- --all
```

---

## English

### Why this exists

Solo development constantly switches between researching code, implementing features, running tests, reviewing diffs, clicking through UI, debugging failures, and writing notes. Context gets messy, and one assistant often tries to play every role at once.

**Agent Team** is built so that:

- You state the goal;
- A lead agent decides which experts are actually needed;
- Specialists collaborate with clear ownership—instead of one model doing everything poorly.

You don’t manually rotate personas. Use the platform-specific entry point and let the team divide the work.

### How it works

1. **You give a goal**  
   e.g. “Add captcha to the login page and collect verification evidence.”

2. **The lead analyzes the request**  
   Research? Implementation? Tests? Review? UI checks? Debugging? Docs?

3. **Experts are dispatched on demand**  
   Only the needed roles are called—no mandatory full roster, no fixed assembly line. Independent work can run in parallel; dependent work stays sequential.

4. **Progress is reported as it happens**  
   You’ll see updates like “Dispatching full-stack engineer Kane…” or “QA is collecting test evidence…”.

5. **Wrap-up and acceptance**  
   Changes, verification, and remaining risks are summarized; extra experts are called only if needed.

### Experts

| Expert | Focus |
|--------|--------|
| Atlas (Generalist) | Docs, checklists, notes, mixed errands |
| Mira (Researcher) | Code/environment discovery and entry points |
| Kane (Full-stack Engineer) | Frontend/backend implementation |
| Vera (QA) | Tests/builds and evidence collection |
| Reed (Code Reviewer) | Review and risk feedback |
| Lina (UI Operator) | Browser flows and visual bug reproduction |
| Orin (Troubleshooter) | Reproduction and root-cause analysis |

### How to use it

Good fits:

- Feature work and small iterations  
- Bug fixes with regression checks  
- Pre-commit / pre-PR review  
- UI issue reproduction  
- Release notes and checklists  
- Fast orientation in unfamiliar repos  

Use the entry point for your platform.

**Cursor**

```text
/agent-team Add captcha support to the login page and collect verification evidence
```

**Claude Code**

```text
/agent-team Review the latest diff for security risks
```

**Codex**

```text
$agent-team Write this week’s release notes and a launch checklist
```

Codex also supports natural-language triggers, for example: `Use the expert team to reproduce this error, find the root cause, and suggest a minimal fix.`

### Install

Share this repo URL, then install with (**no key required; Git is required**):

**Cursor (recommended)**

```bash
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash
```

Cursor expert personas are installed as `~/.cursor/agents/agent-team-*.md`, so generic names such as `qa.md` are left untouched.

If `curl` hits a stale cache:

```bash
git clone --depth 1 https://github.com/JasonDee-hub/agent-team-skill.git /tmp/agent-team-skill \
  && bash /tmp/agent-team-skill/install.sh
```

**Claude Code**

```bash
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash -s -- --claude
```

**Codex**

```bash
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash -s -- --codex
```

Install everywhere:

```bash
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash -s -- --all
```

---

## License

[MIT License](LICENSE)
