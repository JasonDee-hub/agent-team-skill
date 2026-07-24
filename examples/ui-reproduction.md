# 示例：UI 问题复现与取证

## 用户请求

```text
$agent-team 在浏览器里复现移动端结算页按钮被底部栏遮挡的问题，记录视口、步骤和截图，不要改源码。
```

## 主控派遣：Lina

```yaml
goal: 复现移动端结算页按钮遮挡问题
task_id: T1
role: Lina
deliverable: 复现步骤、视口信息、截图和初步归类
execution_mode: single_agent_simulation
write_authority: read_only
scope:
  read_paths: ["app/**", "src/**"]
  write_paths: []
  environment: local
  external_actions: []
  in:
    - 使用移动端视口验证结算页
    - 记录期望 vs 实际
  out:
    - 不改源码
    - 不提交订单
acceptance:
  - 记录可复现步骤
  - 记录视口和环境
  - 提供截图或等价视觉证据
  - 不执行购买/提交等外部动作
```

## Lina 回报

```yaml
task_id: T1
role: Lina
status: done
summary: 已复现按钮被底部栏遮挡，问题属于移动端布局缺陷。
evidence:
  - "viewport: 390x844, route: /checkout"
  - "steps: 打开 /checkout -> 添加商品 -> 滚动到底部"
  - "screenshot: artifacts/checkout-mobile-overlap.png"
verify:
  - acceptance: 记录可复现步骤
    result: passed
    evidence: "steps 已记录"
  - acceptance: 记录视口和环境
    result: passed
    evidence: "viewport 390x844; local environment"
  - acceptance: 提供截图或等价视觉证据
    result: passed
    evidence: "artifacts/checkout-mobile-overlap.png"
  - acceptance: 不执行购买/提交等外部动作
    result: passed
    evidence: "未点击提交订单按钮"
risks:
  - 只验证了 390x844；其它移动视口未覆盖
next:
  suggest_role: Kane
  reason: 需要修复 CSS/布局时派 Kane
```

## 主控最终收口

```text
完成状态：done
派遣：Lina only
结果：问题已复现，证据包含视口、步骤和截图
残留风险：仅覆盖一个移动视口；修复前建议再补 360x740 和 414x896
下一步：授权 Kane 修改布局相关文件
```

