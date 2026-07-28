# Colony Under Glass

《玻璃蚁国》的 Godot 4.7.1 可玩原型。默认入口是应用标题页；新档案进入正式 Act 1 试管阶段的前两章：观察单后护理与蛹，记录推论，见证第一只工蚁羽化，再通过微型喂食口提供糖液并观察自主取食、分享与育幼。完成两章后可进入模块布局视图，使用逻辑槽位布置首个小型觅食盒。旧档案仍按原场景恢复。

## 当前功能

- 新档案进入 `scenes/main/act1_test_tube.tscn`；场景始终使用同一个 0.1 秒固定 Tick 时钟和同一份权威群落状态。
- 第 1 章从 1 只蚁后、2 枚卵和 1 个晚期蛹开始。玩家先应用遮光套，再从蚁后的确定性护理循环和蛹状态收集证据。
- 蚁后护理只包含休息、靠近幼体和护理三个显式状态；行为与进度来自 `Act1Snapshot`，View 不持有模拟模型。
- 玩家在观察手册中提交推论；错误选项只递进提示，正确推论在下一 Tick 生效并解锁微型喂食口。
- 晚期蛹羽化后保持同一个稳定实体 ID 和同一个 `AntView`，成为第一只工蚁并进入第 2 章。
- 第 2 章允许通过高层命令放置一份糖液。工蚁自主发现、采集、返巢、分享并参与育幼；玩家不能指定执行者。
- 首次工蚁出现、工蚁育幼和首次营养交换成为权威证据。正确记录第二条推论后解锁小型觅食盒并完成当前 Act 1 候选内容。
- `HabitatLayoutState` 现在是设施实例、设施库存和区域连接的唯一权威来源；`HabitatZoneState` 保存湿度、光照、污染与可用状态。
- Act 1 模块布局使用 12×8 逻辑槽位和冻结设施接口。放置、旋转、拆除与闸门开关都是下一 Tick 生效的高层命令；屏幕坐标不进入模拟。
- 布局视图支持鼠标与键盘：`L` 切换布局，`P` 开始放置，方向键移动预览，`Enter` 确认，`R` 旋转，`Delete` 拆除，`Tab` 选择设施，WASD／拖动平移，滚轮或 `+`／`-` 缩放，`0` 重置镜头。
- 遮光套不再是布局之外的重复状态：高层遮光动作在同一 Tick 同时创建稳定 `FacilityState`、消耗冻结库存并启用蚁后护理。
- R8 为巢室、补水、糖液／蛋白站、垃圾托盘、连接与遮光定义冻结强类型效果；不使用通用效果字典。
- `EnvironmentSystem` 在命令之后、生命周期和任务之前推进湿度、光照、污染产生／传播与垃圾收集。新增巢室使用稳定动态区域 ID，连接与闸门决定可达关系。
- R9 使用三个专用确定性任务处理废物批次搬运、新区域往返侦察和群落迁移；幼体按稳定 ID 先迁移，蚁后最后迁入，不使用行为树或 ECS。
- 垃圾托盘可清理时，工具栏显示清理按钮；按钮只提交稳定设施 ID，权威清理在下一固定 Tick 应用。
- 布局视图以区域底色、污染颗粒、垃圾容量和开关线条投影环境快照；精确环境数值只显示在开发 F3 层。
- 遮光与糖液操作都先进入命令队列，在下一连续固定 Tick 开始时按启动时冻结的配置应用。
- `GameSnapshot` 分离群落、营养、章节与 `Act1Snapshot`；UI 和 `Act1TestTubeView` 只读取快照。
- 启动与重开都先进入 Tick 0 准备门；门内固定 1×并冻结时钟、插值和视觉。点击“开始观察”只释放应用层时钟。
- 普通视图不显示内部任务枚举、目标 ID、生命周期倒计时或调试入口；开发环境仍可按 F3 打开诊断层。
- 支持暂停、1×、4×、16×；倍速只改变现实时间内处理的 Tick 数，不改变单 Tick 语义。`Esc` 或“菜单”打开暂停菜单。
- 标题页提供新游戏、继续、档案、设置和退出；一个主档案支持显式保存、完整备份、损坏回退和确认删除。
- 设置独立保存到 `user://settings.json`，包括主音量、分辨率、窗口模式、UI 缩放、简体中文／临时英文和减少动效。
- 存档 schema 为 `r9.authority.v7`。旧 R8／R7／R6／R5／R4／R2 档案沿显式单向迁移链恢复；R8 档案会获得冻结工作配置、区域发现状态、迁巢状态与空闲任务，旧组合观察档案仍路由到原 `CombinedObservationController`。
- R5 的糖／蛋白守恒、糖短缺减速、育幼喂食和资源约束生命周期继续作为权威基础与回归覆盖；Act 1 当前只开放糖液操作，蛋白放置留给后续章节。
- 旧的连续组合观察、双室湿度、独立糖水和生命周期场景仍保留，用于旧档恢复、回归与调试。

当前所有物种、湿度和行为参数都是 `prototype_pacing_fixture`，未经科学验证。影响当前连续体验的配置事实来源包括：

- `data/species/species_a.tres`
- `data/habitats/act1_test_tube.tres`
- `data/behaviors/founding_care_prototype.tres`
- `data/behaviors/act1_nutrition_prototype.tres`
- `data/behaviors/act1_environment_prototype.tres`
- `data/behaviors/colony_work_prototype.tres`
- `data/facilities/act1_layout_catalog.tres`
- `data/habitats/combined_observation_slice.tres`
- `data/habitats/combined_observation_sequence.tres`
- `data/behaviors/sugar_foraging_prototype.tres`
- `data/habitats/colony_growth_nutrition.tres`
- `data/behaviors/nutrition_growth_prototype.tres`

旧独立场景继续使用各自的 `.tres` 配置。测试从 Resource 计算节奏边界，不在生产代码或文档中复制生命周期 Tick。

## 运行

在仓库根目录打开编辑器：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --editor --path .
```

运行默认应用外壳：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --path .
```

直接运行正式 Act 1 场景或保留场景：

```powershell
# 正式 Act 1 试管阶段
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --path . `
  --scene 'res://scenes/main/act1_test_tube.tscn'

# 旧连续组合观察
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --path . `
  --scene 'res://scenes/main/combined_observation.tscn'

# 双室湿度切片
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --path . `
  --scene 'res://scenes/main/main.tscn'

# 独立糖水切片
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --path . `
  --scene 'res://scenes/foraging/sugar_foraging.tscn'

# 完整生命周期调试
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --path . `
  --scene 'res://scenes/debug/lifecycle_debug.tscn'
```

## 操作

### 默认 Act 1 观察

- 在标题页创建新游戏，或继续一个已验证的主档案；“档案”页可查看摘要、恢复备份或确认删除。
- 在准备门阅读目标后点击“开始观察”，然后应用遮光套。
- 观察蚁后靠近幼体、护理与休息的循环，同时观察晚期蛹；证据齐全后打开手册记录第一条推论。
- 进入第 2 章后观察同一个体从蛹变为第一只工蚁；微型喂食口开放时提供一份糖液。
- 等待工蚁自主完成取食、分享和育幼；证据齐全后在手册记录第二条推论。
- 完成面板出现后可继续自由观察；关闭后不会在下一 Tick 重复弹出。
- 完成后打开“模块布局”，从冻结库存选择小型觅食盒。鼠标点击有效槽位或用键盘移动预览并按 `Enter`；提交当下只显示待处理，下一固定 Tick 才创建设施。
- 在布局视图中可用鼠标拖动／滚轮，或 WASD／`+`／`-`／`0` 操作镜头；这些操作不会推进 Tick 或改变模拟结果。
- 开始后可使用“菜单”、`1×`、`4×`、`16×` 控制节奏；按 `Esc` 打开暂停菜单可保存、返回标题或重新开始。
- F3 只用于开发诊断。减少动效会关闭蚁后摆动、阶段脉冲和位置帧间插值，但不改变模拟。

主视图只提供护理、个体变化和资源交换线索，不让玩家直接命令蚂蚁。

## 测试

`tests/test_runner.gd` 是唯一顶层入口，先验证每个测试套件可实例化，再聚合固定时钟、生命周期、湿度搬运、糖水觅食、营养守恒、育幼喂食、Act 1 蚁后护理、设施占位／接口／方向／库存、动态区域、闸门与派生连接、冻结环境效果、湿度／光照／污染传播、垃圾容量、两章证据与推论、真实 UI 通关、鼠标与键盘布局路径、稳定 View 映射、版本化存档、旧邻接与旧档迁移、档案与备份、暂停、两档 UI 缩放、减少动效和翻译资源测试：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --headless `
  --path . `
  --script 'res://tests/test_runner.gd'
```

脚本解析和默认主场景冒烟：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 30
```

## Windows 导出

仓库中的 `export_presets.cfg` 配置 Windows Desktop x86_64 release，并排除内部参考目录与测试。安装精确匹配 Godot `4.7.1.stable` 的官方 Windows Export Templates 后可运行：

```powershell
New-Item -ItemType Directory -Force -Path '.\builds\windows'
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --headless `
  --path . `
  --export-release 'Windows Desktop' `
  'builds/windows/ColonyUnderGlass_v0.2_demo.exe'
```

`builds/` 已忽略，不进入版本控制。

## 当前限制

- 当前 R6 自动真实 UI 路径验证了两章因果闭环，但仍是压缩候选，尚未用 5～7 名新玩家证明 35～60 分钟目标；不会通过无信息等待填充时长。
- v0.2 计划要求的 7 名有效首次接触测试者数据尚未取得，外部理解度 Gate 保持 `INCOMPLETE`。用户于 2026-07-28 明确豁免它作为继续开发的前置条件；这不等于通过。
- 正式 Act 1 目前覆盖单后护理、第一工蚁、首次糖液照护和基础模块布局；R8 环境效果与 R9 工作任务已经作为权威基础实现，但蛋白、补水、垃圾设施及完整清理／侦察／迁巢流程尚未编排进正式章节，后四章也未实现。
- 温度没有区别于湿度的独立闭环证据，继续延期。
- 工蚁名称和个人行动记录仍属于旧组合观察的会话注释；显示设置独立跨程序保存。
- 物种与节奏参数均未经科学审校；临时英文尚未完成人工终校。
- 尚无正式素材、音频、Steam、第三方插件或发布授权。

v0.1 发布基线见 `docs/validation/v0.1_baseline_001.md`；M2 身份验证见 `docs/validation/worker_identity_001.md`；M3 糖水验证见 `docs/validation/sugar_foraging_001.md`；M4 连续体验验证见 `docs/validation/v0_2_combined_001.md`；R0-A／R0-B 与 M5 记录位于 `docs/validation/`；R1～R6 分别见同目录的 `v1_r1_…` 至 `v1_r6_…`；R7～R9 分别见同目录的 `v1_r7_…`、`v1_r8_…` 与 `v1_r9_…` 验证记录。

未来 3～4 小时完整独立游戏的章节、设施、音画、验证与发行路线见 `CODEX_V1_MASTER_PLAN.md`；当前存档 schema 见 `docs/architecture/SAVE_SCHEMA_R9.md`，R8／R7／R6／R5／R4／R2 文档保留为历史基线。这些计划不表示未来能力已经实现；当前可运行事实仍以本 README、`GDD.md` 和 `ARCHITECTURE.md` 为准。

开始修改前请阅读 `AGENTS.md`、`GDD.md` 和 `ARCHITECTURE.md`。`sucai/` 仅作内部观察参考，授权确认前不得作为发行素材。
