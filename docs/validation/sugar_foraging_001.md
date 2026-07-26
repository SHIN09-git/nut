# 单次糖水觅食 M3 验证记录 001

- 日期：2026-07-27
- 分支：`feat/sugar-foraging-slice`
- 起始提交：`a2e5877`
- 前置黄金提交：`62ae740`
- 引擎：Godot `4.7.1.stable.official.a13da4feb`
- 人工验证分辨率：1280×720
- 范围：`CODEX_V0_2_MASTER_PLAN.md` 的 M3

## 结论

M3 技术候选通过：独立场景可从真实两步 UI 路径完成糖水出现、工蚁自主发现、去程、采集、携带返巢、分享和观察记录解锁。全量自动测试、三个场景冒烟、Windows 导出与导出构建冒烟均通过；默认 `project.godot` 入口仍为湿度切片。

这不是 M4 的连续游戏，也不代表 M2 外部试玩 Gate 已经完成。

## 已实现范围

- 把原幼体搬运逻辑提取为 `BroodRelocationSystem`，并用前置黄金签名保护行为等价。
- 将栖息地区域迁移为 2～3 个稳定 ID 的强类型数组。
- 增加冻结的糖水场景与觅食节奏 Resource。
- 增加下一固定 Tick 应用的无参数 `submit_place_sugar_action()`。
- 增加确定性觅食状态机、任务内路线、糖水份数守恒、软失效和返程恢复。
- 增加 `GameSnapshot`、`ForagingScenarioSnapshot` 与 `ObservationJournalSnapshot` 边界。
- 增加独立糖水场景、两步放置工具、三域 View、携带／分享反馈、F3、身份面板和重玩。
- 默认湿度入口与独立生命周期调试入口保持不变。

## 自动验证

| 命令 | 结果 | 退出码 |
| --- | --- | ---: |
| `Godot_v4.7.1-stable_win64_console.exe --version` | `4.7.1.stable.official.a13da4feb` | 0 |
| `Godot_v4.7.1-stable_win64_console.exe --headless --editor --path . --quit` | 脚本、Resource 与场景解析通过 | 0 |
| `Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd` | `PASS: 1780 project assertions` | 0 |
| 默认入口 `--headless --path . --quit-after 30` | 主场景冒烟通过 | 0 |
| M3 `--scene res://scenes/foraging/sugar_foraging.tscn --quit-after 30` | 独立糖水场景冒烟通过 | 0 |
| 生命周期 `--scene res://scenes/debug/lifecycle_debug.tscn --quit-after 30` | 独立调试场景冒烟通过 | 0 |
| `--export-release "Windows Desktop" C:\tmp\ColonyUnderGlass_M3.exe` | Windows x86_64 导出成功，109,071,360 bytes | 0 |
| 导出构建 `--headless --quit-after 30` | 导出构建启动并正常退出 | 0 |
| `git diff --check` | 通过 | 0 |

一次沙箱内测试尝试因 `user://logs` 不可写触发引擎子进程异常，未计入结果；同一标准命令在沙箱外重新运行后得到上表中的 1780 条通过结果和退出码 0。

## 自动覆盖

- 糖水放置命令在提交 Tick 只显示 pending，并在下一合法 Tick 创建配置中的食物源。
- 非连续 Tick 不消费待处理命令。
- 场景、区域、份数和五段时长在启动时冻结；修改源 Resource 不影响运行或重开。
- 工蚁与食物源按稳定实体 ID 确定性选择。
- 简单 BFS 同时缓存可达和不可达结果；只有端点或区域拓扑改变才增加路线缓存项。
- `SEEKING_FOOD`、`MOVING_TO_FOOD`、`COLLECTING`、`RETURNING_TO_NEST`、`SHARING` 的边界全部由 Resource 推导。
- 一份糖水最多由一个工蚁预订或携带；每 Tick 满足 `remaining + carried + shared == total_placed`。
- 食物源移除通过保留份数的不可用守恒墓碑完成；它会取消采集前任务并清理预订，恢复后可重新分配。
- 返巢路径或巢室暂时不可用时保留携带量、旧路线和阶段进度；恢复后完成分享。
- 快照子对象、数组、事件和卡片副本不能修改内部状态。
- 1×、4×、16× 在相同 Tick 产生相同模拟签名。
- 结构化事件完整、单调、唯一且不重复。
- 重开清除命令、源、任务、观察卡、事件和实体投影。
- 玩家选中或命名非最低 ID 工蚁不会改变最低稳定 ID 的自主任务分配。
- 移动中的暂停会同时冻结固定 Tick、插值 alpha 和工蚁投影；恢复后继续快照驱动的运动。
- 10,000 Tick soak 不崩溃、不产生非法所有权或非有限值。
- 真实 Viewport 的按钮、区域点击、F3、暂停、身份和连续两次重开路径通过。
- 湿度、生命周期、事件、身份和既有 View 套件继续通过。

## 1280×720 人工窗口检查

以下项目实际执行：

- 通过：默认 F3 隐藏；巢室、出入口、觅食区、蚁后和三只工蚁无重叠或截断。
- 通过：点击“准备放置糖水”后出现明确落点高亮；点击觅食区提交。
- 通过：1× 下分别在约 0.5、4、7、10、13、16 秒记录到糖水源、去程、采集、携带返巢、分享和完成画面。
- 通过：关闭 F3 时，携带中的高对比黄色糖滴跟随工蚁，返巢行为可辨认。
- 通过：分享阶段在巢室内有克制的扩散反馈；完成后观察记录与“重新观察”入口清楚。
- 通过：F3 显示 Tick、速度、场景阶段、区域、食物源、预订、携带和工蚁任务。
- 通过：暂停前后间隔 2 秒，诊断层 Tick 均为 1571，画面插值没有继续推进。
- 通过：1×、4×、16× 控件可用；16× 真实放置路径仍显示完成态，没有漏掉观察卡。
- 通过：选择工蚁、保存会话名称 `Amber` 和最近四条觅食历史与 M3 共存。
- 通过：“重新观察”后食物源、完成态、选择轮廓、名称和最近行动清空，速度恢复 1×。

人工检查截图只保存在本机临时目录 `C:\tmp`，不作为发行素材或仓库资源提交。

## 已知限制

- M3 仍是独立场景，尚未与生命周期、身份和湿度组合成 M4 连续流程。
- 固定三个逻辑区域、三只工蚁、一个糖水源和一份糖水。
- 分享只解锁观察记录，不实现蛋白质、饥饿、能量、寿命或经济。
- 路径是当前 2～3 区域的稳定 BFS 与任务内缓存，不是通用导航系统。
- 名称和个人行动历史只存在于当前会话。
- 所有参数都是未经科学验证的原型节奏夹具。

## 里程碑边界

M2 的外部试玩 Gate 仍保持 `docs/validation/worker_identity_001.md` 中的状态。本轮进入 M3 来自用户对 M3 的单独明确授权，不反向写成 M2 外部 Gate 已通过。

本轮没有加入 M4 编排、蛋白质、资源经济、存档、镜头、正式素材、第三方插件或直接命令工蚁。

## 最终 diff 审查

- 默认 `project.godot` 主场景未改变。
- `species_a.tres` 生命周期与湿度行为参数未改变。
- `BroodRelocationSystem` 拆分由黄金测试和全量旧回归保护。
- M3 UI 只投影快照；落点坐标、区域颜色和尺寸没有进入模拟。
- 未跟踪的用户文件 `DEVELOPMENT_PLAYBOOK.md` 未读取、修改或纳入提交。
- 最终 M3 提交与推送状态在交付总结中记录。
