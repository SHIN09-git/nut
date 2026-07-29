# R10 第 3～4 章存档 Schema

> 当前 schema：`r10.authority.v8`
> 游戏版本：`0.10.0-dev`
> 状态：已实现并由自动测试覆盖

## 1. 变更目的

R10 在 R9 的布局、环境与群落工作权威上加入可恢复的正式章节内容：

- 冻结第 3 章最小工蚁数、第 4 章污染改善阈值和环境连续稳定窗口；
- 保存第 4 章环境稳定 Tick；
- 把小型觅食区与环境管理加入 `CampaignState` 的显式章节序列；
- 为正式 Act 1 解锁专用糖液台、蛋白盘、垃圾托盘、备用试管、补水模块和连接组件族；
- 让旧两章完成档案继续进入第 3 章，而不是错误地保持整局完成。

屏幕坐标、设施下拉栏选择、布局镜头、插值端点、玩家选择和完成面板关闭状态仍不进入权威存档。

## 2. 冻结配置

`frozen_config_bundle.habitat` 新增 `act1_progression_config`：

```text
chapter_three_min_worker_count
pollution_avoidance_min_contrast
environment_stable_ticks
```

这些字段来自 `data/behaviors/act1_progression_prototype.tres`，只用于当前四章的证据与节奏。它们不属于生命周期配置，也不是真实物种数据。

R10 同时扩展冻结设施目录：

- `test_tube_nest` 的运行时解锁 ID 改为 `spare_test_tube`；
- 玩家放置的备用试管允许四向旋转并必须与已有接口连接；
- 备用试管使用冻结的动态区域环境初值；
- 增加 `connector_elbow` 的两接口冻结定义；
- 增加一个备用试管和四个弯管的初始库存。

初始试管仍由初始设施配置固定为不可拆除；类型本身可拆除只适用于后续玩家放置的实例。

## 3. 权威状态

`state_payload.act1` 新增：

```text
environment_stable_ticks
```

该字段只能在第 4 章需要的三项先决证据均已收集，且没有活动废物、侦察或迁移任务、全部幼体位于舒适低污染区域时连续累积。条件失效立即归零；达到冻结上限后不再增加。

`CampaignState` 继续保存稳定 ID 集合，不增加通用任务脚本。R10 的合法序列为：

```text
ACT1_FOUNDING
→ ACT1_FIRST_WORKERS
→ ACT1_FORAGING_EXPANSION
→ ACT1_ENVIRONMENT_MANAGEMENT
→ COMPLETED
```

章节、完成数、确认推论、证据与设施解锁必须严格匹配。恢复时，未知证据、未知推论、过早设施解锁、越界稳定 Tick 或不一致完成状态都会被拒绝。

## 4. 命令与固定 Tick

R10 不增加通用命令框架。它复用现有白名单高层命令：

- `PLACE_PROTEIN_ACTION` 不携带区域或份数；
- `PLACE_FACILITY_ACTION` 只携带稳定设施类型、逻辑槽位和方向；
- `SET_GATE_OPEN_ACTION` 只携带稳定连接 ID 与开关意图；
- `CLEAN_WASTE_TRAY_ACTION` 只携带稳定托盘 ID；
- `SELECT_CAMPAIGN_INFERENCE_ACTION` 只携带当前章节允许的稳定推论 ID。

所有命令都在下一连续固定 Tick 开始时使用档案内冻结配置重新校验。专用糖液台或蛋白盘存在时，模拟按稳定设施 ID 优先选择其宿主区域；UI 不提供权威落点或效果量。

## 5. 显式迁移链

```text
r2.authority.v0
→ r2.authority.v1
→ r4.authority.v2
→ r5.authority.v3
→ r6.authority.v4
→ r7.authority.v5
→ r8.authority.v6
→ r9.authority.v7
→ r10.authority.v8
```

`r9.authority.v7 → r10.authority.v8`：

- 只为正式 Act 1 写入冻结 `act1_progression_config`；旧独立场景保持 `null`；
- 更新备用试管类型的解锁、旋转、连接和动态环境字段；
- 追加弯管类型与备用试管／弯管库存；
- 初始化 `environment_stable_ticks = 0`；
- 若 R9 正式 Act 1 已完成两章，则改为第 3 章活动状态，清除旧整局完成 Tick，并解锁糖液台、蛋白盘和垃圾托盘；
- 保留所有实体、任务、资源、事件、布局、环境、连接和 next IDs；
- 更新游戏版本与 schema，并重新计算冻结配置哈希和 Envelope checksum；
- 不读取当前 Resource，不修改输入字典。

测试使用真实 R9 形状的降级夹具，证明迁移后的档案进入第 3 章、获得冻结 R10 配置且通过全部权威不变量。
