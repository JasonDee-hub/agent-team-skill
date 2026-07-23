# 专家团交接协议

主控与专家统一使用下列 canonical 字段名。必填字段不可省略或改名；条件字段只在适用时出现，不用填 `none` 或空数组凑格式。

## 主控 → 专家（派遣包）

### 必填

- `goal`：用户总目标
- `task_id`：当前子任务唯一标识
- `role`：`Atlas | Mira | Kane | Vera | Reed | Lina | Orin`
- `deliverable`：本任务的具体交付物
- `scope`：允许读取/写入的路径与明确边界；写任务须给互斥路径
- `acceptance`：可判定的通过标准

### 条件字段

- `constraints`：存在技术、时间、权限或风格约束时填写
- `context`：存在上游结论、关键日志或已尝试路径时填写
- `handoff_from`：由上游角色转交时填写

```yaml
goal: <用户总目标一句话>
task_id: <T1/T2/...>
role: <Atlas|Mira|Kane|Vera|Reed|Lina|Orin>
deliverable: <本任务具体交付物>
scope:
  paths: [<相关路径或 glob>]
  in: [<必须做>]
  out: [<明确不做>]
acceptance: [<可判定的通过标准>]
# constraints/context/handoff_from 按需添加
```

## 专家 → 主控（回报包）

### 必填

- `task_id`：与派遣一致
- `role`：当前角色
- `status`：`done | blocked | needs_handoff`
- `summary`：结果与结论的简要说明
- `next`：收工、继续或建议改派的下一步

### 条件字段

- `changes`：修改或删除文件时填写
- `evidence` / `verify`：测试、审查、诊断任务，或需要提供验收证据时填写
- `risks`：仅在确有已知风险或未覆盖场景时填写
- `blocked_by`：仅当 `status: blocked` 时填写

```yaml
task_id: <与派遣一致>
role: <本角色>
status: done | blocked | needs_handoff
summary: <结果与结论>
next:
  suggest_role: <none|Atlas|Mira|Kane|Vera|Reed|Lina|Orin>
  reason: <为何收工、继续或改派>
# changes/evidence/verify/risks/blocked_by 按条件添加
```

## 主控义务

- 派遣前确认权限边界；没有实现授权时保持只读。
- 并行写任务的 `scope` 必须互斥；重叠路径、共享 lockfile 与生成产物必须串行。
- 回收后核对 `status`、`next` 和适用的验收证据，再决定收工、补派或改派。
- 向下游传递时，将必要的上游 `summary`、`changes`、`evidence` 放入新派遣包的 `context`。
