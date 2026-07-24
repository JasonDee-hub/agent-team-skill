# 示例：功能实现后独立 QA

## 用户请求

```text
$agent-team 实现导出 CSV 功能并补测试；实现完成后安排独立 QA 按验收标准验证。
```

## 主控派遣：Kane

```yaml
goal: 实现导出 CSV 功能并补测试，随后进行独立 QA
task_id: T1
role: Kane
deliverable: CSV 导出实现、配套单元测试和自检结果
execution_mode: real_multi_agent
write_authority: scoped_write
scope:
  read_paths: ["src/export/**", "src/table/**", "tests/**", "package.json"]
  write_paths: ["src/export/csv.ts", "tests/export-csv.test.ts"]
  environment: local
  external_actions: []
  in:
    - 复用现有导出入口和测试框架
    - 处理逗号、换行、引号和空值
  out:
    - 不改 UI
    - 不新增依赖
acceptance:
  - src/export/csv.ts 提供可复用 CSV 序列化函数
  - 覆盖逗号、换行、引号和空值测试
  - 本地相关测试通过，或无法运行时如实标注 not_run/blocked
constraints: 精简 标准；稳定优先，不为远期格式扩展新增抽象层
```

## Kane 回报

```yaml
task_id: T1
role: Kane
status: done
summary: 已新增 CSV 序列化函数并补齐关键转义测试。
changes:
  - path: src/export/csv.ts
    summary: 新增 serializeCsv，按 RFC 风格处理引号、逗号、换行与空值
  - path: tests/export-csv.test.ts
    summary: 覆盖普通字段、逗号、换行、引号和 null/undefined
evidence:
  - "npm test -- export-csv.test.ts -> exit 0"
verify:
  - acceptance: src/export/csv.ts 提供可复用 CSV 序列化函数
    result: passed
    evidence: "src/export/csv.ts exports serializeCsv"
  - acceptance: 覆盖逗号、换行、引号和空值测试
    result: passed
    evidence: "tests/export-csv.test.ts includes comma/newline/quote/null cases"
  - acceptance: 本地相关测试通过，或无法运行时如实标注 not_run/blocked
    result: passed
    evidence: "npm test -- export-csv.test.ts -> exit 0"
next:
  suggest_role: Vera
  reason: 用户要求独立 QA，且当前平台支持 real_multi_agent
```

## 主控派遣：Vera

```yaml
goal: 独立验证 CSV 导出功能
task_id: T2
role: Vera
deliverable: 独立 QA 验证结果和证据
execution_mode: real_multi_agent
write_authority: read_only
scope:
  read_paths: ["src/export/csv.ts", "tests/export-csv.test.ts", "package.json"]
  write_paths: []
  environment: local
  external_actions: []
  in:
    - 复核 Kane 改动
    - 运行相关测试
  out:
    - 不改产品代码
acceptance:
  - CSV 转义行为符合测试预期
  - 相关测试可复现通过
context:
  Kane_summary: 已实现 serializeCsv 并补单元测试
  Kane_evidence: "npm test -- export-csv.test.ts -> exit 0"
```

## Vera 回报

```yaml
task_id: T2
role: Vera
status: done
summary: 独立复核通过，未发现与验收标准冲突的问题。
evidence:
  - "npm test -- export-csv.test.ts -> exit 0"
verify:
  - acceptance: CSV 转义行为符合测试预期
    result: passed
    evidence: "测试覆盖 comma/newline/quote/null，实际输出与期望一致"
  - acceptance: 相关测试可复现通过
    result: passed
    evidence: "npm test -- export-csv.test.ts -> exit 0"
next:
  suggest_role: none
  reason: 验收项均已通过
```

## 主控最终收口

```text
完成状态：done
派遣：Kane -> Vera，execution_mode: real_multi_agent
交付：CSV 导出实现与单元测试
验证：Kane 自检通过；Vera 独立复核通过
残留风险：未做 UI 导出按钮集成，因为用户本次只要求导出逻辑和测试
```

