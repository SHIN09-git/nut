# 《玻璃蚁国》技术架构

> 文档版本：0.7｜更新日期：2026-07-24
>
> 本文描述当前已经实现的湿度、幼体搬运与工蚁身份观察切片。

## 1. 固定技术决定

| 项目 | 决定 |
| --- | --- |
| 引擎 | `Godot 4.7.1.stable.official.a13da4feb` |
| 脚本 | 强类型 GDScript |
| 模拟步长 | 固定 0.1 秒／Tick |
| 时间控制 | 暂停、1×、4×、16×；默认单帧最多处理 16 Tick，积压保留 |
| 权威状态 | 纯模拟对象，不引用场景树 |
| 配置 | 强类型 Resource，启动时验证并复制 |
| 随机性 | 当前切片不使用随机性 |
| 显示 | Godot 内置节点和程序化占位图形 |
| 测试 | 项目自建 headless runner，无第三方插件 |

## 2. 数据流与命令边界

```text
WaterButton
    ↓ submit_water_action()
ColonySimulation._pending_humidity_commands
    ↓ 使用冻结 HabitatScenarioConfig 的目标与增量
    ↓ 下一固定 Tick 开始时应用
HabitatZoneState.humidity
    ↓
校验现有任务 → 推进状态机 → 为到期空闲工蚁决策
    ↓
更新观察稳定状态 → 校验所有权
    ↓ create_snapshot() 深复制
ColonySnapshot / AntSnapshot / HabitatZoneSnapshot / ObservationEvent
    ├── HabitatView
    ├── PlayerAnnotationState → WorkerObservationPanel
    └── F3 DebugPanel
```

提交命令时不会改变 `HabitatZoneState`。同一时间最多存在一个待处理补水动作；`ColonySimulation` 先验证 Tick 连续，再消费队列，错误 Tick 不会丢失输入。补水工具的首次落地门控、待处理状态、可用性、次数和目标舒适状态均由模拟拥有并复制进快照。

`MainController` 只负责：

- 推进 `SimulationClock`。
- 把 UI 操作转换成无参数高层模拟命令。
- 每个成功固定 Tick 后创建并交付一份快照。
- 把快照交给 `HabitatView` 和调试 UI。
- 协调 `HabitatView` 的选择请求、会话注释和 `WorkerObservationPanel` 投影。
- 每个渲染帧把时钟插值系数交给 `HabitatView`。
- 在完成快照允许时协调会话重置，但不重新读取 Resource、不替换时钟或逐只管理视觉节点。
- 在模拟拒绝 Tick 时暂停并显示错误。

控制器不创建或逐只管理蚂蚁视觉节点，也不能访问私有 `ColonyState`。

## 3. 配置冻结

```text
data/species/species_a.tres
    ├── LifecycleConfig
    └── BroodCareConfig

data/habitats/humidity_relocation_slice.tres
    └── HabitatScenarioConfig
         └── HabitatZoneState 副本
```

- `LifecycleConfig` 只保存产卵和阶段转换配置。
- `BroodCareConfig` 保存幼体舒适湿度、最小改善、决策间隔、拾取／移动／放下时长和区域停留冷却。
- `HabitatScenarioConfig` 保存切片初始实体、区域、连接、湿度、单次补水量和观察稳定窗口。
- Resource 通过验证后复制到私有运行时对象；修改源 `.tres` 不会改变已经开始的模拟。
- `restart_session()` 使用相同的私有冻结配置创建全新 `ColonyState`，并清空旧会话的待处理命令；不会再次读取 Resource。
- 两份数据都标记为 `prototype_pacing_fixture` 且 `scientifically_validated = false`。它们是游戏节奏夹具，不是真实物种数据。

## 4. 权威模型

### `ColonyState`

保存：

- 当前模拟 Tick。
- 蚁后与稳定 ID 实体数组。
- 两个 `HabitatZoneState`。
- 已应用湿度调整次数。
- 观察稳定 Tick 和观察记录解锁状态。
- 会话内单调事件 ID 和最多 64 条的结构化观察事件历史。

### `HabitatZoneState`

每个区域保存稳定 `StringName zone_id`、限制在 0.0～1.0 的湿度、可达连接 ID 和可用状态。模拟只使用区域 ID 与逻辑连接，不包含坐标、尺寸或颜色。

### `AntModel`

所有非蚁后实体保持原有稳定 ID，保存生命周期字段、`zone_id` 和 `zone_entered_tick`。工蚁额外持有一个 `WorkerTaskModel`；幼体不保存反向预订或携带引用。

### `WorkerTaskModel`

使用五个显式状态：

```text
IDLE
MOVING_TO_BROOD
PICKING_UP
CARRYING_TO_ZONE
DROPPING
```

任务是预订与携带关系的唯一事实来源，保存来源区域、目标幼体、目标区域、当前携带幼体、阶段已用 Tick、阶段总 Tick 和下一次决策 Tick。

### `ObservationEvent`

模拟在搬运开始、开始拾取、开始携带、实际放下和观察首次完成时追加结构化值对象。每条事件只包含：

- `event_id`
- `tick`
- `event_type`
- `actor_entity_id`
- `subject_entity_id`
- `source_zone_id`
- `target_zone_id`

事件 ID 在单个会话内从 1 单调递增；同 Tick 事件沿现有稳定工蚁 ID 更新顺序追加。历史是容量 64 的 FIFO，只服务当前小型切片，不是通用事件总线。重开创建新的 `ColonyState`，清空历史并让新会话从事件 ID 1 开始。

## 5. 搬运决策

湿度适宜度使用到舒适区间的距离：

```text
penalty(h) =
    min - h    当 h < min
    0          当 min ≤ h ≤ max
    h - max    当 h > max
```

- 只考虑非工蚁实体。
- 工蚁和幼体按稳定实体 ID 遍历，区域平局按区域 ID 字符串处理。
- 只有 `source_penalty - target_penalty` 达到 `relocation_min_improvement` 才创建任务。
- 一个幼体被某个活跃任务选中后，后续工蚁不能再次预订。
- 工蚁只在空闲、决策间隔到期或当前目标失效时重新评估。
- `minimum_zone_dwell_ticks` 从放下 Tick 开始计算，防止幼体在区域间反复振荡。
- 当前只有两个直接连接区域，不存在通用寻路系统。

## 6. 状态机与失效处理

```text
IDLE
  └─ 选择幼体与更优区域
      → MOVING_TO_BROOD
          → PICKING_UP
              ├─ 幼体 zone_id 清空
              └─ CARRYING_TO_ZONE
                    → DROPPING
                        ├─ 幼体进入目标区域
                        ├─ 更新 zone_entered_tick
                        └─ 清空任务 → IDLE
```

- `MOVING_TO_BROOD` 或 `PICKING_UP` 的目标失效时，可以清空任务并释放预订。
- `CARRYING_TO_ZONE` 或 `DROPPING` 中的目标失效时，不能直接回到空闲；必须重新选择可达区域并完成放下。
- 玩家补水让改善不足时，只取消尚未拾取的失效任务；已经携带幼体且目标仍可用、可达时必须完成原任务，只有目标区域不可用或不可达时才重定向并完成放下。
- 每个 Tick 单次推进现有阶段，位置进度由 `elapsed_ticks / duration_ticks` 复制进快照。

## 7. 所有权不变量

每个模拟 Tick 结束时必须满足：

- 未被携带的幼体恰好属于一个现存区域。
- 被携带的幼体 `zone_id` 为空，且恰好属于一只工蚁。
- 一个幼体最多被一个活跃任务预订。
- 一只工蚁最多携带一个幼体。
- `IDLE` 不残留来源、目标幼体、目标区域或携带 ID。
- 搬运前状态有目标但没有携带物；搬运后状态的携带 ID 与目标幼体 ID 一致。
- 放下后区域、预订、携带者和任务字段全部一致清理。
- 工蚁始终属于一个现存区域。

预订者和携带者只在创建快照时从工蚁任务派生，避免双向权威字段漂移。所有权检查失败会让模拟进入错误状态并拒绝继续推进。

## 8. 每 Tick 更新顺序

`ColonySimulation.advance_tick()` 的实际顺序：

1. 验证 Tick 必须连续；失败时不消费命令。
2. 写入当前 Tick。
3. 应用并清空本 Tick 的湿度命令批次，湿度夹紧到有限的 0.0～1.0。
4. 栖息地切片不推进生命周期；无栖息地的独立调试入口保持原生命周期流程。
5. 按稳定工蚁 ID 校验、取消或重定向现有任务。
6. 推进现有搬运状态机，并在跨越拾取、携带和放下边界时追加结构化事件。
7. 按稳定工蚁与幼体 ID 为到期的空闲工蚁分配任务，并在任务开始时追加事件。
8. 更新观察记录稳定计数与解锁状态；首次解锁时追加完成事件。
9. 校验所有权不变量。
10. 每个成功 Tick 后，由控制器立即创建并交付一份新快照。

系统结果不依赖场景树处理顺序、渲染帧率或墙钟时间。

## 9. 快照边界

`ColonySimulation.create_snapshot()` 每次新建：

- 一个 `ColonySnapshot`。
- 每个区域对应的 `HabitatZoneSnapshot`，包括新的连接 ID 数组。
- 每个实体对应的 `AntSnapshot`。
- 有界结构化事件历史中每个 `ObservationEvent` 的副本。

快照包含显示和诊断所需的区域、任务进度、派生预订／携带关系、补水门控与待处理状态、生命周期模式、观察状态和结构化事件，但不携带任何内部模型引用。修改快照字段、事件对象、子对象或数组不会改变模拟。

## 10. 显示层

`HabitatView`：

- 只读取快照。
- 维护稳定的 `entity_id -> AntView` 映射。
- 单独持有 `QueenView`。
- 绘制两个巢室、连接通道和非数字湿度线索。
- 根据工蚁任务状态与进度计算屏幕位置。
- 携带中的幼体使用工蚁的快照驱动位置，不运行独立搬运动画。
- 保存相邻 Tick 的前后位置，并使用 `SimulationClock.get_interpolation_alpha()` 在渲染帧间插值。
- 同 Tick 快照不轮换端点，旧 Tick 被拒绝；暂停时插值冻结。
- 相邻搬运状态共享连续端点，16× 与积压排空不会产生视觉回跳。
- 重复快照不创建重复节点，完整快照中缺失的节点按明确规则移除。
- 会话重置会清空快照端点和实体映射，解绑旧节点，然后允许新会话从 Tick 0 建立全新投影。
- 鼠标命中使用当前插值后的 `AntView.position`；只接受工蚁，重叠时先选最近者，距离相同按稳定实体 ID。
- `AntView` 只投影是否选中的静态轮廓，不拥有选择事实。

普通 UI 不显示精确湿度、任务枚举、目标 ID 或生命周期倒计时。F3 诊断层读取相同快照并显示精确内部状态。

### 会话身份层

`PlayerAnnotationState` 是独立于权威模拟的会话对象：

- 只保存当前选择的稳定工蚁 ID、可选名称、每只工蚁最近最多 5 条事件副本和事件消费游标。
- 每次快照按 `event_id` 顺序消费所有新事件；重复快照按游标去重，ID 缺口被显式记录。
- 选择实体消失或不再是工蚁时，清除对应选择、名称与历史。
- `restart_session()` 的控制流程同时重置选择、全部名称、个人历史和消费游标。
- 不持有 `AntModel`、`ColonyState` 或可写模拟引用，也不向模拟回写任何身份信息。

`WorkerObservationPanel` 只读取所选 `AntSnapshot` 和过滤后的事件副本，显示自然语言当前行为与最近 4 条记录。名称提交只写入 `PlayerAnnotationState`。16× 时控制器仍在每个成功 Tick 后交付快照，因此同一渲染帧跨越的多条事件会依次被消费，而不是只保留最后一条。

## 11. 独立生命周期调试

`scenes/debug/lifecycle_debug.tscn` 使用：

```text
ColonySimulation(species_data, null)
    ↓
TestTubeHabitat
    ↓
ColonyViewAdapter
```

无栖息地配置时，`ColonySimulation` 保持原有产卵与卵 → 幼虫 → 蛹 → 工蚁流程。阶段中文显示映射位于 View 层的 `LifeStagePresenter`，核心 `AntModel` 不负责本地化。

## 12. 测试结构

`tests/test_runner.gd` 只聚合独立套件：

- `tests/core/simulation_clock_test_suite.gd`
- `tests/simulation/lifecycle_test_suite.gd`
- `tests/simulation/humidity_relocation_test_suite.gd`
- `tests/simulation/observation_event_test_suite.gd`
- `tests/session/player_annotation_state_test_suite.gd`
- `tests/view/view_adapter_test_suite.gd`
- `tests/view/habitat_view_interpolation_test_suite.gd`
- `tests/view/worker_observation_panel_test_suite.gd`
- `tests/scenes/lifecycle_debug_scene_test_suite.gd`
- `tests/scenes/humidity_main_scene_test_suite.gd`
- `tests/scenes/worker_identity_scene_test_suite.gd`

生命周期边界从 Resource 计算。湿度套件覆盖高层命令、配置冻结、确定性、任务选择、所有权、取消／重定向、补水后重评估、会话重置、1,000 Tick 防振荡、快照隔离、60～120 秒节奏和 10,000 Tick soak。事件与身份套件覆盖单调唯一顺序、深复制、64 条上限、16× 多 Tick 批次、稳定选择、命名不改变完整模拟签名、所选工蚁过滤和连续两次重开清理。场景测试使用实际按钮和 `HabitatView` 鼠标输入路径，不绑定完整中文文案。

标准命令：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script 'res://tests/test_runner.gd'
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 30
```

自动测试不替代 1280×720 的人工可读性检查。

## 13. 当前限制

- 湿度和行为数值是原型节奏参数，未经真实养蚁数据审校。
- 只有两个直接相连区域、一个物种和固定参与者。
- 生命周期调试与湿度切片是两个独立入口。
- 名称、选择和个人记录只存在于当前会话，重开后不保留。
- 没有觅食、资源消耗、镜头、直接个体命令、存档、随机行为、正式素材或外部插件。
