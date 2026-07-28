# Colony Under Glass

《玻璃蚁国》的 Godot 4.7.1 灰盒。默认入口是应用标题页；玩家可创建一个主档案、继续或恢复备份，再进入连续观察：见证第一只工蚁羽化，通过补水观察幼体搬运，放置糖水观察自主觅食，并在观察手册中根据证据完成两次推论。

## 当前功能

- 默认场景使用同一份权威群落状态和同一个 0.1 秒固定 Tick 时钟连续推进五个阶段：建群序幕、认识个体、湿度观察、糖水觅食、观察总结。
- 第一只工蚁以晚期蛹开始；羽化后保持同一个稳定实体 ID 和同一个 `AntView`，继续参与幼体搬运和糖水觅食。
- 玩家可以点击工蚁持续观察，并为当前会话中的个体设置可选名称；选择和名称不改变模拟快照。
- 补水、继续观察和放置糖水都是无参数高层命令，在下一连续固定 Tick 开始时按冻结配置应用。
- 幼体搬运使用确定性的五状态行为；预订、区域归属和携带关系始终保持单一所有权。
- 糖水觅食使用确定性的发现、移动、采集、返巢和分享流程；玩家不能指定执行者。
- `ScenarioDirector` 只编排这五个固定阶段，不是通用关卡脚本系统；阶段转换属于权威模拟状态。
- `CampaignDirector` 在同一演示流程上提供两个显式短章：收集首工／环境证据、等待玩家推论、分级提示、确认结论并解锁固定设施工具包；它不是通用任务 DSL。
- 错误推论不会惩罚档案或倒退进度，只会提高当前短章的提示层级；正确推论仍通过下一 Tick 生效的高层命令确认。
- `GameSnapshot` 分离群落、场景工具、观察记录、连续阶段和章节手册；UI 与 View 只读取快照。
- 启动与重开都先进入 Tick 0 准备门；门内固定 1×，时钟、插值与视觉冻结，点击“开始观察”只释放应用层时钟。
- 未解锁观察卡只显示中性占位；事件完成后才显示结论。身份提示只提供观察线索，不要求玩家点击或命名首工。
- 普通视图不显示精确湿度、内部任务枚举、目标 ID、生命周期倒计时或调试入口；编辑器与开发调试构建仍可按 F3 打开诊断层。
- 支持暂停、1×、4×、16×；倍速只改变现实时间内处理的 Tick 数，不改变单 Tick 语义。标题栏“菜单”或 `Esc` 打开暂停菜单，可继续、保存、重新开始当前短章或返回标题。
- 默认标题页提供新游戏、继续、档案、设置和退出；档案页显示当前阶段、模拟时间、最近观察和保存时间。
- 一个主档案通过暂停菜单显式保存；“保存并返回标题”也会先保存。暂停、倍速、任务中状态、冻结配置和待处理命令都按合法固定 Tick 边界恢复。
- 第二次保存会保留上一个完整备份；主档损坏时“继续”可回退到备份，档案页也提供显式恢复。新游戏覆盖和删除档案均需二次确认。
- 设置独立保存到 `user://settings.json`，包括主音量、1280×720／1920×1080、窗口／全屏、100%／125%／150% UI 缩放、简体中文／临时英文和减少动效；设置不进入权威游戏档案。
- 完成后可立即重新开始；重开会清除旧命令、阶段、资源、观察卡、名称、选择、事件游标和视觉映射，并返回 Tick 0 准备门。
- R4 把章节、证据、推论、提示和设施解锁写入权威档案，并建立 `r4.authority.v2` 历史 schema。
- R5 增加独立的营养成长模拟基线：糖类储备支持工蚁活动，短缺时确定性减速而非停摆；蛋白由工蚁搬回群落储备，再通过专用育幼任务支持幼虫阶段成长。该抽象不是现实饲养剂量建议。
- 营养成长场景启用栖息地内完整生命周期、稳定实体 ID、糖／蛋白分别守恒和三类工蚁任务互斥；它目前由快照与自动测试验证，尚未接入默认玩家章节或设施 UI。
- 当前存档 schema 为 `r5.authority.v3`；R4 状态、R2 两个旧 schema 和固定旧档夹具沿显式单向链迁移，营养配置与任务状态随会话冻结和恢复。
- 旧的双室湿度切片、独立糖水切片和完整生命周期试管场景仍可单独启动，用于回归与调试。

当前所有物种、湿度和行为参数都是 `prototype_pacing_fixture`，未经科学验证。影响当前连续体验的配置事实来源包括：

- `data/species/species_a.tres`
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

运行保留场景：

```powershell
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

### 默认连续观察

- 在标题页创建新游戏，或继续一个已验证的主档案；“档案”页可查看摘要、恢复备份或确认删除。
- 在准备门阅读画面后点击“开始观察”。
- 观察晚期蛹与之后出现的个体；若玩家自行选择工蚁，可为本局设置可选名称。
- 首工证据出现后打开“观察手册”，比较证据并记录第一条推论；错误选择会给出递进提示，不会丢失进度。
- 点击“继续观察环境”进入湿度阶段。
- 先观察第一次幼体搬运；补水开放后分三次给育幼室少量补水。
- 湿度观察卡解锁后，点击“准备放置糖水”，再点击右侧觅食区。
- 三张观察卡完成后再次打开观察手册，记录环境推论并完成本轮；结算后可重新开始。
- 开始后可使用“菜单”、`1×`、`4×`、`16×` 控制节奏；按 `Esc` 打开暂停菜单可保存、返回标题或修改完整设置。
- 标题页、档案页和设置页支持键盘焦点与 `Esc` 返回；减少动效会关闭蚁后待机摆动、阶段脉冲和位置帧间插值。
- F3 仅供编辑器与开发调试构建诊断；Windows release 候选不会显示诊断层。

主视图给出环境和行为线索，但不会直接提示“湿度过低”，也不会让玩家直接命令某只工蚁。

## 测试

`tests/test_runner.gd` 是唯一顶层入口，先验证每个测试套件可实例化，再聚合固定时钟、生命周期、湿度搬运、糖水觅食、糖／蛋白守恒、育幼喂食、资源约束成长、连续场景编排、章节手册、推论命令、设施解锁、结构化事件、版本化存档、档案与备份、独立设置、会话注释、快照隔离、View 映射、真实 UI 存取档路径、暂停菜单、减少动效和翻译资源测试：

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

- 当前冻结节奏的无停顿自动流程在 Tick 586，即 58.6 模拟秒完成；它已验证连续因果链，但尚未达到 v0.2 计划中的 12～15 分钟外部试玩目标。不会用无信息等待填充时长。
- v0.2 计划要求的 7 名有效首次接触测试者数据尚未取得，因此外部理解度 Gate 没有通过。用户于 2026-07-28 明确决定豁免该前置条件并继续 M5；这不是测试结果，也不能作为外部可理解性证据。
- 连续场景只受控推进一只晚期蛹；完整卵、幼虫、蛹、工蚁生命周期仍只在独立调试场景运行。
- 工蚁名称、选择和个人行动记录仍是会话注释，不进入权威游戏档案；显示设置会独立跨程序保存。
- 当前默认主档保存连续观察和两章演示手册；R5 营养权威状态也已经可以独立存读，但尚未接入默认档案的玩家章节。设施仅以稳定类型 ID 解锁并显示在手册中，尚不能摆放或产生权威环境效果；正式六章内容仍未实现。
- 尚无蛋白质、饥饿、能量、资源经济、多食物点、自由地图、设施建造、镜头跟随、Steam、正式素材、音频或第三方插件。

v0.1 发布基线见 `docs/validation/v0.1_baseline_001.md`；M2 身份验证见 `docs/validation/worker_identity_001.md`；M3 糖水验证见 `docs/validation/sugar_foraging_001.md`；M4 连续体验验证见 `docs/validation/v0_2_combined_001.md`；R0-A 证据有效性修正见 `docs/validation/v0_2_m4_evidence_validity_001.md`；R0-B 冻结外测候选见 `docs/validation/v0_2_m4_evidence_candidate_001.md`；M5 演示候选见 `docs/validation/v0_2_m5_demo_candidate_001.md`；R1 规格锁定见 `docs/validation/v1_r1_production_spec_001.md`；R2 存档核心见 `docs/validation/v1_r2_save_core_001.md`；R3 档案与设置见 `docs/validation/v1_r3_profile_shell_001.md`；R4 章节与手册见 `docs/validation/v1_r4_campaign_journal_001.md`；R5 营养成长见 `docs/validation/v1_r5_nutrition_growth_001.md`。

未来 3～4 小时完整独立游戏的章节、档案、设施、UI、音画、验证与发行路线见 `CODEX_V1_MASTER_PLAN.md`；R1 生产规格索引见 `docs/V1_PRODUCTION_SPEC_INDEX.md`，当前存档 schema 见 `docs/architecture/SAVE_SCHEMA_R5.md`，R4／R2 历史基线分别见 `docs/architecture/SAVE_SCHEMA_R4.md` 与 `docs/architecture/SAVE_SCHEMA_R2.md`。这些计划不表示未来能力已经实现；当前可运行事实仍以本 README、`GDD.md` 和 `ARCHITECTURE.md` 为准。

开始修改前请阅读 `AGENTS.md`、`GDD.md` 和 `ARCHITECTURE.md`。`sucai/` 仅作内部观察参考，授权确认前不得作为发行素材。
