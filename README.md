# Colony Under Glass

《玻璃蚁国》的 Godot 4.7.1 灰盒。默认入口仍是约 60～120 秒的湿度与幼体搬运切片；仓库另提供独立糖水觅食场景，用来验证“放置环境资源 → 工蚁自主发现 → 采集 → 返巢分享”。

## 当前功能

- 主场景直接生成 1 只蚁后、3 只工蚁、6 个幼体和两个相连巢室。
- 模拟以 0.1 秒固定 Tick 推进，支持暂停、1×、4×、16×；倍速不改变 Tick 边界。
- 左室补水是模拟拥有的无参数高层动作；目标和单次水量来自启动时冻结的场景配置，并在下一固定 Tick 开始时应用。
- 工蚁使用确定性的 `IDLE → MOVING_TO_BROOD → PICKING_UP → CARRYING_TO_ZONE → DROPPING` 状态机。
- 幼体预订、携带和区域归属保持单一所有权；目标失效时任务会安全取消或重定向。
- `HabitatView` 只读快照，按稳定实体 ID 维护视觉节点；幼体在携带时跟随对应工蚁，位置由相邻固定 Tick 的任务进度插值而非独立 Tween 产生。
- 玩家可以直接点击画面中的工蚁，使用静态轮廓持续辨认同一稳定个体；可选名称只保存在当前会话。
- 个体观察面板显示所选工蚁的自然语言当前行为和最近 4 条结构化行动记录，不显示内部实体或事件 ID。
- 模拟输出会话内单调、容量 64 的结构化观察事件；即使 16× 一帧跨越多个 Tick，界面也按事件游标依次消费而不只保留最后一条。
- 普通视图不显示精确湿度、内部任务、目标 ID 或生命周期倒计时。
- F3 诊断层显示 Tick、速度、左右室精确湿度、工蚁任务、目标、携带、预订和活跃搬运数。
- 玩家完成补水且群落连续稳定后，由模拟解锁观察记录。
- 解锁后界面显示明确的“观察完成”状态；“重新观察”会从同一份冻结配置恢复 Tick 0、1×、未暂停和初始实体，不继承旧命令、视觉节点、选择、名称或个人行动记录。
- 湿度场景通过快照明确标记生命周期不适用，不把预置幼体计为蚁后产卵。
- 生命周期试管展示保留为独立调试场景，不再是默认入口。
- 独立糖水场景生成 1 只蚁后、3 只工蚁，以及巢室、出入口、觅食区三个相连区域。
- 玩家使用两步操作放置糖水：先启用工具，再点击右侧觅食区；模拟只接收无参数命令，并在下一固定 Tick 按冻结配置创建食物源。
- 工蚁通过确定性 `IDLE → SEEKING_FOOD → MOVING_TO_FOOD → COLLECTING → RETURNING_TO_NEST → SHARING` 状态机自主完成任务，玩家不能指定执行者。
- 一份糖水只有一个预订者或携带者；分享后解锁观察记录，不产生资源条、饥饿或经济。
- `GameSnapshot` 分离群落、场景工具状态和观察记录；糖水 View 只读快照并按稳定实体 ID 复用节点。

当前所有物种、湿度和行为参数都是 `prototype_pacing_fixture`，未经科学验证。数据事实来源只有：

- `data/species/species_a.tres`
- `data/habitats/humidity_relocation_slice.tres`
- `data/habitats/sugar_foraging_slice.tres`
- `data/behaviors/sugar_foraging_prototype.tres`

发布候选检查与验收标准见 `ROADMAP.md`；GDD 与架构文档只描述已经实现的能力。

测试会从这些 Resource 计算节奏边界，不在生产代码或文档中复制生命周期 Tick。

## 运行

在仓库根目录打开编辑器：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --editor --path .
```

直接运行默认湿度切片：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --path .
```

单独运行生命周期调试场景：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --path . --scene 'res://scenes/debug/lifecycle_debug.tscn'
```

单独运行糖水觅食切片：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --path . `
  --scene 'res://scenes/foraging/sugar_foraging.tscn'
```

## 操作

### 默认湿度切片

- 先观察工蚁完成第一次幼体搬运，随后“给左室补水”按钮会开放。
- 正常流程分 3 次少量补水。
- 点击任一工蚁可持续观察它；名称为可选项，留空保存会清除名称。
- 个体观察面板会跟随所选工蚁更新当前行为，并保留最近 4 条行动。
- 使用“暂停”、`1×`、`4×`、`16×` 控制观察节奏。
- 按 F3 显示或隐藏诊断层。
- 观察记录解锁后，使用“重新观察”立即开始一局干净的新会话。

主视图提供环境和行为线索，但不会直接提示“湿度过低”。

### 独立糖水切片

- 点击“准备放置糖水”启用工具。
- 点击右侧觅食区完成提交；点击其他区域或按 Esc 取消。
- 命令提交后，糖水在下一固定 Tick 出现。
- 不需要也不能指定工蚁；观察哪只工蚁最先改变行动。
- 可继续选择、命名工蚁并查看它最近的行动。
- 暂停、1×、4×、16× 和 F3 与默认切片一致。
- 分享完成后使用“重新观察”开始干净的新会话。

## 测试

`tests/test_runner.gd` 是唯一顶层入口，聚合固定时钟、生命周期、湿度搬运黄金回归、糖水觅食、结构化事件、会话注释、快照／View 映射及场景测试：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script 'res://tests/test_runner.gd'
```

脚本解析和主场景冒烟：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 30
```

独立糖水场景冒烟：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --headless `
  --path . `
  --scene 'res://scenes/foraging/sugar_foraging.tscn' `
  --quit-after 30
```

## Windows 导出

仓库中的 `export_presets.cfg` 配置 Windows Desktop x86_64 release，并排除内部参考目录与测试。安装精确匹配 Godot `4.7.1.stable` 的官方 Windows Export Templates 后可运行：

```powershell
New-Item -ItemType Directory -Force -Path '.\builds\windows'
& '.\Godot_v4.7.1-stable_win64_console.exe' `
  --headless `
  --path . `
  --export-release 'Windows Desktop' `
  'builds/windows/ColonyUnderGlass.exe'
```

`builds/` 已忽略，不进入版本控制。

## 当前限制

- 默认入口仍是湿度切片；糖水切片是独立场景，尚未组合为 M4 的连续体验。
- 糖水场景固定为三个区域、三只工蚁、一个食物源和一份糖水。
- 湿度切片内生命周期冻结；完整生命周期只在独立调试场景中运行。
- 名称、选择和个人行动记录不会跨“重新观察”保留。
- 没有蛋白质、饥饿、能量、资源经济、多食物点、自由地图、镜头跟随、直接命令个体、存档、Steam、正式素材、音频或第三方插件。

v0.1 发布基线记录见 `docs/validation/v0.1_baseline_001.md`；M2 技术与人工检查边界见 `docs/validation/worker_identity_001.md`；M3 验证见 `docs/validation/sugar_foraging_001.md`。

开始修改前请阅读 `AGENTS.md`、`GDD.md` 和 `ARCHITECTURE.md`。`sucai/` 仅作内部观察参考，授权确认前不得作为发行素材。
