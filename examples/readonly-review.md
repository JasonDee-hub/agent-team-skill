# 示例：只读安全审查

## 用户请求

```text
/agent-team 请 review 当前 git diff 的鉴权和注入风险，只报告问题，不要修改文件。
```

## 主控派遣：Reed

```yaml
goal: 审查当前 diff 的鉴权和注入风险
task_id: T1
role: Reed
deliverable: 只读代码审查报告
execution_mode: single_agent_simulation
write_authority: read_only
scope:
  read_paths: ["src/**", "tests/**", "package.json"]
  write_paths: []
  environment: local
  external_actions: []
  in:
    - 查看当前 diff 和相关调用上下文
    - 优先 correctness/security
  out:
    - 不修改文件
acceptance:
  - 列出有证据的问题，包含位置、风险和建议
  - 明确未覆盖范围
  - 不进行任何写入
```

## Reed 回报

```yaml
task_id: T1
role: Reed
status: done
summary: 发现 1 个 Warning 级鉴权风险；未修改文件。
evidence:
  - "src/api/admin.ts:L42: 新增 deleteUser handler 仅检查登录态，未检查 admin role"
  - "tests/admin.test.ts: 未覆盖非管理员删除用户的拒绝场景"
verify:
  - acceptance: 列出有证据的问题，包含位置、风险和建议
    result: passed
    evidence: "报告包含 src/api/admin.ts:L42 风险、影响和建议补 role check"
  - acceptance: 明确未覆盖范围
    result: passed
    evidence: "未运行测试；审查范围限当前 diff 和 admin 调用链"
  - acceptance: 不进行任何写入
    result: passed
    evidence: "write_authority: read_only; changes omitted"
risks:
  - 未运行测试，结论来自静态 diff 审查
next:
  suggest_role: Kane
  reason: 需要实现鉴权修复和测试时再派 Kane
```

## 主控最终收口

```text
完成状态：done
派遣：Reed only
结果：只读审查完成，发现 admin deleteUser 缺少 role check
验证：未修改文件；审查范围与未运行测试已披露
下一步：如需修复，授权 Kane 修改 src/api/admin.ts 和对应测试
```

