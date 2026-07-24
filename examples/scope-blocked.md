# 示例：写入范围不足时如实阻塞

## 用户请求

```text
$agent-team 授权 Kane 只改 src/cache.ts。若实现需要同步 package-lock.json，不要越界，先申请扩展写入范围。
```

## 主控派遣：Kane

```yaml
goal: 在限定写入范围内修复缓存问题
task_id: T1
role: Kane
deliverable: 若可在范围内完成则修复；否则申请扩展范围
execution_mode: single_agent_simulation
write_authority: scoped_write
scope:
  read_paths: ["src/cache.ts", "package.json", "package-lock.json"]
  write_paths: ["src/cache.ts"]
  environment: local
  external_actions: []
  in:
    - 只写 src/cache.ts
    - 如果需要改 package-lock.json，先停手
  out:
    - 不写 package-lock.json
acceptance:
  - 不越权写入 package-lock.json
  - 若无法在授权范围内完成，返回 needs_handoff 并说明原因
```

## Kane 回报

```yaml
task_id: T1
role: Kane
status: needs_handoff
summary: 修复需要同步锁文件，但 package-lock.json 不在写入范围内；已停手。
evidence:
  - "package.json 中相关依赖版本会影响 src/cache.ts 的时间工具导入"
  - "package-lock.json 不在 scope.write_paths"
verify:
  - acceptance: 不越权写入 package-lock.json
    result: passed
    evidence: "changes omitted; package-lock.json 未写入"
  - acceptance: 若无法在授权范围内完成，返回 needs_handoff 并说明原因
    result: passed
    evidence: "status: needs_handoff; 原因是需要扩展 write_paths"
next:
  suggest_role: Kane
  reason: 用户授权 package-lock.json 后可继续同一修复
```

## 主控最终收口

```text
完成状态：needs_handoff
已完成：确认当前授权不足；未越权写 package-lock.json
未完成：缓存修复尚未落地
阻塞原因：需要用户明确扩展 write_paths 到 package-lock.json
最小下一步：用户确认是否允许 Kane 写入 package-lock.json
```
