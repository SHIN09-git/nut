# 《玻璃蚁国》技术架构

> 文档版本：2.1｜更新日期：2026-07-29
>
> 本文描述当前 R12 正式 Act 1 六章、稳定群落结局与双室模块化迁巢、R9 清理／侦察／迁巢任务、R8 设施与环境传播、R7 模块化布局与镜头、版本化存档和档案设置外壳，以及仍保留的旧组合与独立调试／验证路径。

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
| 应用外壳 | 标题／档案／设置／确认页、暂停菜单、键盘焦点、三档 UI 缩放和减少动效 |
| 章节手册 | Act 1 六章显式枚举、权威证据、推论、递进提示、固定设施工具包解锁、最终报告与结算；不使用任务 DSL |
| 蚁后护理 | 独立冻结配置和休息／靠近幼体／护理三态确定性循环；只在正式 Act 1 启用 |
| 营养成长 | 冻结糖／蛋白储备、确定性觅食与育幼喂食、短缺减速和资源约束生命周期 |
| 设施与布局 | 12×8 逻辑槽位、冻结占地／接口／方向、稳定设施与连接 ID、权威库存、下一 Tick 布局命令 |
| 设施效果 | 巢室、补水、喂食、垃圾、连接和遮光使用强类型冻结效果；不使用通用 Dictionary 效果框架 |
| 区域环境 | 湿度、光照、污染均为 0～1 权威值；开放连接上的污染传播按稳定顺序确定性计算 |
| 群落工作 | 废物清理、区域侦察、群落迁移使用三个专用显式状态机；与搬运、觅食、喂食互斥 |
| 布局镜头 | `FacilityLayoutView` 只读布局快照；鼠标与键盘平移缩放不进入模拟或存档 |
| 存档核心 | `r12.authority.v10` 规范化 JSON、版本／清单／checksum 校验、双室／终章报告权威、主档／备份恢复和单向迁移 |
| 测试 | 项目自建 headless runner，无第三方插件 |

## 2. 数据流与命令边界

```text
PreparationGate（应用层，Tick 0）
    └── StartObservationButton → 只释放 SimulationClock
                               （不进入模拟命令队列）
    ↓
Act1TestTubeController
    ├── 遮光套按钮 → submit_apply_light_cover_action()
    ├── 糖液按钮 → submit_place_sugar_action()
    ├── 蛋白按钮 → submit_place_protein_action()
    ├── 清理按钮 → submit_clean_waste_tray_action(facility_id)
    ├── 手册推论按钮 → submit_campaign_inference_action(inference_id)
    └── 布局操作 → submit_place/rotate/remove_facility_action(...)
                    submit_set_gate_open_action(connection_id, open)
                          （推论／设施使用稳定逻辑 ID，不携带效果量）
    ↓
ColonySimulation._pending_commands
    ↓ 先验证 Tick 连续，再按提交顺序消费
    ↓ 下一合法固定 Tick 开始时使用冻结配置应用
ColonyState + Act1State + CampaignState + HabitatLayoutState
    ↓
EnvironmentSystem（设施效果与污染传播）
    ↓
栖息地生命周期 + FoundingCareSystem
    ↓
搬运／觅食／育幼任务校验与推进
    ↓
按当前章节分配新任务
    ↓
Act1CampaignDirector 从护理、首工与营养事件收集证据并结算推论
    ↓
校验栖息地、任务、守恒、Act1 状态与章节不变量
    ↓ create_game_snapshot() 深复制
GameSnapshot
    ├── ColonySnapshot
    ├── ForagingScenarioSnapshot
    ├── ObservationJournalSnapshot
    ├── NutritionSnapshot
    ├── Act1Snapshot
    ├── HabitatLayoutSnapshot
    └── CampaignSnapshot
            ├── Act1TestTubeView
            │    └── FacilityLayoutView
            ├── Act1TestTubeController 的章节 UI
            └── 开发调试构建中的 F3 DebugPanel
```

提交命令时不会直接修改权威状态。控制器在提交成功后立即重新取同 Tick 快照，所以 UI 可以先看到遮光、糖液或推论的待处理状态；命令效果只会在下一合法固定 Tick 出现。`ColonySimulation` 在消费命令前拒绝非连续 Tick，因此错误推进不会丢失已提交输入。

准备门是 `Act1TestTubeController` 的应用层状态，不属于 `ColonyState`、命令队列或 `Act1State`。门内 `SimulationClock` 保持 Tick 0、1×和暂停，View 插值系数固定为 0，蚁后与蚂蚁视觉暂停；开始按钮只解除这些暂停。首工的生命周期边界仍由冻结 Resource 和模拟 Tick 决定。重开先创建全新模拟会话，再回到同一个准备门。

Act 1 会话从开始到六章完成始终持有同一个 `SimulationClock`、同一个 `ColonySimulation` 和其中同一个 `ColonyState`。`FoundingCareSystem` 与 `Act1CampaignDirector` 只持有冻结配置并操作同一权威状态，不会替换时钟、重载场景或重建首工。

`Act1TestTubeController` 只负责：

- 推进 `SimulationClock`。
- 协调 Tick 0 准备门，并在开始前冻结时钟、插值和视觉。
- 把遮光、糖液和蛋白 UI 操作转换成无参数高层模拟命令。
- 把设施类型、逻辑槽位、方向、稳定设施／连接 ID 转换成现有布局高层命令；不提供权威效果量。
- 把观察手册选项转换成带稳定推论 ID 的高层模拟命令；UI 文案不是权威输入。
- 每个成功固定 Tick 后创建并交付一份 `GameSnapshot`。
- 把快照交给 `Act1TestTubeView`、章节面板、观察手册和调试 UI。
- 每个渲染帧把时钟插值系数交给 View。
- 协调暂停、显式保存、返回标题、重开和完成后继续观察。
- 协调应用层暂停菜单、显示模式、语言和退出；这些状态不进入模拟命令队列。
- 在模拟或 View 拒绝更新时暂停并显示可见错误。

控制器不能访问私有 `ColonyState`，也不创建或逐只管理蚂蚁视觉节点。放大镜是纯显示辅助；它不写入模拟。

`DemoSettingsState` 保存分辨率、全屏、语言、UI 缩放、减少动效和主音量。应用外壳把它独立持久化并与当前游戏控制器共享；它不读取或修改 `ColonyState`，也不进入 `GameSnapshot`。打开暂停菜单只暂停 `SimulationClock` 并冻结 View 插值；继续时恢复合法时钟语义。显示、语言、动效和音量切换不会推进 Tick、消费命令或改变模拟快照。

旧 `CombinedObservationController`、独立湿度和糖水入口继续遵守相同边界：

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

data/habitats/act1_test_tube.tres
    ├── HabitatScenarioConfig（3 zones）
    ├── data/behaviors/act1_environment_prototype.tres
    │    └── EnvironmentConfig
    ├── data/behaviors/founding_care_prototype.tres
    │    └── FoundingCareConfig
    ├── data/behaviors/act1_nutrition_prototype.tres
    │    └── NutritionConfig
    ├── data/behaviors/colony_work_prototype.tres
    │    └── ColonyWorkConfig
    ├── data/behaviors/act1_progression_prototype.tres
    │    └── Act1ProgressionConfig
    └── data/facilities/act1_layout_catalog.tres
         └── FacilityCatalogConfig
```

- `LifecycleConfig` 只保存产卵和阶段转换配置。
- `BroodCareConfig` 保存幼体舒适湿度、最小改善、决策间隔、拾取／移动／放下时长和区域停留冷却。
- `HabitatScenarioData.zones` 是包含 2～3 个稳定区域 ID 的强类型数组。
- `HabitatScenarioConfig` 保存切片初始实体、区域、连接、环境值与对应场景的高层动作参数。
- `ForagingConfig` 保存发现、去程、采集、返程和分享时长。
- `ScenarioSequenceConfig` 保存首工晚期蛹的初始阶段年龄，以及首工羽化和湿度响应两张观察卡 ID。
- `FoundingCareConfig` 保存蚁后休息、靠近幼体、护理与蛹观察的节奏、首工晚期蛹的初始阶段年龄，以及 Act 1 四类观察卡 ID。
- `EnvironmentConfig` 冻结污染传播、幼体污染舒适上限／惩罚与蚁后护理光照上限。
- `ColonyWorkConfig` 冻结废物批次与时长、侦察时长、迁巢改善阈值／稳定窗口／停留冷却和各决策间隔。
- `Act1ProgressionConfig` 冻结第 3 章最小工蚁数、第 4 章污染改善阈值／环境稳定窗口、第 5 章核心迁移稳定窗口，以及第 6 章稳定窗口／最终报告卡 ID；它只协调当前六章节奏，不承载生命周期或通用任务规则。
- `FacilityCatalogConfig` 冻结逻辑网格、设施占地、允许方向、接口、布局层、初始设施、有限库存与每类设施的强类型 `FacilityEffectConfig`；不包含屏幕坐标、颜色或通用环境效果字典。
- 正式 Act 1 冻结配置声明生命周期与营养均启用；章节快照门控依次开放糖液、蛋白、觅食／卫生设施和环境／连接设施。
- Resource 通过验证后复制到私有运行时对象；修改源 `.tres` 不会改变已经开始的模拟。
- `restart_session()` 使用相同的私有冻结配置创建全新 `ColonyState`，并清空旧会话的待处理命令；不会再次读取 Resource。
- 所有行为与场景数据都标记为 `prototype_pacing_fixture` 且 `scientifically_validated = false`。它们是游戏节奏夹具，不是真实物种数据。

M3 前先把已经验证的幼体搬运逻辑提取为 `BroodRelocationSystem`。`ColonySimulation` 继续拥有连续 Tick 检查、命令队列、系统调用顺序、观察状态、不变量总校验与快照创建。提交 `62ae740` 固定了拆分前的补水流程、事件、重开与滚动快照 SHA-256 黄金结果；拆分后的旧回归继续使用同一份签名验证行为等价。

M4 在既有 `HabitatScenarioData.ScenarioKind` 末尾追加 `COMBINED_OBSERVATION`，不改变原有枚举值。组合配置同时声明湿度和糖水能力，并额外冻结 `ScenarioSequenceData`；原有湿度和糖水配置继续走各自的兼容路径。组合 Resource 必须精确符合“育幼室 ↔ 栖息室 ↔ 觅食区”的双向线性邻接，补水目标、首工初始区和幼体初始区都必须是巢室；额外捷径或不可用区域会在冻结前被拒绝。`ColonySimulation` 再结合冻结的 `BroodCareConfig` 验证：初始状态能触发明显改善的首次搬运，最多 4 次配置补水能到达舒适范围，并能让幼体产生返回巢室的明确改善；不可完成的组合不会进入运行态。

R6 在枚举末尾追加 `ACT1_TEST_TUBE`。该配置必须同时具有序列、蚁后护理、觅食与营养冻结数据，初始工蚁为 0，初始个体按“晚期蛹、两枚卵”的稳定顺序建立。运行中修改任何源 Resource 都不会改变遮光门控、护理节奏、首工边界、糖液份数或营养规则。

R7 为 Act 1 冻结 `FacilityCatalogData`。运行时只使用复制后的 `FacilityCatalogConfig`；源 Resource 的槽位、接口、方向、库存或初始设施在会话开始后即使被修改，也不能改变当前模拟。非 Act 1 旧场景没有设施目录，但其旧区域邻接仍在初始化时迁入 `HabitatLayoutState` 的稳定连接实例。

R8 为正式 Act 1 冻结 `EnvironmentData` 和设施目录中的具体效果 Resource。运行时 `EnvironmentConfig` 与 `FacilityEffectConfig` 是唯一规则来源；源 `.tres` 的环境值、效果类型、容量或速率在会话开始后被修改，不会改变当前模拟。旧验证场景继续使用 `environment_config = null`，不会被隐式赋予新环境规则。

R9 为正式 Act 1 冻结 `ColonyWorkData`。运行时 `ColonyWorkConfig` 是清理、侦察与迁巢的唯一节奏和阈值来源；源 Resource 在会话开始后被修改不会改变任务分配、批次、目标选择或清理结果。

R10 为正式 Act 1 冻结 `Act1ProgressionData`。运行时 `Act1ProgressionConfig` 是第 3 章规模阈值、污染规避对比和第 4 章稳定窗口的唯一来源；Director、快照和 UI 在 `_ready()` 后不读取源 Resource。备用试管的可旋转方向、必须连接约束和动态环境初值同样来自冻结设施目录。

R11 在设施效果枚举末尾追加 `DUAL_CHAMBER_ZONE`，不改变旧枚举数值。一个双室设施拥有 `zone_id` 与 `secondary_zone_id` 两个稳定区域 ID、一个内部连接，以及按本地占用单元映射到具体房间的外部接口；环境、发现状态和迁巢所有权仍逐区域保存。双室初值和两室污染速率来自专用 `DualChamberFacilityEffectData`，核心迁移稳定窗口来自同一冻结 `Act1ProgressionConfig`。运行中的模拟和 UI 不读取源 Resource。

## 4. 权威模型

### `ColonyState`

保存：

- 当前模拟 Tick。
- 蚁后与稳定 ID 实体数组。
- 初始 2～3 个 `HabitatZoneState`，以及设施放置后按稳定设施 ID 派生的动态区域。
- `FoodSourceState`、已放置糖水份数、已分享份数和观察卡 ID。
- 已应用湿度调整次数。
- 观察稳定 Tick 和观察记录解锁状态。
- 组合场景中的 `ScenarioProgressState`。
- 组合场景中的 `CampaignState`：章节、状态、进入 Tick、错误推论次数、提示层级、证据、已确认推论和设施工具包。
- 正式 Act 1 场景中的 `Act1State`：遮光动作、蚁后护理、蛹观察、首工身份、首次工蚁护理证据与环境连续稳定 Tick。
- 营养场景与 Act 1 中的 `ColonyNutritionState`。
- 所有栖息地场景中的 `HabitatLayoutState`：稳定设施、显式区域连接、闸门开关、有限设施库存、布局 revision 与各 ID 域的下一个值。
- 正式 Act 1 区域中的湿度、光照和污染，以及垃圾设施已收集容量。
- 正式 Act 1 的 `ColonyWorkState`：迁巢候选／稳定 Tick／目标、三个完成计数；区域自身保存发现状态与发现 Tick，蚁后保存唯一 `zone_id` 和进入 Tick。
- 会话内单调事件 ID 和最多 64 条的结构化观察事件历史。

组合场景初始化时，蚁后固定为实体 ID 0，晚期蛹先于其余幼体创建并取得实体 ID 1。它从蛹原地转换为工蚁时不创建替代实体；`ScenarioProgressState.first_worker_entity_id` 始终指向这个 ID，`configure_worker()` 在同一个 `AntModel` 上建立 `WorkerTaskModel` 与 `ForagingTaskModel`。重开会从冻结配置重新执行同一稳定 ID 分配顺序。

正式 Act 1 使用同样的稳定身份约束：实体 ID 1 是晚期蛹，之后才建立两枚卵；羽化时在同一个 `AntModel` 上配置觅食与育幼状态。初始三个幼体计入本场景已建立的首代个体，生命周期上限不会再次产生重复批次。

### `HabitatLayoutState`

布局状态是设施与可达关系的唯一事实来源：

- `facility_id -> FacilityState` 保存类型、逻辑槽位、方向、主区域、可选次区域、可用状态、可拆除标记与垃圾收集量。普通设施的次区域为空；双室巢的两个区域均由同一个稳定设施 ID 所有。
- `connection_id -> HabitatConnectionState` 保存两个稳定区域 ID、闸门属性、开关和所属设施。
- `FacilitySupplyState` 保存冻结工具包的剩余数量；章节解锁与库存必须同时满足才会发布合法放置选项。
- 占地、边界、布局层、接口种类和相反方向匹配都从冻结目录确定性验证。
- 放置、旋转、拆除和闸门开关只在下一连续 Tick 消费；同一时刻最多一个布局命令待处理。
- 双室巢未被实体、任务或叠放设施引用时可以旋转；一旦补水／喂食／废物设施绑定到任一房间，旋转命令会在提交边界被拒绝，避免物理格与权威宿主区域错位。
- 拆除先检查设施是否仍被实体、食物、任务、路线或携带关系引用；拒绝时不产生部分修改，成功时归还库存并清理设施拥有的连接。
- 区域邻接缓存由布局 revision 派生。设施或闸门变化使缓存失效；缓存本身不写入存档。

`ColonyState.zones` 中的运行时 `HabitatZoneState` 副本携带区域 ID、湿度、光照、污染和可用状态；配置冻结阶段仍暂用同一值对象读取旧 `.tres` 邻接，并立即迁入初始布局。提供区域的设施使用 `类型_ID + 稳定设施_ID` 建立稳定动态区域 ID；放置或拆除与区域、派生连接一起原子应用。搬运、觅食与喂食系统统一通过 `ColonyState.find_stable_zone_path()` 查询布局权威，不读取运行时区域对象上的邻接数组。

### `EnvironmentSystem`

`EnvironmentSystem` 是纯 `RefCounted` 系统，在每个合法 Tick 中位于命令消费之后、生命周期与任务之前：

- 巢室按冻结速率产生污染；补水与遮光设施分别把宿主区域逐 Tick 推向冻结目标。
- 垃圾托盘在容量内按冻结速率被动捕获宿主区域污染；R9 工蚁还能把有限污染批次搬入托盘，玩家清理命令在下一 Tick 原子清空未被活动任务引用的托盘。
- 开放连接按稳定连接 ID 计算污染差，先累积全部 delta，再按稳定区域 ID 应用，避免字典顺序和同 Tick 前后次序影响结果。
- 糖液与蛋白放置先选择稳定、可达且接受对应类型的喂食设施；拥有活动食物源的设施不可拆除。
- 幼体适宜度加入污染惩罚；蚁后护理同时要求遮光设施和冻结光照上限。
- 所有环境值与垃圾容量都拒绝 NaN／无穷并限制在合法范围。

### `Act1State`、`FoundingCareSystem` 与 `Act1CampaignDirector`

`Act1State` 由 `ColonyState` 唯一拥有，保存遮光是否已应用和应用次数、蚁后护理状态／阶段 Tick／目标幼体／完成次数、蛹稳定观察 Tick、首工实体 ID／羽化 Tick、首次工蚁护理是否记录、第 4／5 章环境连续稳定 Tick、第 6 章稳定 Tick 和最终报告生成 Tick。

`FoundingCareSystem` 是纯 `RefCounted` 系统。遮光命令在下一合法 Tick 应用；遮光前护理保持休息态，遮光后按冻结时长在 `RESTING → GATHERING → BROOD_CARE` 间循环。目标幼体按稳定实体 ID 选择。它还根据同一权威生命周期与营养任务生成蛹观察、首工羽化和工蚁护理证据。

`Act1CampaignDirector` 只使用六个显式章节：

```text
ACT1_FOUNDING
    → ACT1_FIRST_WORKERS
    → ACT1_FORAGING_EXPANSION
    → ACT1_ENVIRONMENT_MANAGEMENT
    → ACT1_MODULAR_MIGRATION
    → ACT1_STABLE_COLONY_SUMMARY
    → COMPLETED
```

第一章要求蚁后护理与蛹观察证据，正确推论解锁微型喂食口；第二章要求首工羽化、工蚁育幼和首次营养交换证据，正确推论解锁小型觅食盒、糖液台、蛋白盘和垃圾托盘。第三章从章节进入后的结构化侦察、糖液分享、蛋白育幼和托盘清理事件，加上冻结最小工蚁数收集证据；正确推论解锁备用试管、补水与连接组件族。第四章从补水后的舒适区域、迁移放下事件的污染对比、部分迁移和连续稳定窗口收集证据；正确推论解锁双室模块巢。第五章要求双室巢连通并让育幼室舒适、两室均已侦察、全部幼体与蚁后迁入育幼室，同时功能室到喂食与废物设施的路径可用且连续稳定；第五条正确推论进入第六章。

第六章不建立新的行为系统：它从稳定首工实体与护理记录、既有关键干预证据、当前双室布局／环境／功能路径，以及冻结连续稳定窗口派生四条终章证据。稳定窗口只要求迁巢任务结束，允许护理、觅食和清洁继续可见。最后一条推论经过现有有序命令队列，在下一 Tick 写入 `final_report_generated_tick`、解锁冻结报告卡并记录 `FINAL_REPORT_GENERATED`；报告 Tick、完成 Tick、完成章节数和卡片必须一致，否则载入被拒绝。完成面板关闭状态仍只属于控制器会话，不写入模拟。

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

### `CampaignState` 与 `CampaignDirector`

`CampaignState` 是章节权威事实来源，归 `ColonyState` 所有。旧组合观察使用：

```text
FOUNDING_OBSERVATION
    → ENVIRONMENTAL_CARE
    → COMPLETED
```

它保存当前章节与状态、进入 Tick、完成章节数、错误推论次数、提示层级、完成 Tick，以及三个稳定 ID 集合：已收集证据、已确认推论、已解锁设施类型。初始工具包固定含试管巢和遮光套；第一章解锁微型喂食口，第二章解锁小型觅食盒。R4 只记录解锁，不创建 `FacilityState` 或摆放能力。

正式 Act 1 复用同一状态容器的证据、提示、推论与设施集合，但使用五个 `ACT1_*` 枚举章节，由 `Act1CampaignDirector` 解释。旧 `CampaignDirector` 只服务旧组合档案。

两个 Director 都是纯 `RefCounted` 协调器。`submit_campaign_inference_action(inference_id)` 只接受当前章节的三个显式选项之一；命令在下一 Tick 应用。错误选项增加累计错误次数和最高三级提示，不倒退章节或删除证据；正确选项确认推论、解锁固定工具包并推进章节或完成本轮。

章节不变量要求证据与观察卡完全对应，完成数、章节、状态、确认推论和设施集合彼此一致，完成 Tick 不越界。章节快照复制所有 ID 数组和派生可用／待处理状态；UI 不能写回。

### `HabitatZoneState`

每个区域保存稳定 `StringName zone_id`、限制在 0.0～1.0 的湿度、可达连接 ID 和可用状态。模拟只使用区域 ID 与逻辑连接，不包含坐标、尺寸或颜色。

### `AntModel`

所有非蚁后实体保持原有稳定 ID，保存生命周期字段、`zone_id` 和 `zone_entered_tick`。R5 幼虫额外保存当前蛋白支持的剩余成长 Tick；正式 Act 1 工蚁持有 `WorkerTaskModel`、`ForagingTaskModel`、`BroodFeedingTaskModel`、`WasteCleanupTaskModel`、`ScoutTaskModel` 与 `MigrationTaskModel`。幼体和食物源不保存反向预订或携带引用。

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

保存稳定实体 ID、逻辑区域 ID、食物类型、剩余份数和可用状态。当前类型为 `SUGAR_WATER` 与 `PROTEIN`；`ColonyState.remove_food_source()` 将目标转为 `available = false` 的守恒墓碑，而不是直接从数组擦除。这样 View 会隐藏目标，任务会清理预订，剩余份数仍可审计；直接擦除权威数组属于非法内部状态。

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

### `ColonyNutritionState`、`BroodFeedingTaskModel` 与 `NutritionSystem`

营养状态是群落储备的唯一事实来源，分别保存糖／蛋白储备、总供应、总消耗、蛋白放置／送达、糖活动余量和完成喂食次数。糖守恒为“来源剩余 + 携带 + 储备 + 已消耗 = 总供应”，蛋白使用同一公式。

喂食任务只有 `IDLE → MOVING_TO_BROOD → FEEDING` 三个状态，保存稳定目标幼虫 ID、逻辑路线和阶段 Tick。活跃任务隐式预订一份蛋白与一个幼虫；取消不消耗储备，完成时原子消耗一份蛋白并为目标幼虫添加冻结数量的成长支持。糖储备在存在活跃工蚁任务时按份转换为活动 Tick；储备为零时只按冻结间隔推进任务，因此减速但不会永久停摆。

### `ColonyWorkSystem`

`ColonyWorkSystem` 只服务具备冻结工作配置的场景，拥有三个明确状态机：

```text
Waste: MOVING_TO_WASTE → PICKING_UP → CARRYING_TO_TRAY → DROPPING
Scout: MOVING_TO_ZONE → OBSERVING → RETURNING
Migration: MOVING_TO_MEMBER → PICKING_UP → CARRYING_TO_ZONE → DROPPING
```

- 废物来源、垃圾托盘、侦察区域、迁移成员和目标巢室均按稳定 ID 排序选择。
- 废物任务在拾取时从来源污染中取得有限批次，放下时写入托盘；已携带批次遇到路径中断会等待，不会被删除。
- 动态区域初始 `discovered = false`。侦察完成观察阶段后原子标记发现；返回只影响工蚁区域，不重复发布发现事件。
- 迁巢候选必须已发现、可达、持续稳定、污染不过限，且相对蚁后当前巢室达到冻结最小改善。幼体按稳定 ID 先搬运，蚁后最后搬运。
- 已拾取成员的 `zone_id` 为空，由唯一 `MigrationTaskModel.carried_entity_id` 拥有；目标环境失效会将成员送回原区域，路径中断保留携带所有权并等待恢复。
- `submit_clean_waste_tray_action(facility_id)` 只携带稳定设施 ID；应用时重新验证托盘类型、容量和活动任务引用。UI 不提供权威清理量。

### `BroodRelocationSystem`、`ForagingSystem`、`NutritionSystem` 与 `ColonyWorkSystem`

`BroodRelocationSystem` 负责原有幼体适宜度、任务校验、推进、分配和所有权检查。`ForagingSystem` 负责稳定食物选择、路径校验、两类食物的觅食状态推进、份数守恒、结构化事件与原有糖水观察卡。`NutritionSystem` 负责活动节奏、喂食任务和营养不变量。`ColonyWorkSystem` 负责 R9 三类工作与蚁后／幼体迁巢所有权。四个系统都只读取纯模拟对象；同一工蚁不能同时执行育幼搬运、觅食、喂食、清理、侦察或迁巢。

### `ObservationEvent`

模拟在首工羽化、身份观察完成、幼体搬运、糖水发现、出发、采集、返程、分享、取消、各观察首次完成、推论确认／拒绝、章节完成和整局完成时追加结构化值对象。R6 追加遮光应用、蚁后护理完成与蛹观察完成事件；R9 追加废物任务开始／拾取／送达／清理、区域发现／侦察返回和迁巢开始／拾取／放下／完成事件。每条事件仍只包含：

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

R9 工作场景还必须满足：

- 一个工蚁最多有一个活跃任务；六类任务状态不能重叠。
- 一个废物来源批次和一个垃圾托盘容量同一时间最多由一个工作任务预订；来源、携带量和托盘量均有限非负。
- 被迁移的幼体或蚁后要么属于一个有效区域，要么恰好由一个迁移工蚁携带，不能同时属于两者或无主。
- 一个群落成员最多被一个迁移任务预订；蚁后只能在所有幼体到达迁巢目标后被选中。
- 未发现区域不能成为普通搬运、觅食、喂食或迁巢目标。
- 取消、回退、放下和清理后不残留目标、路线、预订或携带关系。

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
3. 按提交顺序应用并清空本 Tick 的继续／补水／糖／蛋白／遮光／章节推论／设施／清理托盘高层命令；清理只使用冻结规则和稳定设施 ID。
4. `EnvironmentSystem` 推进设施效果和污染传播。
5. `ColonyWorkSystem` 更新迁巢候选与稳定窗口。
6. 生命周期启用场景推进全部实体并让幼虫成长读取蛋白支持；旧组合场景改由 `ScenarioDirector` 只推进指定晚期蛹。
7. 依次校验育幼搬运、觅食、营养喂食与 R9 工作现有任务。
8. 启用营养的场景根据糖活动余量决定本 Tick 是否推进工蚁任务；其他场景每 Tick 推进。允许时依次推进育幼搬运、觅食、喂食和 R9 工作。
9. 先按稳定优先级分配 R9 废物／侦察／迁巢任务，再按场景门控分配湿度搬运、营养喂食和食物觅食；全部任务互斥。
10. 更新湿度观察稳定计数与解锁状态。
11. 旧组合场景由 `ScenarioDirector` 检查湿度／糖水完成条件并推进阶段。
12. 正式 Act 1 由 `FoundingCareSystem` 推进护理与相关证据。
13. 按场景使用 `CampaignDirector` 或 `Act1CampaignDirector` 收集证据并刷新章节状态。
14. 校验栖息地、发现状态、所有任务所有权、废物／糖／蛋白守恒、营养状态、Act 1／组合进度与章节不变量。
15. 每个成功 Tick 后，由控制器立即创建并交付一份新快照。

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
- `GameSnapshot.campaign: CampaignSnapshot`，保存六章状态、证据、确认推论、提示层级、设施工具包和推论命令可用／待处理状态
- `GameSnapshot.nutrition: NutritionSnapshot`，只在营养场景存在，保存两类储备／供应／消耗、短缺线索、活跃喂食数量和糖／蛋白动作的可用／待处理状态
- `GameSnapshot.act1: Act1Snapshot`，只在正式 Act 1 存在，保存遮光动作、蚁后护理、蛹观察、稳定首工 ID／羽化 Tick、工蚁护理证据、环境／终章稳定计数与冻结要求，以及最终报告 Tick／可用状态
- `GameSnapshot.layout: HabitatLayoutSnapshot`，保存稳定设施、逻辑槽位、方向、动态区域、派生连接、闸门、库存、合法放置选项和布局命令待处理状态
- `GameSnapshot.work: ColonyWorkSnapshot`，保存迁巢候选／目标、完成计数、三类活动任务数、可清理托盘 ID 和待处理清理目标

`sequence` 只在旧组合场景存在；`campaign` 同时用于旧组合和正式 Act 1；`nutrition` 同时用于营养基线和正式 Act 1。独立糖水场景继续使用其必要组成部分。M2 兼容路径仍保留 `ColonySnapshot.observation_events`。任何快照都不是命令入口，也不能写回模拟。

控制器在命令提交后可以创建同 Tick 新快照来展示待处理状态；只有成功推进到下一 Tick 后，快照中的权威湿度、阶段或食物源才反映命令效果。所有数组、事件和嵌套快照都重新创建或复制，修改快照不会改变 `ColonyState`。

## 10. 版本化存档核心

`SaveGameService` 只捕获最近一次成功固定 Tick 后的合法边界。`ColonySimulation` 在 Tick 执行期间拒绝捕获；保存不会暗中推进 Tick。Envelope 包含模拟 Tick、倍速、暂停、分别计数的 next IDs、按稳定 sequence 排序的待处理高层命令、权威状态和实际冻结配置。推论、布局、闸门和托盘命令只保存白名单允许的稳定逻辑 ID、槽位、方向或布尔意图；糖／蛋白／遮光等高层动作不保存效果量。

`SimulationStateCodec` 负责纯状态编码、从冻结值重建临时强类型 Resource、重建新的 `ColonyState`，以及运行稳定 ID、有限数值、区域图、任务进度、守恒、单一所有权和组合阶段不变量。加载不读取当前 `.tres`，不保存快照、View、Tween、会话名称或显示设置。只有 Envelope、配置哈希、迁移和全部不变量成功后才返回新会话。

磁盘写入只允许 `user://`：先在同目录写临时文件并完整回读验证，再把有效旧主档轮换为备份，最后提升新主档。读取按主档、备份、临时文件顺序寻找第一个完整候选。`ProfileStore` 固定管理一个主档案，把保存 Envelope、摘要、显式备份恢复和确认后的完整删除暴露给 `GameShellController`；它不取得模拟内部引用。

`GameShellController` 在新游戏时创建 `Act1TestTubeController`；继续时先读取恢复后快照的稳定 `scenario_id`，正式 Act 1 路由到新控制器，旧档路由到 `CombinedObservationController`。继续流程先在隔离对象中完成校验与重建，再用恢复的 `ColonySimulation + SimulationClock` 替换对应场景的空会话；失败不会改变当前档案或暴露半恢复状态。暂停菜单只向外壳请求保存，Envelope 仍由控制器在合法 Tick 边界创建。

`SettingsStore` 使用独立的 `user://settings.json`，只保存显示、音量、语言、UI 缩放和减少动效；它不进入 SaveEnvelope，不参与模拟 checksum，也不随档案删除。

当前 `r12.authority.v10` schema 与 `r11.authority.v9 → r12.authority.v10` 迁移见 `docs/architecture/SAVE_SCHEMA_R12.md`；R11、R10、R9、R8、R7、R6、R5、R4 与 R2 文档保留为历史基线。

## 11. 显示层

### 默认 Act 1 显示层

`Act1TestTubeView` 只读取完整 `GameSnapshot`：

- 程序化绘制试管玻璃、储水棉端、遮光套、管道、微型喂食口和糖液；坐标、尺寸与颜色只存在于 View。
- 维护稳定的 `entity_id -> AntView` 映射和独立的蚁后绘制。
- 首工从蛹转换为工蚁时沿用相同实体 ID，因此对已有 `AntView` 应用新阶段快照，不替换节点。
- 根据 `ForagingTaskSnapshot`、`BroodFeedingTaskSnapshot` 与三个 R9 工作任务快照的逻辑路线和进度计算工蚁位置；迁移成员跟随快照中的实际搬运者，蚁后位置由护理或迁巢快照决定，不使用与模拟脱节的 Tween。
- 相邻 Tick 间使用同一个 `SimulationClock` 的插值系数，暂停时冻结；同 Tick 快照只更新状态，不轮换插值端点。
- 减少动效启用时，蚁后待机摆动和 AntView 阶段脉冲停止，位置直接投影当前快照端点；模拟 Tick 和任务结果不变。
- 重复快照不创建重复节点；重开时 `reset_projection()` 清除旧端点、实体映射和临时选择。

`Act1TestTubeController` 从 `CampaignSnapshot` 投影章节、目标、证据、提示、推论按钮、设施工具包和最终结算；从 `Act1Snapshot`、`NutritionSnapshot`、`HabitatLayoutSnapshot` 与 `ColonyWorkSnapshot` 投影遮光、糖／蛋白动作、设施选择、闸门、护理和可清理托盘。清理按钮只把快照提供的稳定托盘 ID 提交给模拟；设施下拉栏也只组合已解锁库存和合法放置选项。UI 不能直接推进章节或修改群落状态。完成面板的“继续观察”只关闭应用层遮罩，后续 Tick 不会重新打开。

`FacilityLayoutView` 是 `Act1TestTubeView` 的独立子视图，只读取 `HabitatLayoutSnapshot`。它把逻辑槽位投影成网格、命中矩形、环境底色、连接状态和程序化设施轮廓，并把鼠标／键盘意图作为逻辑类型、槽位、方向或稳定设施 ID 交给控制器。湿度、光照、污染和垃圾容量只来自设施／区域快照；镜头 offset 与 zoom 是纯显示状态，拖动、WASD、滚轮、`+/-/0` 不创建命令、不推进 Tick，也不写入存档。

玩家可见文本通过 `localization/v0_2.csv` 导入简体中文与临时英文翻译资源。阶段说明、反馈和观察卡仍携带小型 `evidence_copy_role` 元数据：`observation_cue`、`action_affordance`、`neutral_placeholder`、`post_event_conclusion`、`system_status` 或 `error`。翻译只改变表现文字，不改变角色或权威状态；锁定卡只能使用中性占位，事件完成后才能切换为结论角色。场景测试检查键、角色和节点状态，不绑定完整中文句子。这是当前场景的应用文案边界，不是通用内容框架。

`scenes/app/game_shell.tscn` 是默认应用入口，提供标题、主档摘要、备份恢复、删除确认和设置页。档案摘要优先显示权威章节与完成状态。暂停菜单属于游戏场景的应用层遮罩，提供继续、保存、重开当前短章、返回标题和同一组设置。显示模式只经 `DisplayServer`，音量只经 `AudioServer`，翻译只经 `TranslationServer`，UI 缩放只经主题缩放应用；这些路径都没有模拟引用。

### 旧组合显示层

`CombinedHabitatView` 与 `CombinedObservationController` 保留原五阶段投影、会话身份和旧档恢复能力。外壳只在恢复对应 `scenario_id` 的旧档时进入该场景；新档案不会从 Act 1 自动跳回旧组合流程。

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

普通 UI 不显示精确湿度、任务枚举、目标 ID、生命周期倒计时或调试入口。F3 诊断层读取相同快照并显示精确内部状态，但组合场景只在 `OS.is_debug_build()` 为真时响应 F3；普通布局没有按钮或底部提示。Windows release 候选已实际确认 F3 无可见效果。

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

## 12. 保留的独立调试与验证入口

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

这些场景各自创建独立会话，不使用五阶段 `ScenarioDirector`，用于保留原有回归与人工验证能力。默认 `project.godot` 主场景是 `scenes/app/game_shell.tscn`；连续组合场景由外壳按需实例化。

## 13. 测试结构

`tests/test_runner.gd` 只聚合独立套件：

- `tests/core/simulation_clock_test_suite.gd`
- `tests/simulation/lifecycle_test_suite.gd`
- `tests/simulation/humidity_relocation_test_suite.gd`
- `tests/simulation/brood_relocation_equivalence_test_suite.gd`
- `tests/simulation/foraging_test_suite.gd`
- `tests/simulation/combined_observation_test_suite.gd`
- `tests/simulation/campaign_journal_test_suite.gd`
- `tests/simulation/nutrition_growth_test_suite.gd`
- `tests/simulation/act1_test_tube_test_suite.gd`
- `tests/simulation/act1_environment_chapters_test_suite.gd`
- `tests/simulation/act1_modular_migration_test_suite.gd`
- `tests/simulation/facility_layout_test_suite.gd`
- `tests/simulation/facility_environment_test_suite.gd`
- `tests/simulation/colony_work_test_suite.gd`
- `tests/simulation/observation_event_test_suite.gd`
- `tests/save/save_core_test_suite.gd`
- `tests/save/profile_store_test_suite.gd`
- `tests/session/player_annotation_state_test_suite.gd`
- `tests/view/view_adapter_test_suite.gd`
- `tests/view/habitat_view_interpolation_test_suite.gd`
- `tests/view/reduced_motion_test_suite.gd`
- `tests/view/worker_observation_panel_test_suite.gd`
- `tests/scenes/lifecycle_debug_scene_test_suite.gd`
- `tests/scenes/humidity_main_scene_test_suite.gd`
- `tests/scenes/worker_identity_scene_test_suite.gd`
- `tests/scenes/sugar_foraging_scene_test_suite.gd`
- `tests/scenes/combined_observation_scene_test_suite.gd`
- `tests/scenes/campaign_journal_scene_test_suite.gd`
- `tests/scenes/demo_shell_scene_test_suite.gd`
- `tests/scenes/game_shell_scene_test_suite.gd`
- `tests/scenes/act1_test_tube_scene_test_suite.gd`
- `tests/ui/demo_settings_state_test_suite.gd`
- `tests/ui/settings_store_test_suite.gd`
- `tests/ui/demo_localization_test_suite.gd`

生命周期边界从 Resource 计算。湿度套件覆盖原有命令、搬运、所有权、节奏和 soak；黄金套件锁定 `BroodRelocationSystem` 拆分前后等价。糖水与 R5 营养套件覆盖下一 Tick 命令、冻结配置、稳定选择、状态边界、守恒、快照隔离、三档速度、任务中存读和 10,000 Tick soak。组合与 R4 套件继续覆盖旧五阶段、稳定首工、章节证据和真实日志路径。R6 Act 1 套件覆盖护理、首工、营养、确定性和 10,000 Tick soak。R7 布局套件覆盖重叠／越界／接口／方向拒绝、稳定设施 ID、库存守恒、放置／旋转／拆除下一 Tick 语义、闸门缓存失效、旧邻接图等价和快照隔离；R8 环境套件覆盖强类型效果冻结、动态区域、派生连接、闸门、湿度／光照／污染传播、垃圾容量、食物站路由、幼体污染规避、确定性、R7→R8 迁移和 10,000 Tick soak；R9 工作套件覆盖清理命令、废物搬运、侦察发现、幼体／蚁后迁巢、环境失效回退、配置冻结、快照隔离、存读确定性和所有权 soak；R10 章节套件覆盖进度配置冻结、五项觅食区证据、四项环境证据、专用蛋白盘路由、旋转备用试管、闸门、稳定窗口和 R9→R10 迁移；R11 套件覆盖双室稳定 ID、逐室接口／环境、补水宿主、自主核心迁移、第五章证据、双室存读和 R10→R11 迁移；R12 套件覆盖终章配置冻结、四类证据、报告命令边界／事件／卡片、快照隔离、终章中途／完成存读、R11→R12 迁移和三档速度同 Tick 等价。场景套件继续用真实设施下拉栏、蛋白按钮、鼠标与键盘路径操作布局、镜头和清理工具，并用真实 UI 完成第五章设施路径及第六章报告／继续／返回路径；同时检查 1280×720／1920×1080、100%／150% UI 缩放。独立 `tests/performance/act1_144k_soak.gd` 在完整报告档案上推进 144,000 Tick、周期提交既有干预并在中点存读。测试入口先验证所有套件脚本可实例化，避免依赖脚本编译失败时产生假阳性退出码。存档套件覆盖任务中途、待处理高层命令、冻结配置、旧 schema 迁移、checksum、原子提交、备份恢复、故障注入和载入后 soak。

标准命令：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script 'res://tests/test_runner.gd'
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 30
```

自动测试不替代 1280×720、1920×1080、窗口和全屏的人工可读性检查。

## 14. 当前限制

- 所有物种、护理、营养和行为数值都是原型节奏参数，未经真实养蚁数据审校。
- 正式 Act 1 当前固定为三个初始区域、一个晚期蛹、两枚卵和有限设施库存；章节按唯一顺序推进，不支持分支。
- 自动路径验证了前两章完整闭环、第 3 章真实设施／蛋白操作和第 5～6 章真实双室设施／迁巢／报告操作；第 3～6 章的外部无讲解理解度与产品节奏尚未取得数据，架构不会通过无信息等待补足时长。
- 原有连续组合、生命周期、双室湿度和三区域糖水场景仍作为旧档／调试／验证入口；它们不会与正式 Act 1 共享状态。
- Act 1 第 2 章开放糖液，第 3 章开放蛋白与觅食／卫生设施，第 4 章开放备用试管、补水和连接组件；所有动作仍受章节快照门控。
- 临时英文尚未完成用户最终校对；7 名有效首次接触测试者数据未取得，外部理解度 Gate 未通过。用户已明确豁免该前置条件继续开发，但该决定不构成外部验证证据。
- 当前档案保存章节、证据、推论、提示、设施、连接、库存、环境值、区域发现、垃圾容量、工作任务和待处理布局／清理命令，但不会自动保存，也不含名称、选择、镜头位置或显示设置。
- 当前正式六章与完整档案结局已经实现；10 个外部完整档案的完成率与 180～240 分钟时长 Gate 尚无数据，保持 `INCOMPLETE`。
- 温度没有证明区别于湿度的独立观察闭环，因此不在当前环境模型中。
- 没有直接个体命令、随机行为、正式素材或外部插件。
