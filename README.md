# Colony Under Glass

《玻璃蚁国》的 Godot 4.7.1 可玩原型。默认入口是应用标题页；新档案进入正式 Act 1 的六章连续流程：观察单后护理与蛹，见证第一只工蚁羽化，通过微型喂食口完成首次营养交换，扩建觅食区并管理环境，接入双室模块巢让群落自主迁入，最后整理同一群落的长期记录并生成“玻璃观察报告”。旧档案仍按原场景恢复。

R14 已为正式六章主流程接入原创生产视觉：暖玻璃观察台标题背景、完整生命周期和蚁后轮廓、十二类设施／连接件、快照驱动的玻璃／凝水／基质表现、六章手册标记及结局报告印记。背景生成提示、SHA-256 和权利来源与代码内原创资产统一记录在 `docs/production/`；`sucai/` 不进入生产引用或发行素材。

R15 增加项目自有的低干扰玻璃观察氛围和八个有限反馈音，分别覆盖界面、遮光、补水、设施、闸门、手册、章节与报告。主音量、环境氛围和操作反馈可以独立调整；音频只强化已有画面与文字，不承担唯一信息。简体中文与英文玩家文案已完成本轮逐条校对和格式占位检查。

R16 Windows v1.0 Beta 技术候选已经冻结：标题页现有双语“制作名单与隐私”入口；发行资料包含项目 Credits、离线隐私说明、Beta 发布说明，以及从精确 Godot 4.7.1 二进制导出的完整引擎／第三方许可。最大规模验证覆盖 80 只工蚁、180 个幼体、48 项设施和 36 个逻辑区域；权威模拟保留全部实体，画面按稳定 ID 优先显示活动个体并将同时存在的蚂蚁视觉节点限制在 240 个。40,381 项回归、144,000 Tick 完整档案、300,000 Tick 最大规模、干净 Windows 流程和最终显示矩阵的证据见 `docs/validation/v1_r16_beta_candidate_001.md`。

R17 为后续完整档案试玩补上本机有效时长证据：档案在“开始观察”后按真实聚焦时间累计总时长和章节拆分，暂停阅读计入，标题／准备门与失焦时间排除；首次结局时长只记录一次。档案页同时显示有效观察、当前章节、首次结局和受倍速影响的模拟历程。旧档不会猜测历史时长，而会明确标记“自本版本起”。

## 当前功能

- 新档案进入 `scenes/main/act1_test_tube.tscn`；场景始终使用同一个 0.1 秒固定 Tick 时钟和同一份权威群落状态。
- 第 1 章从 1 只蚁后、2 枚卵和 1 个晚期蛹开始。玩家先应用遮光套，再从蚁后的确定性护理循环和蛹状态收集证据。
- 蚁后护理只包含休息、靠近幼体和护理三个显式状态；行为与进度来自 `Act1Snapshot`，View 不持有模拟模型。
- 玩家在观察手册中提交推论；错误选项只递进提示，正确推论在下一 Tick 生效并解锁微型喂食口。
- 晚期蛹羽化后保持同一个稳定实体 ID 和同一个 `AntView`，成为第一只工蚁并进入第 2 章。
- 第 2 章允许通过高层命令放置一份糖液。工蚁自主发现、采集、返巢、分享并参与育幼；玩家不能指定执行者。
- 首次工蚁出现、工蚁育幼和首次营养交换成为权威证据。正确记录第二条推论后进入第 3 章并解锁小型觅食盒、糖液台、蛋白盘和垃圾托盘。
- 第 3 章把侦察、糖类循环、蛋白育幼、托盘清理和三工蚁规模作为五条权威证据；正确推论后进入环境管理。
- 第 4 章解锁可旋转的备用试管、补水模块、直管／弯管／闸门。备用试管必须与现有网络接通；群落在已发现、明显更舒适且污染更低的区域间自主迁移。
- 补水响应、污染规避、部分迁移和连续稳定窗口形成第 4 章证据；第四条正确推论解锁双室模块巢并进入第 5 章。
- 第 5 章要求连接双室巢、为育幼室补水并保留可达的喂食／废物路径。工蚁先侦察两室，再按稳定实体 ID 搬迁幼体，最后迁入蚁后；第五条正确推论进入稳定群落总结。
- 第 6 章从首工历史、关键干预、最终布局与连续稳定行为收集权威证据。最后一条正确推论在下一 Tick 生成持久观察卡和结构化报告事件，完成六章档案；结局面板可继续自由观察，或保存后返回标题建立新档案。
- `HabitatLayoutState` 现在是设施实例、设施库存和区域连接的唯一权威来源；`HabitatZoneState` 保存湿度、光照、污染与可用状态。
- Act 1 模块布局使用 12×8 逻辑槽位和冻结设施接口。放置、旋转、拆除与闸门开关都是下一 Tick 生效的高层命令；屏幕坐标不进入模拟。
- 布局视图支持鼠标与键盘：默认 `L` 切换布局，`P` 开始放置，方向键移动预览，`Enter` 确认，`R` 旋转，`Delete` 拆除，`Tab` 选择设施，WASD／拖动平移，滚轮或 `+`／`-` 缩放，`0` 重置镜头。合法／非法预览同时使用颜色、勾／叉和文字，不依赖单一颜色。
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
- 标题页提供新游戏、继续、档案、设置、制作名单与隐私和退出；一个主档案支持显式保存、完整备份、损坏回退和确认删除。档案摘要显示不受倍速影响的有效观察总时长、当前章节时长、首次结局时长和模拟历程。
- 设置独立保存到 `user://settings.json`，包括主音量、环境氛围音量、操作与反馈音量、分辨率、窗口模式、UI 缩放、简体中文／英文、减少动效，以及帮助、观察手册和模块布局三个可重映射快捷键。v1／v2 旧设置文件会安全迁移并获得默认分音量与 `F1`／`J`／`L`。
- 权威存档 schema 为 `r12.authority.v10`，外层 `SaveEnvelope` 格式为 v2。旧 R11／R10／R9／R8／R7／R6／R5／R4／R2 档案沿显式单向迁移链恢复；格式 v1 档案会获得带历史缺口标记的零起点计时，不伪造过去时长。已完成 R11 五章的 Act 1 档案会恢复为第 6 章且不会伪造最终报告，旧组合观察档案仍路由到原 `CombinedObservationController`。
- R5 的糖／蛋白守恒、糖短缺减速、育幼喂食和资源约束生命周期继续作为权威基础。第 3 章开放无参数蛋白补给动作；安装专用糖液台或蛋白盘后，高层动作优先路由到该设施所属区域。
- 旧的连续组合观察、双室湿度、独立糖水和生命周期场景仍保留，用于旧档恢复、回归与调试；新档案只进入具有 R14 生产视觉和 R15 音频的正式 Act 1。

当前所有物种、湿度和行为参数都是 `prototype_pacing_fixture`，未经科学验证。影响当前连续体验的配置事实来源包括：

- `data/species/species_a.tres`
- `data/habitats/act1_test_tube.tres`
- `data/behaviors/founding_care_prototype.tres`
- `data/behaviors/act1_nutrition_prototype.tres`
- `data/behaviors/act1_environment_prototype.tres`
- `data/behaviors/colony_work_prototype.tres`
- `data/behaviors/act1_progression_prototype.tres`
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
- 第二条推论后打开“模块布局”，从冻结库存选择小型觅食盒、糖液台、蛋白盘和垃圾托盘。鼠标点击有效槽位或用键盘移动预览并按 `Enter`；提交当下只显示待处理，下一固定 Tick 才创建设施。
- 使用糖液和蛋白按钮提供补给，观察工蚁侦察新区域、往返取食、喂养幼体和搬运废物；托盘可清理时使用清理按钮。
- 第三条推论后布置闸门与旋转后的备用试管，并在备用试管上叠放补水模块。闸门按钮只对当前选中的闸门连接显示，开关同样在下一 Tick 应用。
- 观察群落避开污染区域并完成部分迁移；环境连续稳定后记录第四条推论，进入模块化迁巢。
- 用连接门接入双室模块巢，在育幼室叠放补水模块，并保留通往喂食区和废物盘的可达路径。工蚁会自行侦察、先搬幼体再迁入蚁后；核心迁移稳定后记录第五条推论。
- 在第 6 章回顾首工、设施与干预记录，保持最终布局稳定并记录最后结论。“玻璃观察报告”出现后可继续自由观察，或保存档案并返回标题；关闭后不会在下一 Tick 重复弹出。
- 默认按 `F1` 打开操作帮助、`J` 打开观察手册、`L` 切换模块布局；可在标题页“设置 → 键盘与快捷键”修改。帮助面板打开时暂停模拟和插值，关闭后恢复此前状态与键盘焦点。
- 在布局视图中可用鼠标拖动／滚轮，或 WASD／`+`／`-`／`0` 操作镜头；这些操作不会推进 Tick 或改变模拟结果。
- 开始后可使用“菜单”、`1×`、`4×`、`16×` 控制节奏；按 `Esc` 打开暂停菜单可保存、返回标题或重新开始。
- F3 只用于开发诊断。减少动效会关闭蚁后摆动、阶段脉冲和位置帧间插值，但不改变模拟。

主视图只提供护理、个体变化和资源交换线索，不让玩家直接命令蚂蚁。

## 测试

`tests/test_runner.gd` 是唯一顶层回归入口，先验证每个测试套件可实例化，再聚合固定时钟、生命周期、湿度搬运、糖水觅食、营养守恒、育幼喂食、Act 1 蚁后护理、设施占位／接口／方向／库存、动态区域、闸门与派生连接、冻结环境效果、湿度／光照／污染传播、垃圾容量、六章证据与推论、最终报告、双室权威、自主核心迁移、真实 UI 补给与布局路径、稳定 View 映射、版本化存档、R11→R12 与更早旧档迁移、档案有效时长与 v1→v2 外层迁移、档案与备份、暂停、帮助焦点、快捷键与三路音量持久化／旧设置迁移、非纯色布局反馈、生产资产与音频哈希／台账／设施样式覆盖、两档 UI 缩放、减少动效和双语格式质量测试：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --headless `
  --path . `
  --script 'res://tests/test_runner.gd'
```

独立 144,000 Tick 完整档案长时验证（含中点存读）：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --headless `
  --path . `
  --script 'res://tests/performance/act1_144k_soak.gd'
```

独立 300,000 Tick 最大规模验证：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --headless `
  --path . `
  --script 'res://tests/performance/act1_300k_max_scale_soak.gd'
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
  --script 'res://tools/release/generate_godot_notices.gd'
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --headless `
  --path . `
  --export-release 'Windows Desktop' `
  'builds/windows/ColonyUnderGlass_v1.0_beta.exe'
```

`builds/` 已忽略，不进入版本控制。内部参考、测试和确定性音频生成器均从发行包排除；最终 WAV 资源会进入构建。便携发行目录还必须附带 `CREDITS.md`、`PRIVACY.md`、`RELEASE_NOTES_V1_0_BETA.md` 和 `docs/production/GODOT_COPYRIGHT.txt` 的读者副本；具体命名、哈希、干净 Windows 流程与显示矩阵见 `docs/release/V1_0_BETA_DISTRIBUTION_CHECKLIST.md`。

## 当前限制

- 当前自动真实 UI 路径验证了前两章完整因果闭环、第 3 章设施／蛋白操作，以及第 5～6 章连接门、双室巢、补水、废物路径、自主迁巢、终章推论、报告和继续／返回路径；第 3～6 章的产品节奏仍未由外部玩家证明，不会通过无信息等待填充时长。
- v0.2 计划要求的 7 名有效首次接触测试者数据尚未取得，外部理解度 Gate 保持 `INCOMPLETE`。用户于 2026-07-28 明确豁免它作为继续开发的前置条件；这不等于通过。
- 最终美术、音频、文本与无障碍版本仍缺少 R16 要求的 10 个首次完整档案，因此 3～4 小时中位时长、完成率和最终理解度 Gate 同样保持 `INCOMPLETE`；本机自动化和窗口验证不能替代这些外部数据。
- 新建档案现可持续记录有效墙钟时长和章节拆分，供未来冻结试玩直接导出证据；现有旧档只能从 R17 起累计并带历史缺口标记。计时能力本身不等于 180～240 分钟 Gate 已通过。
- R16 已冻结的 Beta ZIP 来自 R17 之前的提交，不包含本轮计时界面；用于后续完整档案外测前必须从 R17 已验证提交重新导出并冻结新哈希。
- 正式 Act 1 已覆盖单后护理、第一工蚁、首次糖液、小型觅食区、蛋白育幼、废物清理、环境管理、完整核心迁巢和稳定群落总结，共六章并具有明确档案结局。
- 温度没有区别于湿度的独立闭环证据，继续延期。
- 工蚁名称和个人行动记录仍属于旧组合观察的会话注释；显示设置独立跨程序保存。
- 物种与节奏参数均未经科学审校；本轮文本终校不构成物种级科学审校。
- 正式原创视觉与音频已经登记；仍未加入 Steam、第三方插件或商店发布授权。

v0.1 发布基线见 `docs/validation/v0.1_baseline_001.md`；M2 身份验证见 `docs/validation/worker_identity_001.md`；M3 糖水验证见 `docs/validation/sugar_foraging_001.md`；M4 连续体验验证见 `docs/validation/v0_2_combined_001.md`；R0-A／R0-B 与 M5 记录位于 `docs/validation/`；R1～R15 的技术验证分别见同目录的 `v1_r1_…` 至 `v1_r15_…` 记录；R16 最终性能、Windows 包、显示矩阵与哈希见 `docs/validation/v1_r16_beta_candidate_001.md`；R17 有效时长与存档迁移见 `docs/validation/v1_r17_playtime_evidence_001.md`。

3～4 小时完整独立游戏的章节、设施、音画、验证与发行路线见 `CODEX_V1_MASTER_PLAN.md`；当前权威存档 schema 见 `docs/architecture/SAVE_SCHEMA_R12.md`，外层有效时长格式见 `docs/architecture/SAVE_ENVELOPE_V2.md`，R11／R10／R9／R8／R7／R6／R5／R4／R2 文档保留为历史基线。计划状态不替代外部玩家证据；当前可运行事实仍以本 README、`GDD.md` 和 `ARCHITECTURE.md` 为准。

开始修改前请阅读 `AGENTS.md`、`GDD.md` 和 `ARCHITECTURE.md`。`sucai/` 仅作内部观察参考，授权确认前不得作为发行素材。
