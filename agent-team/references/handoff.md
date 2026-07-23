# 专家团交接协议

主控派遣与专家回报统一用下列字段，避免信息丢失。所有顶层字段均须保留且**不得改名**；不适用项写 `none`、`[]` 或简短原因。

## 主控 → 专家（派遣包）

```yaml
goal: <用户总目标一句话>
task_id: <T1/T2/...>
role: <Atlas|Mira|Kane|Vera|Reed|Lina|Orin>
deliverable: <本任务具体交付物>
scope:
  paths: [<相关路径或 glob>]
  in: [<必须做>]
  out: [<明确不做>]
constraints: [<技术/时间/风格约束>]
acceptance: [<可判定的通过标准>]
context: |
  <上游结论、关键日志、已尝试过的路径；无则写「无」>
handoff_from: <上游角色或 main|none>
```

## 专家 → 主控（回报包）

结束时按此结构回报（可用 Markdown 标题，字段名保持一致）：

```yaml
task_id: <与派遣一致>
role: <本角色>
status: done | blocked | needs_handoff
summary: <做了什么，一句话>
changes:
  - path: <文件>
    note: <改动要点>
evidence:
  - <命令/退出码/日志摘要/截图说明>
verify:
  - <如何验证；未跑则写原因>
risks:
  - <已知限制或未覆盖场景>
next:
  suggest_role: <none|Atlas|Mira|Kane|Vera|Reed|Lina|Orin>
  reason: <为何改派或可收工>
blocked_by: <若 status=blocked，写清缺什么；否则写 none>
```

## 主控义务

- 派遣 prompt **必须包含**派遣包字段（可内嵌，不必真 YAML）。
- 回收后先核对 `status/evidence/next`，再决定收工、补派或改派。
- 向下游传递时，把上游 `summary/changes/evidence` 写入新派遣包的 `context`。
