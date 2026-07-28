# R9 清理、侦察与迁巢存档 Schema

> 当前 schema：`r9.authority.v7`
> 游戏版本：`0.9.0-dev`
> 状态：已实现并由自动测试覆盖

## 1. 变更目的

R9 在 R8 环境与设施权威上增加可恢复的群落工作：

- 冻结废物清理、区域侦察与群落迁移规则；
- 保存区域发现状态；
- 保存废物、侦察和迁巢三个专用任务；
- 保存蚁后的区域与进入 Tick；
- 保存迁巢候选、稳定窗口、目标和完成计数；
- 保存待处理的高层垃圾托盘清理命令。

屏幕坐标、程序化颜色、任务光晕、插值端点、选择和镜头仍不进入权威存档。

## 2. 冻结配置

`frozen_config_bundle.habitat` 新增 `colony_work_config`：

```text
waste_source_pollution_min
waste_batch_amount
waste_decision_interval_ticks
waste_travel_ticks_per_connection
waste_pickup_duration_ticks
waste_drop_duration_ticks
scout_decision_interval_ticks
scout_travel_ticks_per_connection
scout_observe_duration_ticks
migration_min_improvement
migration_pollution_max
migration_target_stable_ticks
migration_minimum_zone_dwell_ticks
migration_decision_interval_ticks
migration_travel_ticks_per_connection
migration_pickup_duration_ticks
migration_drop_duration_ticks
```

所有数值来自启动时验证并复制的 `prototype_pacing_fixture`。加载只使用档案中的冻结副本；未知字段、缺字段、非法范围、NaN 或无穷会使恢复失败。

配置区的每个区域追加初始 `discovered`。R8 旧档迁移时，既有动态区域保持已发现，以维持旧档可达行为；R9 新放置的动态区域初始未发现。

## 3. 权威状态与任务

`state_payload` 新增：

```text
queen.zone_id
queen.zone_entered_tick
colony_work_state
zones[].discovered
zones[].discovered_tick
ants[].waste_cleanup_task
ants[].scout_task
ants[].migration_task
```

三个任务分别保存自己的状态枚举、来源／目标稳定 ID、缓存路线、阶段 Tick，以及必要的预订或携带量。迁移任务还保存目标成员、当前携带成员和是否正在返回来源。

恢复必须证明：

- 每个工蚁最多有一个活跃任务；
- 废物来源与托盘容量不会被重复预订，污染和携带量守恒；
- 未发现区域不会被普通任务使用；
- 未携带的幼体与蚁后各属于一个有效区域；
- 被迁移的成员区域为空，且恰好属于一个迁移工蚁；
- 一个成员最多被一个迁移任务预订或携带；
- 所有目标、路线、设施和区域引用有效；
- 空闲任务不残留目标、路线、计时、预订或携带关系。

## 4. 命令与固定 Tick

`pending_commands` 追加 `CLEAN_WASTE_TRAY_ACTION`。命令只保存：

```text
sequence_id
command_type
argument_int = stable facility_id
```

它不保存清理量。下一连续 Tick 开始时，模拟使用冻结目录重新验证目标是可清理垃圾托盘，且没有活动任务引用，再原子清理；拒绝不会部分修改容量。

R9 的相关 Tick 顺序：

```text
验证连续 Tick
→ 按 sequence 应用高层命令
→ 环境与设施效果
→ 更新迁巢候选
→ 生命周期
→ 校验并推进所有既有任务
→ R9 工作分配
→ 育幼／喂食／觅食分配
→ Director 与全部不变量
→ 深复制快照
```

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
```

`r8.authority.v6 → r9.authority.v7`：

- 为正式 Act 1 写入固定的 R9 工作配置；旧独立验证场景保持 `null`；
- 为区域配置和运行状态补全发现字段；
- 保持 R8 已存在动态区域为已发现，避免迁移改变旧档可达行为；
- 为蚁后写入原巢区域和进入 Tick；
- 初始化空迁巢状态与三个完成计数；
- 为现有工蚁初始化三个空闲工作任务；
- 保留已有任务、环境、布局、章节、资源和 ID；
- 更新游戏版本和 schema，并重新计算配置哈希与存档 checksum；
- 不读取当前 Resource，不修改输入字典。

测试使用真实 R8 形状的降级夹具，并覆盖更早 schema 的完整单向迁移链。活动 R9 侦察任务还经过存读后的逐 Tick 快照等价验证。
