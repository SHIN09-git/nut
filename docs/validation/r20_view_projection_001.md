# R20-B 统一世界显示投影性能验证记录 001

日期：2026-07-31
分支：`codex/perf/r20-view-projection`

## 范围与结论

本轮只减少 R19 统一栖息地世界与 R20-A 行为姿态路径中的重复显示计算：

- 连续 Tick 直接复用上一轮已经计算的实体与蚁后显示端点；
- 按布局 revision 和网格尺寸缓存稳定区域锚点；
- 环境数值变化复用布局锚点，布局变化和投影重置明确使缓存失效；
- 无独立设施的逻辑通道继续由稳定拓扑计算，并保持数组顺序无关。

没有修改固定 Tick、模拟状态、任务选择、所有权、命令、快照结构、存档、
设施规则、原型节奏或玩家路径。

技术结论：通过。R20-A 同一台机器上的 10,000 Tick 诊断为
`avg_view_us=18081.60`、`p95_view_us=20302`、`view_over_7000=10`；
优化后的同规模短测为 `avg_view_us=2286.00`、
`p95_view_us=2777`、`view_over_7000=0`。短测权威签名保持：

```text
16a7888c81c193cb715c12188b18a3033271152ad1143086cd835622bdf70f63
```

## 30 万 Tick 最大规模验证

命令：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . `
  --script 'res://tests/performance/act1_300k_max_scale_soak.gd' -- `
  --ticks=300000 --frame-samples=0
```

结果：`R16_MAX_SCALE_SOAK_PASS`，退出码 0。

夹具规模：

- 80 只工蚁；
- 180 个幼体；
- 48 项设施；
- 36 个逻辑区域；
- 72 条连接；
- 240 个可见 `AntView`。

关键采样：

```text
ticks=300000
elapsed_s=378.856
avg_tick_us=1252.82
p95_tick_us=1632
p99_tick_us=2320
max_tick_us=7652
tick_over_5000=1
avg_snapshot_us=2767.38
p95_snapshot_us=3184
max_snapshot_us=4386
snapshot_over_4000=3
avg_view_us=2382.67
p95_view_us=2735
max_view_us=3784
view_over_7000=0
memory_growth_bytes=9460508
memory_trend_slope_bytes_per_sample=168.12
signature=ad21e7f54e3a2832223048f4a8f4748fa108e60b5a5dbf02a8e11e493564dd3e
```

## 自动验证

新增回归覆盖：

- 批量区域锚点包含无独立设施的逻辑通道；
- 批量锚点与直接投影一致；
- 设施和拓扑数组重排不改变锚点；
- 仅环境值变化时复用同一布局锚点；
- 布局 revision 变化时缓存失效并重新计算。

最终标准验证：

| 检查 | 结果 | 退出码 |
| --- | --- | ---: |
| Godot 精确版本 | `4.7.1.stable.official.a13da4feb` | 0 |
| headless 编辑器解析 | 通过 | 0 |
| 项目测试 | `PASS: 40981 project assertions` | 0 |
| headless 默认主场景冒烟 | 通过，无脚本错误 | 0 |
| 10,000 Tick 最大规模短测 | `R16_MAX_SCALE_SOAK_PASS` | 0 |
| 300,000 Tick 最大规模完整 soak | `R16_MAX_SCALE_SOAK_PASS` | 0 |

## 人工与外部验证

- 已执行 Windows 1280×720、简体中文、UI 100% 的默认主场景检查。沿用现有
  档案分别在 1× 与 16× 观察；试管、蚁后和幼体投影稳定，阶段变化没有可见
  回跳、越界或重复节点，顶栏、观察区、侧栏和操作栏无重叠。
- 检查后直接关闭窗口且未保存，没有改写用户档案。
- R20-A 普通玩家路径中的真实携带糖液与育幼喂食姿态捕获仍未执行。
- 必需的 7 名有效首次接触测试者数据仍为 `INCOMPLETE`。用户允许跳过该项
  继续开发，不等于 Gate 通过，也没有用本机性能数据替代外部理解度证据。

## 已知限制

- 性能数字只适用于当前机器、Godot 4.7.1 和固定最大规模夹具，不能外推到
  其他硬件。
- 计时采样存在少量系统抖动；判定同时保留 P95、超线次数、确定性签名、
  所有权检查与长时完成结果，不把单个最大值当作独立 Gate。
