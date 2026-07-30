# R20-C 稳定设施节点验证记录 001

日期：2026-07-31
分支：`codex/art/r20-facility-view-slice`

## 范围与结论

本轮把已有设施轮廓从 `FacilityLayoutView._draw()` 迁入稳定的
`facility_id -> FacilityView` 映射，并把放置合法性预览迁入单一
`FacilityPlacementPreviewView`。网格与连接继续批量绘制。

没有修改固定 Tick、模拟、命令、设施目录、布局规则、环境效果、快照结构、
存档、节奏或玩家路径，也没有加入外部图片、模型、插件或新设施。

技术结论：通过。该包建立后续有限设施艺术切片需要的节点边界，不宣称完成
Blender／精灵资产生产，也不把现有程序化轮廓称为最终美术。

## 自动覆盖

新增或扩展的确定性回归覆盖：

- 每个可用稳定设施 ID 只创建一个 `FacilityView`；
- 重复应用和快照数组重排复用原节点；
- 选择状态更新已有节点；
- 相机平移、缩放和聚焦更新原节点的位置与尺寸；
- 一个设施失效时只移除对应映射，其他设施节点继续复用；
- 设施节点忽略鼠标，布局命中仍由父视图拥有；
- 合法／非法放置移动复用同一个预览节点，取消后隐藏。

首次全量运行：

| 检查 | 结果 | 退出码 |
| --- | --- | ---: |
| Godot 精确版本 | `4.7.1.stable.official.a13da4feb` | 0 |
| headless 编辑器解析 | 通过 | 0 |
| 项目测试 | `PASS: 40996 project assertions` | 0 |
| headless 默认主场景冒烟 | 通过，无脚本错误 | 0 |
| 10,000 Tick 最大规模短测 | `R16_MAX_SCALE_SOAK_PASS` | 0 |
| 300,000 Tick 最大规模完整 soak | `R16_MAX_SCALE_SOAK_PASS` | 0 |

最大规模短测继续使用 80 只工蚁、180 个幼体、48 项设施、36 个区域、
72 条连接和 240 个可见 `AntView`。关键采样：

```text
avg_tick_us=1244.04
p95_tick_us=1824
avg_snapshot_us=2957.10
p95_snapshot_us=3978
avg_view_us=2888.50
p95_view_us=3733
view_over_7000=0
signature=16a7888c81c193cb715c12188b18a3033271152ad1143086cd835622bdf70f63
```

完整 300,000 Tick 最大规模 soak：

```text
R16_MAX_SCALE_SOAK_PASS
ticks=300000
elapsed_s=368.454
avg_tick_us=1217.59
p95_tick_us=1653
p99_tick_us=2248
max_tick_us=7810
tick_over_5000=3
avg_snapshot_us=2813.57
p95_snapshot_us=3636
max_snapshot_us=4320
snapshot_over_4000=10
avg_view_us=2875.73
p95_view_us=3390
max_view_us=4601
view_over_7000=0
memory_growth_bytes=9460508
memory_trend_slope_bytes_per_sample=168.12
signature=ad21e7f54e3a2832223048f4a8f4748fa108e60b5a5dbf02a8e11e493564dd3e
```

结果：通过，退出码 0。

## 人工窗口检查

环境：Windows，1280×720 逻辑分辨率，简体中文，UI 100%。

已执行：

- 从标题继续现有档案并关闭暂停遮罩；
- 确认普通观察中的试管和微型喂食口位置、实体叠放与 R20-B 一致；
- 打开模块布局，确认网格和连接位于设施后方；
- 确认试管与微型喂食口标签可读；
- 选择微型喂食口，确认原节点出现选中轮廓，检查器与命中对象一致；
- 直接关闭窗口且未保存，没有改写用户档案。

证据：

- `docs/ux/r20_facility_nodes/01_layout_selected_1280x720_zh_100.jpg`

## 外部证据与限制

- 必需的 7 名有效首次接触测试者数据仍为 `INCOMPLETE`；用户允许跳过该
  阻塞继续开发，不等于通过。
- R20 要求的 5 名无说明行为辨认数据仍为 `INCOMPLETE`。
- 本轮只重构设施节点所有权和保留现有视觉，不增加最终建模、精灵动画、
  近中远 LOD 或外部资产再生产管线。
- 性能数字只适用于当前机器、Godot 4.7.1 和固定最大规模夹具。
