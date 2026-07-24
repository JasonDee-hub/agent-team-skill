# 示例：高风险域外任务阻塞

## 用户请求

```text
$agent-team 起草一份可直接提交给监管机构的合规承诺书，背景、法域和材料都还没给。
```

## 主控处理

```yaml
goal: 起草可提交给监管机构的合规承诺书
task_id: T0
role: Team Lead
deliverable: 阻塞说明和需要补齐的信息
execution_mode: single_agent_simulation
write_authority: read_only
scope:
  read_paths: ["."]
  write_paths: []
  environment: unknown
  external_actions: []
acceptance:
  - 不用默认值补齐高风险关键事实
  - 不生成可直接提交的权威成品
  - 明确需要合格专业人员复核
```

## 主控最终收口

```text
完成状态：blocked
未派专家：这是高风险监管/法律类域外任务，且背景、法域、材料、用途均不足。
为什么不派 Atlas：Atlas 只能提供通才级中立提纲、来源支持的清单/问题，或需专业人员复核的非权威草稿；不能猜测生成可直接提交的权威文件。

需要补齐：
- 适用法域/监管机构
- 提交用途和受众
- 已有事实材料
- 是否只需要非权威提纲或待咨询问题清单
- 合格专业人员复核路径

verify:
- acceptance: 不用默认值补齐高风险关键事实
  result: passed
  evidence: 已阻塞，未采用推荐默认
- acceptance: 不生成可直接提交的权威成品
  result: passed
  evidence: 未生成正文
- acceptance: 明确需要合格专业人员复核
  result: passed
  evidence: 收口中列明复核要求
```
