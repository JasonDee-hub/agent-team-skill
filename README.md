# Agent Team Skill

[中文](#中文) · [English](#english)

面向软件开发的多智能体专家团技能包。安装后可在 **Cursor** / **Claude Code** / **Codex** 中让主控按任务需要调度专家，完成调研、实现、测试、审查、UI 复现、排障和文档工作。

A multi-agent expert-team skill pack for software development. After installation, a lead agent can coordinate specialists in **Cursor**, **Claude Code**, and **Codex** for research, implementation, testing, review, UI reproduction, troubleshooting, and docs.

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Cursor-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/Platform-Claude%20Code-orange?style=flat-square" />
  <img src="https://img.shields.io/badge/Platform-Codex-brightgreen?style=flat-square" />
  <img src="https://img.shields.io/badge/Language-ZH%20%2F%20EN-red?style=flat-square" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square" />
</p>

---

## 中文

### 快速开始

默认安装到 Cursor：

```bash
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash
```

安装到其它平台：

```bash
# Claude Code
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash -s -- --claude

# Codex
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash -s -- --codex

# 一次安装全部目标
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash -s -- --all
```

安装不需要 API key，但需要本机可用的 `git` 与 `tar`。若 `curl` 命中旧缓存，可改用：

```bash
git clone --depth 1 https://github.com/JasonDee-hub/agent-team-skill.git /tmp/agent-team-skill \
  && bash /tmp/agent-team-skill/install.sh
```

安装后按平台调用：

| 平台 | 入口 | 示例 |
|------|------|------|
| Cursor | `/agent-team` | `/agent-team 给登录页加验证码，并补上关键测试证据` |
| Claude Code | `/agent-team` | `/agent-team 审查最近 diff 的安全风险` |
| Codex | `$agent-team` | `$agent-team 写一份本周发布说明和上线检查清单` |

Codex 也支持自然语言触发，例如：`请用专家团帮我定位这个报错的根因，并给出最小修复建议。`

### 这是什么

Agent Team 是一个“主控 + 专家”的编排技能，不是固定流水线，也不是让你手动轮岗点名。

你只需要说清目标。主控会判断这次真正需要哪些角色，并在任务开始时披露执行模式：

- `real_multi_agent`：平台支持真实独立智能体/进程，专家可以按依赖协作；只有这种模式下的 QA 或审查才能称为独立验证。
- `single_agent_simulation`：平台不支持独立智能体时，主控只在职责确实变化时切换必要人设，共用一份权限与验收台账；不会伪称并行或独立验收。

适合使用 Agent Team 的场景：

- 功能开发与小迭代
- Bug 修复与回归验证
- 提交前的代码审查
- UI 问题复现与取证
- 陌生仓库快速摸底
- 发布说明、检查清单等开发向文档工作

不适合使用的场景：

- 你只是想让一个普通 subagent 完成单一回答，没有专家分工或独立验收需求。
- 你要求医疗、法律、财务、监管等高风险领域的权威成品。
- 你要求提交、发布、部署、生产写入等外部高影响动作，但没有给出明确授权。

### 工作方式

1. **判断任务层级**
   微型/只读问题，以及授权明确、不涉及安全/数据/依赖/CI/生产等风险的单文件小改动，由主控走快路径直接完成；单一领域默认只派一位专家；复合或高风险任务才进入严格路径。

2. **按需派遣专家**
   不默认全员上场，也不自动追加 QA 或审查。标准路径的一位专家逐项通过且证据充分时，一次派遣、一次回收后直接收口，不重复验证、读取或做展示性复核。只有用户明确要求独立验收，或风险确实需要独立证据时才增加 Vera/Reed。

3. **先声明权限边界**
   新 agent 使用完整派遣包；复用同一 agent/同一角色时只发送失败或变化的验收项与必要新证据，但仍完整重申 `write_authority`、读写路径、环境与外部动作边界。缺少明确写授权时，一律按只读处理。

4. **关键节点同步进展**
   只有在开始派遣、阻塞或改派、长阶段完成可验证里程碑、最终收口时才汇报，避免循环发送空状态。

5. **收口验收**
   严格路径只增加验收必需的独立角色，无依赖只读验收可并行。与验收或既有明确行为冲突的风险必须判为失败/阻塞，不能降级进 `risks` 后报完成；交同一 Kane 增量修复后，由同一审查者只复核 delta，仅出现新风险时扩大范围。

输出跟随用户当前使用的语言；无法判断时才默认简体中文。医疗、法律、财务、监管等高风险域外任务仅提供中立提纲、有来源的清单/问题，或须由合格专业人员复核的非权威草稿。

### 专家角色

| 专家 | 职责 |
|------|------|
| 万事通 Atlas | 文档、清单、一次性非产品辅助工作 |
| 调研员 Mira | 摸清代码与环境、定位入口 |
| 全栈工程师 Kane | 产品代码/配置、CI、构建、依赖与技术方案 |
| QA Vera | 测试、构建、纯测试改动与验证证据 |
| 代码审查员 Reed | 代码审查与风险提醒 |
| UI 操作者 Lina | 浏览器操作与界面问题复现 |
| 故障诊断工程师 Orin | 复现问题、分析根因 |

### 示例与行为回放

典型交付样本放在 [`examples/`](examples/)：

- 功能实现后独立 QA：[feature-with-independent-qa.md](examples/feature-with-independent-qa.md)
- 只读安全审查：[readonly-review.md](examples/readonly-review.md)
- 写入范围不足时如实阻塞：[scope-blocked.md](examples/scope-blocked.md)
- UI 问题复现与取证：[ui-reproduction.md](examples/ui-reproduction.md)
- 高风险域外任务阻塞：[high-risk-blocked.md](examples/high-risk-blocked.md)

真实型任务回放基线放在 `evals/replay-cases.json`，当前包含 15 条覆盖文档、实现、QA、审查、UI、排障、计划、并行、安全、scope 和阻塞的需求。`evals/replay-results.json` 记录本轮按当前 skill 规则得到的机器可读行为结果，字段包括是否正确派遣、是否过度派遣、是否如实阻塞和是否真实完成。

验证回放结果：

```bash
python3 scripts/run-behavior-evals.py
```

接入真实 agent runner 时，让 runner 输出同样结构的实际结果 JSON，然后执行：

```bash
python3 scripts/run-behavior-evals.py --actual path/to/results.json
```

该脚本校验行为结果 JSON，不直接执行 agent。真实运行由 Cursor / Claude Code / Codex 或外部 harness 负责。

### 安装位置

安装器只维护每个平台的一份 Agent Team 副本：

| 平台 | 安装路径 |
|------|----------|
| Cursor | `~/.cursor/skills/agent-team`、`~/.cursor/agents/agent-team-*.md`、`~/.cursor/commands/agent-team.md` |
| Claude Code | `~/.claude/skills/agent-team` |
| Codex | `${CODEX_HOME:-~/.codex}/skills/agent-team` |

重复运行安装命令即可升级。内容完全一致时不会重复备份。

### 升级与安全

- 远程安装会核对缓存的 Git origin。已有缓存只作为对象参考，实际 fetch 在隔离的临时仓库中完成，再从所请求 ref 的提交导出干净源码。
- 缓存中的工作树修改、未跟踪文件、replace refs 和本地 Git 配置不会进入或控制安装结果。
- 仓库 URL 不允许内嵌凭证、query 或 fragment，安装器也不会打印 origin URL。
- Skill 目录按固定 manifest 生成干净 payload，并在目标文件系统暂存后事务式切换；整次命令中途失败会恢复所有旧目标。
- 内容发生变化的旧 skill 会保留到对应平台根目录的 `backups/.agent-team-backup.*`，安装器会打印路径。活动 skill 目录视为受管理目录，自定义文件请放在目录之外。
- Cursor 专家人设安装为 `~/.cursor/agents/agent-team-*.md`，不会占用 `qa.md` 等通用文件名。安装器用 `.agent-team-managed-agents` 记录固定七个专家文件；未知的 `agent-team-*.md` 和旧版通用文件名只告警、不删除。
- 旧版本可能在 `~/.agents/skills/agent-team` 留下 Codex 副本。建议备份后移除，避免重复发现；若 `CODEX_HOME` 明确指向 `~/.agents`，该路径就是权威安装，不会告警。

### 本地验证

仓库不依赖第三方测试包；安装测试全部使用临时 home/cache，不触碰真实用户配置：

```bash
bash -n install.sh scripts/install-from-github.sh scripts/test-install.sh
bash scripts/test-install.sh
python3 scripts/run-evals.py
python3 scripts/run-behavior-evals.py
python3 scripts/test-evals.py
git diff --check
```

`scripts/run-evals.py` 默认校验 eval 定义、安全/编排与性能契约、核心协议体积和 skill 结构，**不会执行 agent 行为**；性能负例覆盖标准路径一次收口、增量跟进边界、严格路径只读并行、delta 复审及 acceptance 冲突收口。使用 `--actual <results.json>` 才会把外部 harness 产生的机器可读执行结果与预期逐项比较。`scripts/run-behavior-evals.py` 校验真实型任务回放结果 JSON，也不直接执行 agent。GitHub Actions 会在 macOS 与 Ubuntu 上运行离线 contract、安装器、回放结果和结构检查，不把它们冒充真实 agent eval。

---

## English

### Quick Start

Install to Cursor by default:

```bash
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash
```

Install to other platforms:

```bash
# Claude Code
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash -s -- --claude

# Codex
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash -s -- --codex

# Install every target
curl -fsSL https://raw.githubusercontent.com/JasonDee-hub/agent-team-skill/main/install.sh | bash -s -- --all
```

No API key is required, but `git` and `tar` must be available. If `curl` hits a stale cache, use:

```bash
git clone --depth 1 https://github.com/JasonDee-hub/agent-team-skill.git /tmp/agent-team-skill \
  && bash /tmp/agent-team-skill/install.sh
```

Use the entry point for your platform:

| Platform | Entry Point | Example |
|----------|-------------|---------|
| Cursor | `/agent-team` | `/agent-team Add captcha support to the login page and collect verification evidence` |
| Claude Code | `/agent-team` | `/agent-team Review the latest diff for security risks` |
| Codex | `$agent-team` | `$agent-team Write this week's release notes and a launch checklist` |

Codex also supports natural-language triggers, for example: `Use the expert team to reproduce this error, find the root cause, and suggest a minimal fix.`

### What It Is

Agent Team is a lead-agent orchestration skill. It is not a fixed pipeline, and you do not manually rotate personas.

You state the goal. The lead decides which roles are actually needed and discloses the execution mode when dispatch starts:

- `real_multi_agent`: the host supports real independent agents/processes, so specialists can coordinate by dependency. Only QA or review from this mode may be called independent verification.
- `single_agent_simulation`: when the host lacks independent agents, the lead switches personas only when responsibility genuinely changes and shares one authority/acceptance ledger across phases. This mode is never presented as parallel or independent acceptance.

Good fits:

- Feature work and small iterations
- Bug fixes with regression checks
- Pre-commit or pre-PR review
- UI issue reproduction and evidence capture
- Fast orientation in unfamiliar repositories
- Developer-facing release notes, checklists, and docs

Poor fits:

- You only want one generic subagent to answer a single-domain request, without role separation or independent acceptance.
- You need authoritative medical, legal, financial, or regulatory output.
- You ask for external high-impact actions such as commits, publishing, deployment, or production writes without explicit authorization.

### How It Works

1. **Classify the task level**
   Tiny/read-only requests and explicitly authorized, low-risk single-file edits that do not touch security, data, dependencies, CI, or production use the lead fast path. Single-domain work gets at most one specialist by default; compound or high-risk work uses the strict path.

2. **Dispatch experts on demand**
   The full roster is not used by default, and QA/review is not added automatically. On the standard path, one specialist's fully evidenced return closes the task after one dispatch and collection; the lead does not repeat verification, reads, or ceremonial review. Vera or Reed is added only when the user requests independent acceptance or risk requires it.

3. **Declare authority first**
   A new agent receives a full handoff. Reusing the same agent/role sends only failed or changed acceptance items and necessary new evidence, while fully restating `write_authority`, path scope, environment, and external-action boundaries. Without explicit write authority, the task is read-only.

4. **Report meaningful progress**
   Updates are sent when dispatch starts, work is blocked or reassigned, a long phase completes a verifiable milestone, and the team finishes. Repetitive empty status updates are avoided.

5. **Wrap up with acceptance evidence**
   The strict path adds only independently necessary roles and parallelizes independent read-only acceptance. A risk that conflicts with acceptance or established behavior is failed/blocked, never downgraded into `risks` and reported done. It returns to the same Kane, then the same reviewer checks only the delta unless a new risk expands scope.

Output follows the user's language, falling back to Simplified Chinese only when unclear. For high-stakes medical, legal, financial, or regulatory work, Atlas is limited to neutral outlines, source-backed checklists/questions, or non-authoritative drafts requiring qualified review.

### Experts

| Expert | Focus |
|--------|-------|
| Atlas (Generalist) | Docs, checklists, one-off non-product helpers |
| Mira (Researcher) | Code/environment discovery and entry points |
| Kane (Full-stack Engineer) | Product code/config, CI, builds, dependencies, technical plans |
| Vera (QA) | Tests/builds, test-only changes, verification evidence |
| Reed (Code Reviewer) | Review and risk feedback |
| Lina (UI Operator) | Browser flows and visual bug reproduction |
| Orin (Troubleshooter) | Reproduction and root-cause analysis |

### Examples and Behavior Replay

Typical delivery samples live in [`examples/`](examples/):

- Feature implementation followed by independent QA: [feature-with-independent-qa.md](examples/feature-with-independent-qa.md)
- Read-only security review: [readonly-review.md](examples/readonly-review.md)
- Honest scope-blocked handoff: [scope-blocked.md](examples/scope-blocked.md)
- UI reproduction and evidence capture: [ui-reproduction.md](examples/ui-reproduction.md)
- High-risk out-of-domain blocker: [high-risk-blocked.md](examples/high-risk-blocked.md)

The realistic replay baseline lives in `evals/replay-cases.json`. It currently contains 15 tasks covering docs, implementation, QA, review, UI, troubleshooting, planning, parallel read-only work, security, scope, and blocking behavior. `evals/replay-results.json` records the machine-readable behavior observed from applying the current skill rules, including correct dispatch, over-dispatch, honest blocking, and truthful completion.

Validate the replay results:

```bash
python3 scripts/run-behavior-evals.py
```

To connect a live agent runner, have it emit the same actual-results JSON shape, then run:

```bash
python3 scripts/run-behavior-evals.py --actual path/to/results.json
```

This script validates behavior result JSON; it does not execute agents directly. Live execution belongs to Cursor, Claude Code, Codex, or an external harness.

### Install Locations

The installer maintains one Agent Team copy per platform:

| Platform | Install Path |
|----------|--------------|
| Cursor | `~/.cursor/skills/agent-team`, `~/.cursor/agents/agent-team-*.md`, `~/.cursor/commands/agent-team.md` |
| Claude Code | `~/.claude/skills/agent-team` |
| Codex | `${CODEX_HOME:-~/.codex}/skills/agent-team` |

Run the same install command again to upgrade. Identical installs do not create another backup.

### Upgrade and Safety

- Remote installs verify the cache Git origin. An existing cache is used only as an object reference; the actual fetch runs in an isolated temporary repository before a clean payload is exported from the requested ref.
- Cache worktree changes, untracked files, replace refs, and local Git configuration cannot enter or control the install.
- Repository URLs may not embed credentials, query strings, or fragments, and the installer never prints origin URLs.
- Skill directories are built as clean payloads from a fixed manifest, staged on the destination filesystem, and switched as one transaction; a failure anywhere in the requested install restores every previous target.
- When an existing skill differs, its full directory is retained under the platform root at `backups/.agent-team-backup.*`, and the installer prints the path. Treat the active skill directory as managed; keep custom files outside it.
- Cursor expert personas are installed as `~/.cursor/agents/agent-team-*.md`, so generic names such as `qa.md` are left untouched. `.agent-team-managed-agents` records the fixed seven managed profiles; unknown `agent-team-*.md` profiles and legacy generic names are warned about and preserved.
- Older releases may have left a Codex copy at `~/.agents/skills/agent-team`. Back it up and remove it to prevent duplicate discovery. If `CODEX_HOME` intentionally points to `~/.agents`, that path is canonical and is not reported as legacy.

### Local Validation

The repository uses no third-party test package. Installer tests use temporary homes and caches and never touch real user configuration:

```bash
bash -n install.sh scripts/install-from-github.sh scripts/test-install.sh
bash scripts/test-install.sh
python3 scripts/run-evals.py
python3 scripts/run-behavior-evals.py
python3 scripts/test-evals.py
git diff --check
```

By default, `scripts/run-evals.py` validates eval definitions, safety/orchestration and performance contracts, the core-protocol byte budget, and skill structure; it **does not execute agent behavior**. Performance negatives cover one-return standard closure, follow-up boundaries, strict read-only parallelism, delta review, and acceptance-conflicting completion. Pass `--actual <results.json>` to compare machine-readable results produced by an external harness against expectations. `scripts/run-behavior-evals.py` validates realistic task replay result JSON and also does not execute agents directly. GitHub Actions runs the offline contract, installer, replay-result, and structure checks on macOS and Ubuntu without presenting them as live agent evals.

---

## License

[MIT License](LICENSE)
