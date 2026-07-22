# 《玻璃蚁国》技术架构

> 文档版本：0.1｜更新日期：2026-07-22
>
> 适用范围：七个开发时段的 Godot 灰盒及其后续演进

## 1. 架构目标

- 在 Godot 4.7.1-stable 中实现可复现、可批量测试的蚁群模拟。
- 严格分离模拟数据、场景显示和玩家输入。
- 首轮支持 Windows、鼠标操作、暂停、1×、4×、16×速度。
- 优先保证 3 只工蚁的行为可读性，同时用独立场景验证 100 只蚂蚁的稳定性。
- 保留数据化扩展空间，但不为多物种、联网或数千只 AI 预先设计复杂框架。

## 2. 固定技术决定

| 项目 | 决定 |
| --- | --- |
| 引擎 | `4.7.1.stable.official.a13da4feb` |
| 脚本 | 强类型 GDScript |
| 模拟频率 | 固定 0.1 秒／Tick，即每模拟秒 10 Tick |
| 显示更新 | 每帧插值；显示帧率不影响模拟结果 |
| 随机性 | 单一项目 RNG 服务，显式种子，可复现 |
| 路径模型 | 巢室、连接管、觅食区组成的图；目标变化时才重算 |
| 数据配置 | 强类型 Godot `Resource`／`.tres`，运行时模型不读取散落常量 |
| 存档方向 | 带 `schema_version` 的 JSON；原型可先只保存最小状态 |
| 第三方插件 | 首轮禁止；测试使用项目自建的 headless 入口 |

## 3. 分层与数据流

```text
PlayerInput
    ↓ 生成命令，不直接改模型
MainController
    ↓
SimulationClock ── pause / 1× / 4× / 16×
    ↓ 固定 Tick
ColonySimulation
    ├── EnvironmentSystem
    ├── LifecycleSystem
    ├── BehaviorSystem
    ├── MovementSystem
    ├── ResourceSystem
    └── EventSystem
    ↓ 只读快照／信号
ViewAdapter
    ├── AntView
    ├── BroodView
    ├── HabitatView
    └── UI
```

关键规则：

- 模拟层是唯一真实状态来源。
- 输入层只能提交命令；不得直接移动 `AntView` 或修改资源数值。
- View 只显示、插值和播放动画；不得反写模拟状态。
- 模拟模型不得保存 `Node`、`NodePath`、动画或输入对象的引用。
- 不允许每只蚂蚁在 `_process()` 中独立决策；由 `ColonySimulation` 统一调度。

## 4. 计划目录

目录在创建第一个 Godot 场景时逐步落地；当前文档不声称这些文件已经存在。

```text
/
  project.godot
  GDD.md
  ARCHITECTURE.md
  AGENTS.md
  README.md
  /scenes
    /main
    /habitat
    /ui
    /tests
  /scripts
    /core
    /simulation
    /behavior
    /environment
    /events
    /view
    /ui
    /save
  /data
    /species
    /foods
    /habitats
    /events
  /tests
    test_runner.gd
    /unit
    /simulation
    /save
  /assets
    /placeholders
    /sprites
    /audio
    /fonts
  /sucai
  /build
```

文件和目录使用小写 `snake_case`；GDD、架构和根代理说明保留现有大写文件名。

## 5. 核心模型

### `SimulationClock`

- 使用累加器按 0.1 秒固定 Tick 推进模拟。
- 暂停时不推进模拟时间。
- 倍速只改变单位现实时间内执行的 Tick 数，不改变单 Tick 步长。
- 不使用系统时间决定生命周期或事件结果。

### `ColonyState`

持有蚁后、幼体、工蚁、环境、资源、事件和当前模拟 Tick。所有实体拥有稳定且唯一的 ID。

### `AntModel` 与 `BroodModel`

- 只保存数据，例如实体 ID、生命周期阶段、位置、能量、当前任务和目标 ID。
- 不保存 Sprite、Tween、AnimationPlayer 或其他场景节点。
- 实体遍历顺序必须稳定；需要时按 ID 排序，避免容器顺序改变结果。

### `SpeciesData`

集中保存生命周期时间、舒适湿度、资源影响、移动速度和行为阈值。首轮只存在 `Species_A`，但代码不得把其数值写死成唯一物种规则。

### `EnvironmentState`

保存各区域的湿度、可达性和补给状态。湿度使用明确单位或标准化区间；在确定真实物种前，不将临时数值描述为科学数据。

### `BehaviorSystem`

根据模型状态选择护理、觅食、返回、搬运幼体、休息等任务。行为选择顺序和随机打破平局的方式必须可复现。

## 6. 每 Tick 更新顺序

固定顺序暂定为：

1. 应用上一帧收集的玩家命令。
2. 更新环境与资源状态。
3. 更新卵、幼虫、蛹和工蚁生命周期。
4. 评估事件进入／退出条件。
5. 为需要重新决策的个体选择任务。
6. 更新图路径上的移动。
7. 结算觅食、护理、搬运和资源交互。
8. 生成供 View 使用的只读快照和事件信号。

系统之间不得依赖场景树的处理顺序。任何顺序调整都必须附带确定性测试。

## 7. 随机性与复现

- 新游戏由一个显式种子创建项目 RNG。
- 其他系统不得自行创建未登记的随机源。
- 测试固定种子并验证关键阶段 Tick、事件和资源结果。
- 若存档发生在随机序列中间，需保存足以继续复现的 RNG 状态。
- Bug 报告应包含引擎版本、种子、模拟 Tick 和玩家命令序列。

## 8. 路径与性能

- 栖息地使用节点图表示：试管／巢室为区域，连接管为边。
- 只在目标变化、连接断开或新资源出现时重新寻路。
- View 使用对象池；个体显示数量上限在压力测试后确定。
- 原型体验场景只需要 3 只工蚁；另建 100 只蚂蚁压力场景，避免用正式流程等待扩群。
- 最低测试硬件尚未确定，因此暂不声称达到特定 GPU 或帧率指标。

## 9. 存档边界

存档不是验证核心乐趣的阻塞项，但从第一次实现起遵守以下格式：

- 顶层包含 `schema_version`、引擎版本、游戏版本、种子和模拟 Tick。
- 只保存数字、字符串、布尔、数组和字典；向量显式拆成数值字段。
- 保存稳定实体 ID，不保存运行时 NodePath。
- 字段变更需要迁移函数和旧档测试。
- 写入临时文件成功后再替换正式文件，并保留最近一个备份。

## 10. 测试策略

首轮不引入 GUT 或 GdUnit4。项目创建 `tests/test_runner.gd`，以 headless `SceneTree` 方式运行。

最低测试集：

- 相同种子与相同命令得到相同结果。
- 卵 → 幼虫 → 蛹 → 工蚁的转换 Tick 正确。
- 资源不出现负数、无穷或 NaN。
- 湿度事件具有明确进入和退出条件。
- 幼体只被搬到可达区域。
- 断开连接后个体不会穿越不可达边。
- 保存再读取后关键状态一致；实现存档后启用。
- 连续 10,000 Tick 不崩溃、不永久卡住事件。
- 100 只蚂蚁压力场景能够完成规定 Tick。

## 11. 本地命令

以下命令以仓库根目录为工作目录。

已验证：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --version
```

待创建 `project.godot` 和相应入口后验证：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --editor --path .
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script 'res://tests/test_runner.gd'
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script 'res://tests/test_runner.gd' -- --suite=soak --ticks=10000 --seed=12345
```

Windows 导出命令只有在安装同版本 Export Templates 并创建 `export_presets.cfg` 后才能加入“已验证”列表。

## 12. 当前风险与开放项

- 真实物种、湿度参数和生命周期仍待养蚁者审校。
- 15 分钟内同时呈现生命周期、觅食和湿度因果链，可能节奏过密，需要试玩调参。
- 行为是否足够清晰，不能由单元测试替代，必须进行无讲解试玩。
- `sucai/` 图片授权未知，只能内部参考。
- Export Templates 尚未确认，Windows 导出能力仍待验证。
