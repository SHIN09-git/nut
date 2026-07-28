# R6 Act 1 存档 Schema

> 当前 schema：`r6.authority.v4`
> 游戏版本：`0.6.0-dev`
> 状态：已实现并由自动测试覆盖

## 1. 变更目的

R6 在 R5 营养权威状态之外增加正式 Act 1 前两章所需的可恢复状态：

- 冻结蚁后护理与观察节奏；
- 遮光套动作及待处理命令；
- 蚁后护理状态、目标与进度；
- 蛹观察进度；
- 稳定首工身份与羽化 Tick；
- 首次工蚁护理证据；
- Act 1 章节、证据、推论、提示和设施解锁。

快照、View、显示设置、放大镜状态和完成面板是否已关闭仍不进入权威存档。

## 2. 冻结配置

`frozen_config_bundle.habitat` 新增：

```text
founding_care_config
```

非 Act 1 场景为 `null`；Act 1 保存：

```text
rest_duration_ticks
gathering_duration_ticks
brood_care_duration_ticks
pupa_observation_ticks
first_worker_initial_pupa_age_ticks
queen_care_observation_card_id
pupa_observation_card_id
first_worker_observation_card_id
worker_care_observation_card_id
```

这些值从 `.tres` 验证并复制一次。加载后只使用档案中的冻结值，不读取或合并当前安装目录中的 Resource。

## 3. 权威状态

`state_payload.act1` 在非 Act 1 场景为 `null`；正式 Act 1 保存：

```text
light_cover_applied
light_cover_action_count
queen_care_state
queen_care_elapsed_ticks
queen_care_target_brood_id
completed_queen_care_count
pupa_stable_ticks
first_worker_entity_id
first_worker_emerged_tick
first_worker_care_recorded
```

章节状态继续使用 R4 已建立的 `state_payload.campaign`，营养状态继续使用 R5 的 `state_payload.nutrition`。新章节枚举、证据 ID 和设施 ID 都经过合法集合校验。

## 4. 待处理命令

R6 在已有命令枚举末尾追加 `APPLY_LIGHT_COVER_ACTION`，保持旧命令数值稳定。命令不携带场景、目标、持续时间或证据参数；恢复时重新检查：

- 当前场景必须是 Act 1；
- 蚁后护理系统与 `Act1State` 必须存在；
- 遮光尚未应用；
- 队列中不存在重复遮光命令。

合法命令只在下一连续固定 Tick 开始时应用。

## 5. 恢复校验

Act 1 加载必须同时满足：

- 冻结护理配置有效且观察卡 ID 唯一；
- 初始首代个体计数与蚁后记录一致；
- `Act1State` 只存在于 `act1_test_tube` 场景；
- 护理状态、阶段 Tick、目标幼体和完成计数有效；
- 首工实体 ID 指向原晚期蛹，羽化前后阶段与 Tick 一致；
- 蛹、护理、营养证据与 `CampaignState` 一致；
- 糖／蛋白守恒、工蚁任务互斥和单一所有权继续成立。

任一条件失败时，加载整体拒绝，不返回部分恢复会话。

## 6. 显式迁移链

```text
r2.authority.v0
→ r2.authority.v1
→ r4.authority.v2
→ r5.authority.v3
→ r6.authority.v4
```

`r5.authority.v3 → r6.authority.v4`：

- 为旧栖息地冻结配置写入 `founding_care_config = null`；
- 为旧状态写入 `act1 = null`；
- 更新游戏版本与 schema；
- 重新计算 `frozen_config_hash` 与 `save_checksum`；
- 不读取当前 Resource，不改变输入对象。

因此旧生命周期、湿度、糖水、组合观察和 R5 营养档案保持原行为。应用外壳根据恢复后的 `scenario_id` 选择对应场景；迁移不会把旧档伪装成新的 Act 1 档案。
