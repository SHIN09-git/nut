# R5 营养成长存档 Schema

> 当前 schema：`r5.authority.v3`
> 游戏版本：`0.5.0-dev`
> 状态：已实现并由自动测试覆盖

## 1. 变更目的

R5 在 R4 章节状态之外增加可持续恢复的营养权威状态：

- 冻结营养节奏配置；
- 糖类与蛋白食物源；
- 群落糖／蛋白储备、累计供应与累计消耗；
- 工蚁育幼喂食任务；
- 幼虫当前剩余的蛋白支持成长 Tick；
- 待处理蛋白放置命令。

快照、View、显示设置和会话名称仍不进入权威状态。

## 2. 冻结配置

`frozen_config_bundle.habitat` 新增：

```text
lifecycle_active
nutrition_config
protein_placement_zone_id
protein_portions
```

`nutrition_config` 只在 `NUTRITION_GROWTH` 场景存在，包含：

```text
initial_sugar_reserve_portions
initial_protein_reserve_portions
sugar_activity_ticks_per_portion
sugar_shortage_step_interval_ticks
protein_growth_ticks_per_portion
feeding_decision_interval_ticks
feeding_travel_duration_ticks
feeding_duration_ticks
```

这些值从 `.tres` 验证并复制一次。加载后只使用档案中的冻结值，不与当前安装目录 Resource 合并。

## 3. 权威状态

`state_payload.nutrition` 在非营养场景为 `null`；营养场景保存：

```text
sugar_reserve_portions
protein_reserve_portions
sugar_activity_ticks_remaining
total_sugar_portions_supplied
total_protein_portions_supplied
total_sugar_portions_consumed
total_protein_portions_consumed
total_protein_portions_placed
delivered_protein_portions
completed_feeding_count
```

每个蚂蚁记录新增：

```text
protein_supported_growth_ticks
feeding_task
```

`feeding_task` 为 `null` 或保存状态、稳定目标幼虫 ID、来源／目标区域、逻辑路线、阶段 Tick 和下一决策 Tick。食物携带类型仍由不可删除的目标食物源派生，不在任务中复制第二份事实。

## 4. 守恒与恢复校验

营养场景加载必须同时满足：

```text
糖来源剩余 + 糖携带 + 糖储备 + 糖已消耗 = 糖总供应
蛋白来源剩余 + 蛋白携带 + 蛋白储备 + 蛋白已消耗 = 蛋白总供应
```

此外：

- 所有计数非负；
- 一只工蚁最多执行一个搬运、觅食或喂食任务；
- 一个幼虫最多被一个喂食任务预订；
- 活跃喂食预订数不超过当前蛋白储备；
- 只有幼虫可以持有蛋白支持成长 Tick；
- 营养场景的蚂蚁总数等于初始工蚁、初始幼体与本会话产卵数之和；
- 食物、蚂蚁、事件和命令 ID 继续满足稳定顺序与唯一性。

任一条件失败时，加载整体拒绝，不返回部分恢复会话。

## 5. 待处理命令

R5 在已有命令枚举末尾追加 `PLACE_PROTEIN_ACTION`，保持旧命令数值稳定。命令不携带区域、份数或目标个体；恢复时重新检查冻结场景是否仍允许该动作，并在下一合法固定 Tick 开始应用。

## 6. 显式迁移链

```text
r2.authority.v0
→ r2.authority.v1
→ r4.authority.v2
→ r5.authority.v3
```

`r4.authority.v2 → r5.authority.v3`：

- 为旧栖息地冻结配置写入 `lifecycle_active = false`、空蛋白目标、零蛋白份数和 `nutrition_config = null`；
- 为旧状态写入 `nutrition = null`；
- 为旧蚂蚁写入零蛋白成长支持和空喂食任务；
- 重新计算 `frozen_config_hash` 与 `save_checksum`；
- 不读取当前 Resource，不改变旧输入对象。

因此旧生命周期、湿度、糖水和 R4 组合档案保持原行为；迁移不会猜测或补发营养资源。
