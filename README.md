# Colony Under Glass

《玻璃蚁国》的 Godot 4.7.1 灰盒。默认入口是一个约 60～120 秒的湿度与幼体搬运切片，用来验证“观察 → 推断 → 干预 → 行为反馈”。

## 当前功能

- 主场景直接生成 1 只蚁后、3 只工蚁、6 个幼体和两个相连巢室。
- 模拟以 0.1 秒固定 Tick 推进，支持暂停、1×、4×、16×；倍速不改变 Tick 边界。
- 左室补水是模拟拥有的无参数高层动作；目标和单次水量来自启动时冻结的场景配置，并在下一固定 Tick 开始时应用。
- 工蚁使用确定性的 `IDLE → MOVING_TO_BROOD → PICKING_UP → CARRYING_TO_ZONE → DROPPING` 状态机。
- 幼体预订、携带和区域归属保持单一所有权；目标失效时任务会安全取消或重定向。
- `HabitatView` 只读快照，按稳定实体 ID 维护视觉节点；幼体在携带时跟随对应工蚁，位置由相邻固定 Tick 的任务进度插值而非独立 Tween 产生。
- 普通视图不显示精确湿度、内部任务、目标 ID 或生命周期倒计时。
- F3 诊断层显示 Tick、速度、左右室精确湿度、工蚁任务、目标、携带、预订和活跃搬运数。
- 玩家完成补水且群落连续稳定后，由模拟解锁观察记录。
- 解锁后界面显示明确的“观察完成”状态；“重新观察”会从同一份冻结配置恢复 Tick 0、1×、未暂停和初始实体，不继承旧命令或视觉节点。
- 湿度场景通过快照明确标记生命周期不适用，不把预置幼体计为蚁后产卵。
- 生命周期试管展示保留为独立调试场景，不再是默认入口。

当前所有物种、湿度和行为参数都是 `prototype_pacing_fixture`，未经科学验证。数据事实来源只有：

- `data/species/species_a.tres`
- `data/habitats/humidity_relocation_slice.tres`

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

## 操作

- 先观察工蚁完成第一次幼体搬运，随后“给左室补水”按钮会开放。
- 正常流程分 3 次少量补水。
- 使用“暂停”、`1×`、`4×`、`16×` 控制观察节奏。
- 按 F3 显示或隐藏诊断层。
- 观察记录解锁后，使用“重新观察”立即开始一局干净的新会话。

主视图提供环境和行为线索，但不会直接提示“湿度过低”。

## 测试

`tests/test_runner.gd` 是唯一顶层入口，聚合固定时钟、生命周期、湿度搬运、快照／View 映射及两个场景的测试：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script 'res://tests/test_runner.gd'
```

脚本解析和主场景冒烟：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 30
```

## 当前限制

- 只有两个直接相连区域、一个物种和固定参与者。
- 湿度切片内生命周期冻结；完整生命周期只在独立调试场景中运行。
- 没有觅食、资源消耗、命名、镜头跟随、存档、Steam、正式素材、音频或第三方插件。
- 当前机器未配置 Windows Export Templates，因此不提供已验证的导出命令。

开始修改前请阅读 `AGENTS.md`、`GDD.md` 和 `ARCHITECTURE.md`。`sucai/` 仅作内部观察参考，授权确认前不得作为发行素材。
