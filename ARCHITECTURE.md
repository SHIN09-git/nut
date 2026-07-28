# 《玻璃蚁国》技术架构

> 文档版本：1.0｜更新日期：2026-07-28
>
> 本文描述当前已经实现并完成 R0-A 证据有效性修正的 M4 连续组合观察，以及仍保留的生命周期、湿度搬运和糖水觅食独立调试／验证路径。

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
PreparationGate（应用层，Tick 0）
    └── StartObservationButton → 只释放 SimulationClock
                               （不进入模拟命令队列）
    ↓
CombinedObservationController
    ├── 身份阶段按钮 → submit_continue_observation_action()
    ├── 湿度阶段按钮 → submit_water_action()
    └── 糖水阶段有效落点 → submit_place_sugar_action()
                              （三个入口都是无参数高层命令）
    ↓
ColonySimulation._pending_commands
    ↓ 先验证 Tick 连续，再按提交顺序消费
    ↓ 下一合法固定 Tick 开始时使用冻结配置应用
ColonyState + ScenarioProgressState
    ↓
ScenarioDirector 受控生命周期
    ↓
搬运／觅食任务校验与推进
    ↓
按当前阶段分配新任务 → 更新湿度观察 → 推进组合阶段
    ↓
校验栖息地、任务、守恒与组合进度不变量
    ↓ create_game_snapshot() 深复制
GameSnapshot
    ├── ColonySnapshot
    ├── ForagingScenarioSnapshot
    ├── ObservationJournalSnapshot
    └── ScenarioSequenceSnapshot
            ├── CombinedHabitatView
            ├── CombinedObservationController 的阶段 UI
            ├── PlayerAnnotationState → WorkerObservationPanel
            └── 开发调试构建中的 F3 DebugPanel
```

提交命令时不会直接修改权威状态。控制器在提交成功后立即重新取同 Tick 快照，所以 UI 可以先看到 `continue_action_pending`、`water_action_pending` 或 `place_action_pending`；命令效果只会在下一合法固定 Tick 出现。`ColonySimulation` 在消费命令前拒绝非连续 Tick，因此错误推进不会丢失已提交输入。

准备门是 `CombinedObservationController` 的应用层状态，不属于 `ColonyState`、命令队列或五阶段 `ScenarioProgressState`。门内 `SimulationClock` 保持 Tick 0、1×和暂停，View 插值系数固定为 0，蚁后与蚂蚁视觉暂停；开始按钮只解除这些暂停。首工的生命周期边界仍由冻结 Resource 和模拟 Tick 决定。重开先创建全新模拟会话，再回到同一个准备门。

组合会话从开始到总结始终持有同一个 `SimulationClock`、同一个 `ColonySimulation` 和其中同一个 `ColonyState`。`ScenarioDirector` 只持有冻结配置并协调阶段，不拥有第二套权威状态，也不会在阶段切换时替换时钟、重载场景或重建首工。

`CombinedObservationController` 只负责：

- 推进 `SimulationClock`。
- 协调 Tick 0 准备门，并在开始前冻结时钟、插值和视觉。
- 把阶段 UI 操作转换成无参数高层模拟命令。
- 每个成功固定 Tick 后创建并交付一份 `GameSnapshot`。
- 把快照交给 `CombinedHabitatView`、会话注释层、观察面板和调试 UI。
- 每个渲染帧把时钟插值系数交给 View。
- 在总结快照允许时协调会话重置；重置复用冻结配置和同一个时钟对象。
- 在模拟或 View 拒绝更新时暂停并显示可见错误。

控制器不能访问私有 `ColonyState`，也不创建或逐只管理蚂蚁视觉节点。糖水落点的屏幕坐标只用于 View 命中判断，不进入命令或模拟。

原有独立湿度和糖水入口继续遵守相同边界：

```text
MainController / SugarForagingController
    ↓ 无参数补水／放置命令
ColonySimulation._pending_commands
    ↓ 下一合法固定 Tick 应用
ColonySnapshot 或 GameSnapshot
    ├── HabitatView / SugarForagingHabitatView
    ├── PlayerAnnotationState → WorkerObservationPanel
    └── F3 DebugPanel
```

## 3. 配置冻结

```text
data/species/species_a.tres
    ├── LifecycleConfig
    └── BroodCareConfig

data/habitats/humidity_relocation_slice.tres
    └── HabitatScenarioConfig（2 zones）

data/habitats/sugar_foraging_slice.tres
    ├── HabitatScenarioConfig（3 zones）
    └── data/behaviors/sugar_foraging_prototype.tres
         └── ForagingConfig

data/habitats/combined_observation_slice.tres
    ├── HabitatScenarioConfig（3 zones）
    ├── data/habitats/combined_observation_sequence.tres
    │    └── ScenarioSequenceConfig
    └── data/behaviors/sugar_foraging_prototype.tres
         └── ForagingConfig
```

- `LifecycleConfig` 只保存产卵和阶段转换配置。
- `BroodCareConfig` 保存幼体舒适湿度、最小改善、决策间隔、拾取／移动／放下时长和区域停留冷却。
- `HabitatScenarioData.zones` 是包含 2～3 个稳定区域 ID 的强类型数组。
- `HabitatScenarioConfig` 保存切片初始实体、区域、连接、湿度与对应场景的高层动作参数。
- `ForagingConfig` 保存发现、去程、采集、返程和分享时长。
- `ScenarioSequenceConfig` 保存首工晚期蛹的初始阶段年龄，以及首工羽化和湿度响应两张观察卡 ID。
- Resource 通过验证后复制到私有运行时对象；修改源 `.tres` 不会改变已经开始的模拟。
- `restart_session()` 使用相同的私有冻结配置创建全新 `ColonyState`，并清空旧会话的待处理命令；不会再次读取 Resource。
- 所有行为与场景数据都标记为 `prototype_pacing_fixture` 且 `scientifically_validated = false`。它们是游戏节奏夹具，不是真实物种数据。

M3 前先把已经验证的幼体搬运逻辑提取为 `BroodRelocationSystem`。`ColonySimulation` 继续拥有连续 Tick 检查、命令队列、系统调用顺序、观察状态、不变量总校验与快照创建。提交 `62ae740` 固定了拆分前的补水流程、事件、重开与滚动快照 SHA-256 黄金结果；拆分后的旧回归继续使用同一份签名验证行为等价。

M4 在既有 `HabitatScenarioData.ScenarioKind` 末尾追加 `COMBINED_OBSERVATION`，不改变原有枚举值。组合配置同时声明湿度和糖水能力，并额外冻结 `ScenarioSequenceData`；原有湿度和糖水配置继续走各自的兼容路径。组合 Resource 必须精确符合“育幼室 ↔ 栖息室 ↔ 觅食区”的双向线性邻接，补水目标、首工初始区和幼体初始区都必须是巢室；额外捷径或不可用区域会在冻结前被拒绝。`ColonySimulation` 再结合冻结的 `BroodCareConfig` 验证：初始状态能触发明显改善的首次搬运，最多 4 次配置补水能到达舒适范围，并能让幼体产生返回巢室的明确改善；不可完成的组合不会进入运行态。

## 4. 权威模型

### `ColonyState`

保存：

- 当前模拟 Tick。
- 蚁后与稳定 ID 实体数组。
- 2～3 个 `HabitatZoneState`。
- `FoodSourceState`、已放置糖水份数、已分享份数和观察卡 ID。
- 已应用湿度调整次数。
- 观察稳定 Tick 和观察记录解锁状态。
- 组合场景中的 `ScenarioProgressState`。
- 会话内单调事件 ID 和最多 64 条的结构化观察事件历史。

组合场景初始化时，蚁后固定为实体 ID 0，晚期蛹先于其余幼体创建并取得实体 ID 1。它从蛹原地转换为工蚁时不创建替代实体；`ScenarioProgressState.first_worker_entity_id` 始终指向这个 ID，`configure_worker()` 在同一个 `AntModel` 上建立 `WorkerTaskModel` 与 `ForagingTaskModel`。重开会从冻结配置重新执行同一稳定 ID 分配顺序。

### `ScenarioProgressState` 与 `ScenarioDirector`

`ScenarioProgressState` 是组合流程的权威事实来源，归 `ColonyState` 所有，保存当前阶段、进入阶段的 Tick、首工实体 ID，以及首工羽化、湿度完成和糖水完成 Tick。

`ScenarioDirector` 是纯 `RefCounted` 协调器，只持有冻结的生命周期、育幼、栖息地和序列配置。它不持有平行状态，也不引用 Godot 场景节点。它负责：

- 仅在建群序幕推进指定晚期蛹的受控生命周期。
- 首工羽化后在原实体上配置两类任务状态，记录事件并解锁首工观察卡。
- 应用身份阶段的继续命令。
- 在湿度或糖水系统达成条件后推进阶段并记录完成 Tick。
- 从 `ScenarioProgressState` 构造只读的 `ScenarioSequenceSnapshot`。
- 校验首工、阶段时间、观察卡、糖水与实体 ID 之间的组合流程不变量。

五阶段只能逐段前进：

```text
FOUNDING_PRELUDE
    → IDENTITY_OBSERVATION
    → HUMIDITY_OBSERVATION
    → SUGAR_FORAGING
    → OBSERVATION_SUMMARY
```

首工羽化自动完成第一段；`submit_continue_observation_action()` 在下一合法 Tick 完成身份段；湿度观察稳定条件达成后进入糖水段；糖水分享观察卡解锁后进入总结段。阶段切换不创建新 `ColonyState`。

### `HabitatZoneState`

每个区域保存稳定 `StringName zone_id`、限制在 0.0～1.0 的湿度、可达连接 ID 和可用状态。模拟只使用区域 ID 与逻辑连接，不包含坐标、尺寸或颜色。

### `AntModel`

所有非蚁后实体保持原有稳定 ID，保存生命周期字段、`zone_id` 和 `zone_entered_tick`。工蚁额外持有 `WorkerTaskModel` 与 `ForagingTaskModel`；幼体和食物源不保存反向预订或携带引用。

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

### `FoodSourceState`

保存稳定实体 ID、逻辑区域 ID、食物类型、剩余份数和可用状态。当前食物类型只有 `SUGAR_WATER`；`ColonyState.remove_food_source()` 将目标转为 `available = false` 的守恒墓碑，而不是直接从数组擦除。这样 View 会隐藏目标，任务会清理预订，剩余份数仍可审计；直接擦除权威数组属于非法内部状态。

### `ForagingTaskModel`

使用六个显式状态：

```text
IDLE
SEEKING_FOOD
MOVING_TO_FOOD
COLLECTING
RETURNING_TO_NEST
SHARING
```

任务保存目标食物源、来源／目标／巢室区域、任务内缓存路线、携带份数、阶段已用 Tick 和阶段总 Tick。

### `BroodRelocationSystem` 与 `ForagingSystem`

`BroodRelocationSystem` 负责原有幼体适宜度、任务校验、推进、分配和所有权检查。`ForagingSystem` 负责稳定食物选择、路径校验、觅食状态推进、糖水守恒、结构化事件与观察卡解锁。两个系统都只读取纯模拟对象；当前同一工蚁不能同时执行两类任务。

### `ObservationEvent`

模拟在首工羽化、身份观察完成、幼体搬运、糖水发现、出发、采集、返程、分享、取消、各观察首次完成和整局完成时追加结构化值对象。M4 追加的事件类型包括 `FIRST_WORKER_EMERGED`、`IDENTITY_OBSERVATION_COMPLETED` 与 `OBSERVATION_SESSION_COMPLETED`；每条事件只包含：

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
- 独立湿度场景有两个直接连接区域；组合场景虽然有三个区域，幼体搬运也只检查来源区的直接连接，不使用多跳路径系统。

### 糖水任务与路径

- 空闲工蚁和可用食物源按稳定实体 ID 选择，平局确定。
- 区域连接使用稳定 `StringName` ID；简单 BFS 在展开前按区域 ID 排序邻接点。
- 路径结果写入 `ForagingTaskModel.route_zone_ids` 并在任务推进中复用；新去程、返程或缓存路线失效时才重新求路。
- 当前没有 `NavigationServer`、A*、自由地图或通用路径服务。
- 采集前食物源或路径软失效会取消任务并释放预订。
- 采集后返巢路径暂时失效时保留糖水所有权、旧路线和当前进度；路径恢复后继续，不清空任务或伪造直线移动。

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

糖水场景还必须满足：

- `remaining + carried + shared == total_placed`，每一项均为有限非负整数。
- 一个食物源最多被一个活跃觅食任务声明。
- 一只工蚁最多携带一份糖水。
- 采集前状态不携带糖水；返巢与分享状态恰好携带一份。
- `IDLE` 不残留食物源、路线、区域目标、携带量或阶段计时。
- 同一工蚁不能同时执行幼体搬运与觅食。
- 软失效取消采集前任务并清理预订；采集后路径失效不丢弃携带所有权。

组合场景还由 `ScenarioDirector.has_valid_state()` 校验：

- 首工实体始终存在，建群序幕中仍是未配置任务的蛹，后续阶段中仍是同时具有两类任务状态的同一只工蚁。
- 蚁后、蚂蚁和食物源的实体 ID 不重复。
- 阶段进入 Tick 和各完成 Tick 不超出当前模拟 Tick。
- 观察卡、完成 Tick、糖水放置状态和当前阶段保持一致。
- 身份阶段首工空闲；糖水阶段不残留搬运任务；总结阶段两类任务都已回到空闲。

## 8. 每 Tick 更新顺序

`ColonySimulation.advance_tick()` 的实际顺序：

1. 验证 Tick 必须连续；失败时不消费命令。
2. 写入当前 Tick。
3. 按提交顺序应用并清空本 Tick 的身份继续／补水／糖水高层命令；湿度夹紧到有限的 0.0～1.0。
4. 组合场景由 `ScenarioDirector` 推进指定晚期蛹；其他栖息地切片不推进生命周期，无栖息地的独立调试入口保持完整生命周期流程。
5. 校验 `BroodRelocationSystem` 现有任务。
6. 配有觅食系统时校验 `ForagingSystem` 现有任务。
7. 推进幼体搬运任务。
8. 配有觅食系统时推进糖水觅食任务。
9. 独立湿度场景始终允许分配搬运；组合场景只在 `HUMIDITY_OBSERVATION` 分配新的搬运任务。
10. 独立糖水场景始终允许分配觅食；组合场景只在 `SUGAR_FORAGING` 分配新的觅食任务。
11. 与搬运分配使用同一阶段门控，更新湿度观察稳定计数与解锁状态。
12. 组合场景在系统更新后由 `ScenarioDirector` 检查湿度／糖水完成条件并推进阶段。
13. 校验栖息地、幼体搬运、糖水守恒与组合进度不变量。
14. 每个成功 Tick 后，由控制器立即创建并交付一份新快照。

系统结果不依赖场景树处理顺序、渲染帧率或墙钟时间。

## 9. 快照边界

`ColonySimulation.create_snapshot()` 每次新建：

- 一个 `ColonySnapshot`。
- 每个区域对应的 `HabitatZoneSnapshot`，包括新的连接 ID 数组。
- 每个实体对应的 `AntSnapshot`。
- 有界结构化事件历史中每个 `ObservationEvent` 的副本。

快照包含显示和诊断所需的区域、任务进度、派生预订／携带关系、补水门控与待处理状态、生命周期模式、观察状态和结构化事件，但不携带任何内部模型引用。修改快照字段、事件对象、子对象或数组不会改变模拟。

`ColonySnapshot` 不平铺 `sugar_*` 或五阶段 UI 状态；它只包含群落领域数据，`AntSnapshot` 通过嵌套的 `ForagingTaskSnapshot` 表达觅食任务。支持糖水的场景由 `create_game_snapshot()` 返回：

- `GameSnapshot.simulation_tick`
- `GameSnapshot.colony: ColonySnapshot`
- `GameSnapshot.scenario: ForagingScenarioSnapshot`，保存场景阶段、巢室／放置区域和动作可用／待处理状态
- `GameSnapshot.observations: ObservationJournalSnapshot`，深复制事件与已解锁卡片 ID
- `GameSnapshot.sequence: ScenarioSequenceSnapshot`，保存五阶段、阶段进入／完成 Tick、稳定首工 ID、三张冻结观察卡 ID，以及继续命令的可用／待处理状态

`sequence` 只在组合场景存在；独立糖水场景继续使用前三个组成部分。M2 兼容路径仍保留 `ColonySnapshot.observation_events`，独立糖水控制器继续读取 `ObservationJournalSnapshot`。任何快照都不是命令入口，也不能写回模拟。

控制器在命令提交后可以创建同 Tick 新快照来展示待处理状态；只有成功推进到下一 Tick 后，快照中的权威湿度、阶段或食物源才反映命令效果。所有数组、事件和嵌套快照都重新创建或复制，修改快照不会改变 `ColonyState`。

## 10. 显示层

### 默认组合显示层

`CombinedHabitatView` 只读取完整 `GameSnapshot`：

- 绘制育幼室、休息室、觅食区和连接通道；坐标、尺寸、颜色与糖水点击命中只存在于 View。
- 维护稳定的 `entity_id -> AntView` 映射和独立 `QueenView`。
- 首工从蛹转换为工蚁时沿用相同实体 ID，因此对已有 `AntView` 应用新阶段快照，不替换节点。
- 根据 `WorkerTaskSnapshot`、`ForagingTaskSnapshot`、逻辑路线和阶段进度计算蚂蚁位置；不使用与模拟脱节的 Tween。
- 相邻 Tick 间使用同一个 `SimulationClock` 的插值系数，暂停时冻结；同 Tick 快照只更新状态，不轮换插值端点。
- 重复快照不创建重复节点；重开时 `reset_projection()` 清除旧端点、实体映射和临时糖水投影。

`CombinedObservationController` 从 `ScenarioSequenceSnapshot` 投影五阶段标题、阶段按钮、三张观察卡和总结面板；从 `ColonySnapshot`、`ForagingScenarioSnapshot` 与 `ObservationJournalSnapshot` 投影对应的环境、工具和事件状态。UI 只组合快照，不能直接推进阶段或修改群落状态。

玩家可见的阶段说明、反馈和观察卡同时携带小型 `evidence_copy_role` 元数据：`observation_cue`、`action_affordance`、`neutral_placeholder`、`post_event_conclusion`、`system_status` 或 `error`。锁定卡只能使用中性占位，事件完成后才能切换为结论角色；场景测试检查角色和节点状态，不绑定完整中文句子。这是当前场景的证据边界，不是通用本地化或文案框架。

### 独立湿度显示层

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

普通 UI 不显示精确湿度、任务枚举、目标 ID、生命周期倒计时或调试入口。F3 诊断层读取相同快照并显示精确内部状态，但组合场景只在 `OS.is_debug_build()` 为真时响应 F3；普通布局没有按钮或底部提示。release 外测构建的实际禁用证据属于后续 R0-B。

### 会话身份层

`PlayerAnnotationState` 是独立于权威模拟的会话对象：

- 只保存当前选择的稳定工蚁 ID、可选名称、每只工蚁最近最多 5 条事件副本和事件消费游标。
- 每次快照按 `event_id` 顺序消费所有新事件；重复快照按游标去重，ID 缺口被显式记录。
- 选择实体消失或不再是工蚁时，清除对应选择、名称与历史。
- `restart_session()` 的控制流程同时重置选择、全部名称、个人历史和消费游标。
- 不持有 `AntModel`、`ColonyState` 或可写模拟引用，也不向模拟回写任何身份信息。

`WorkerObservationPanel` 只读取所选 `AntSnapshot` 和过滤后的事件副本，显示自然语言当前行为与最近 4 条记录。名称提交只写入 `PlayerAnnotationState`。16× 时控制器仍在每个成功 Tick 后交付快照，因此同一渲染帧跨越的多条事件会依次被消费，而不是只保留最后一条。

### 独立糖水显示层

`SugarForagingHabitatView` 只读取 `GameSnapshot`，维护稳定的 `entity_id -> AntView` 映射和独立 `QueenView`。区域坐标、颜色、糖滴绘制、命中区域和携带偏移只存在于 View。工蚁位置由 `ForagingTaskSnapshot` 的状态、进度和缓存路线计算，相邻 Tick 间使用时钟插值；暂停时冻结，不使用 Tween。

`SugarForagingController` 只协调时钟、无参数高层命令、快照、工具的临时“已启用”状态、身份面板与 F3。有效区域点击提交命令后，同 Tick 快照只显示 `place_action_pending`，食物源在下一 Tick 才出现。

## 11. 保留的独立调试与验证入口

`scenes/debug/lifecycle_debug.tscn` 使用：

```text
ColonySimulation(species_data, null)
    ↓
TestTubeHabitat
    ↓
ColonyViewAdapter
```

无栖息地配置时，`ColonySimulation` 保持原有产卵与卵 → 幼虫 → 蛹 → 工蚁流程。阶段中文显示映射位于 View 层的 `LifeStagePresenter`，核心 `AntModel` 不负责本地化。

另外两条旧入口继续保留：

- `scenes/main/main.tscn` 使用 `MainController + HabitatView`，独立验证双室湿度搬运和身份观察。
- `scenes/foraging/sugar_foraging.tscn` 使用 `SugarForagingController + SugarForagingHabitatView`，独立验证三区域糖水觅食。

这些场景各自创建独立会话，不使用五阶段 `ScenarioDirector`，用于保留原有回归与人工验证能力。默认 `project.godot` 主场景是 `scenes/main/combined_observation.tscn`。

## 12. 测试结构

`tests/test_runner.gd` 只聚合独立套件：

- `tests/core/simulation_clock_test_suite.gd`
- `tests/simulation/lifecycle_test_suite.gd`
- `tests/simulation/humidity_relocation_test_suite.gd`
- `tests/simulation/brood_relocation_equivalence_test_suite.gd`
- `tests/simulation/foraging_test_suite.gd`
- `tests/simulation/combined_observation_test_suite.gd`
- `tests/simulation/observation_event_test_suite.gd`
- `tests/session/player_annotation_state_test_suite.gd`
- `tests/view/view_adapter_test_suite.gd`
- `tests/view/habitat_view_interpolation_test_suite.gd`
- `tests/view/worker_observation_panel_test_suite.gd`
- `tests/scenes/lifecycle_debug_scene_test_suite.gd`
- `tests/scenes/humidity_main_scene_test_suite.gd`
- `tests/scenes/worker_identity_scene_test_suite.gd`
- `tests/scenes/sugar_foraging_scene_test_suite.gd`
- `tests/scenes/combined_observation_scene_test_suite.gd`

生命周期边界从 Resource 计算。湿度套件覆盖原有命令、搬运、所有权、节奏和 soak；黄金套件锁定 `BroodRelocationSystem` 拆分前后等价。糖水套件覆盖下一 Tick 命令、冻结配置、稳定选择、全部状态边界、软失效与返程恢复、份数守恒、快照隔离、三档速度、事件和 10,000 Tick soak。组合模拟套件覆盖五阶段顺序、稳定首工 ID、阶段门控、三类命令、冻结配置、精确线性拓扑、湿度闭环可完成性、快照隔离、重开和组合不变量；组合场景套件覆盖真实阶段按钮、快照卡片 ID、糖水落点、总结与 View 节点复用。场景测试使用实际按钮和 Viewport 鼠标输入路径，不绑定完整中文文案。

标准命令：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script 'res://tests/test_runner.gd'
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 30
```

自动测试不替代 1280×720 的人工可读性检查。

## 13. 当前限制

- 湿度和行为数值是原型节奏参数，未经真实养蚁数据审校。
- 默认组合场景固定为三个区域、一个接近羽化的晚期蛹、五个幼虫和一份糖水；五阶段按唯一顺序推进，不支持分支。
- 当前冻结配置在无额外玩家停留时于 Tick 586 完成，技术上已形成连续流程，但尚未达到 12～15 分钟的外部试玩节奏目标；架构不会通过无信息等待补足时长。
- 原有生命周期、双室湿度和三区域糖水场景仍作为独立调试／验证入口；它们不会与默认组合会话共享状态。
- 名称、选择和个人记录只存在于当前会话，重开后不保留。
- 糖水分享只解锁观察记录，不实现饥饿、能量、蛋白质或资源经济。
- 没有镜头、直接个体命令、存档、随机行为、正式素材或外部插件。
