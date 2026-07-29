# R11 第 5 章模块化迁巢存档 Schema

> 当前 schema：`r11.authority.v9`
>
> 游戏版本：`0.11.0-dev`
>
> 状态：已实现并由自动测试覆盖

## 1. 变更目的

R11 在 R10 的章节、布局、环境与群落工作权威上加入可恢复的双室模块巢和第 5 章：

- 一个设施实例可以拥有主、次两个稳定区域 ID；
- 双室巢的育幼室与功能室分别保存环境和发现状态；
- 内部连接、按端口房间映射的外部连接和闸门状态继续进入同一布局图；
- 第 4 章完成档案继续进入第 5 章，而不是错误地保持整局完成；
- 第 5 章证据、推论和双室设施解锁继续使用 `CampaignState` 的稳定 ID 集合。

屏幕坐标、双室绘制尺寸、布局镜头、设施下拉栏选择、插值端点和完成面板关闭状态不进入权威存档。

## 2. 冻结配置

`frozen_config_bundle.habitat.act1_progression_config` 新增：

```text
core_migration_stable_ticks
```

该值只定义第 5 章核心迁移完成后的连续稳定窗口，是 `prototype_pacing_fixture`，不属于生命周期配置或真实物种数据。

冻结设施目录新增 `dual_chamber_nest`。其 `effect_config.kind` 为追加在枚举末尾的 `DUAL_CHAMBER_ZONE`，并保存：

```text
brood_initial_humidity
brood_initial_light_exposure
brood_initial_pollution
brood_pollution_per_tick
utility_initial_humidity
utility_initial_light_exposure
utility_initial_pollution
utility_pollution_per_tick
```

目录同时保存 2×2 占地、允许方向、育幼室／功能室外部端口、本设施必须连接的约束和一份冻结库存。加载只使用档内冻结值，不读取当前 `.tres`。

## 3. 权威状态

`state_payload.layout.facilities[]` 新增：

```text
secondary_zone_id
```

普通设施保存空字符串；双室巢保存稳定功能室 ID，原有 `zone_id` 保存稳定育幼室 ID。两个对应 `HabitatZoneState`、内部连接与外部连接仍保存在既有区域和连接数组中，不保存重复反向所有权。

R11 的合法正式 Act 1 序列为：

```text
ACT1_FOUNDING
→ ACT1_FIRST_WORKERS
→ ACT1_FORAGING_EXPANSION
→ ACT1_ENVIRONMENT_MANAGEMENT
→ ACT1_MODULAR_MIGRATION
→ COMPLETED
```

第五章完成要求证据、正确推论、完成章节数、双室设施解锁和完成 Tick 严格一致。恢复时，未知区域、重复区域所有权、无效双室端口、非法内部连接、越界环境值或不一致章节状态都会被拒绝。

## 4. 固定 Tick 与命令

R11 不增加新的通用命令框架。玩家继续使用现有白名单命令：

- `PLACE_FACILITY_ACTION`：稳定设施类型、逻辑槽位和方向；
- `SET_GATE_OPEN_ACTION`：稳定连接 ID 与开关意图；
- `SELECT_CAMPAIGN_INFERENCE_ACTION`：当前章节允许的稳定推论 ID；
- 既有补给和托盘清理高层动作。

放置双室巢时，模拟在下一连续 Tick 从冻结目录分配两个稳定区域 ID，建立内部连接，再按端口所在房间重建外部连接。UI 不提交区域 ID、环境初值或内部连接。

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
→ r11.authority.v9
```

`r10.authority.v8 → r11.authority.v9`：

- 为正式 Act 1 的冻结进度配置写入 `core_migration_stable_ticks`；旧独立场景保持 `null`；
- 在冻结目录追加双室巢类型与一份库存；
- 为所有既有设施状态写入空 `secondary_zone_id`；
- 若 R10 正式 Act 1 已完成四章，则恢复为第 5 章活动状态、清除旧整局完成 Tick 并解锁双室巢；
- 保留所有实体、任务、资源、事件、设施、区域、连接、环境、待处理命令和 next IDs；
- 更新游戏版本与 schema，重新计算冻结配置哈希和 Envelope checksum；
- 不读取当前 Resource，不原地修改输入字典。

测试使用真实 R10 形状的降级夹具，证明旧四章档案进入第 5 章并获得双室工具；原生 R11 档案还覆盖双室两个稳定区域 ID 的存读往返。
