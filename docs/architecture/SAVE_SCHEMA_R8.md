# R8 设施与环境传播存档 Schema

> 当前 schema：`r8.authority.v6`
> 游戏版本：`0.8.0-dev`
> 状态：已实现并由自动测试覆盖

## 1. 变更目的

R8 在 R7 布局权威上增加可恢复的设施效果与区域环境：

- 冻结每类设施的强类型效果；
- 冻结污染传播、幼体污染偏好与蚁后护理光照阈值；
- 保存区域湿度、光照和污染；
- 保存垃圾托盘已收集量；
- 让动态巢室区域和派生连接成为可验证权威状态；
- 让食物来源只能落在接受对应类型的稳定喂食设施。

屏幕坐标、设施颜色、污染颗粒、镜头、命中区域和插值端点仍不进入权威存档。

## 2. 冻结配置

`frozen_config_bundle.habitat` 新增：

```text
environment_config
zones[].light_exposure
zones[].pollution
facility_catalog_config.facility_types[].effect_config
```

正式 Act 1 的 `environment_config` 保存：

```text
pollution_diffusion_per_tick
brood_pollution_comfort_max
brood_pollution_penalty_weight
queen_care_light_max
```

旧独立验证场景保存 `environment_config = null`。设施效果使用带 `kind` 的封闭联合结构，只允许：

```text
HABITAT_ZONE
HYDRATION
FOOD_STATION
WASTE_TRAY
CONNECTOR
LIGHT_COVER
```

每个种类只保存自己的合法字段；未知种类、缺字段、额外字段、NaN、无穷或越界值都会使恢复失败。加载只使用档案中的冻结值，不读取或合并当前 `.tres`。

## 3. 权威状态

`state_payload.zones[]` 保存：

```text
zone_id
humidity
light_exposure
pollution
available
```

`state_payload.layout.facilities[]` 追加：

```text
waste_stored
```

动态区域使用提供区域的稳定设施 ID 派生唯一 `StringName`，例如 `small_foraging_box_003`。恢复必须证明：

- 区域 ID 唯一，三个环境值有限且位于 0～1；
- 所有设施都能在冻结目录中找到匹配效果；
- 需要宿主区域的设施引用有效区域；
- 区域设施与其动态区域一一对应；
- 垃圾量有限、非负且不超过冻结容量；
- 连接端点存在、来源设施有效，闸门开关与派生连接一致；
- 活动食物来源位于接受对应食物类型的设施区域；
- 环境、搬运、觅食和育幼所有权不变量同时成立。

## 4. 固定 Tick 顺序

R8 没有增加新的待处理命令枚举。合法 Tick 顺序为：

```text
验证 Tick 连续性
→ 按 sequence 消费待处理高层命令
→ EnvironmentSystem 推进设施效果与污染传播
→ 生命周期
→ 校验并推进已有任务
→ 分配新任务
→ 蚁后护理与章节证据
→ 全部不变量校验
→ 发布深复制快照
```

因此同一命令序列在连续运行、倍速和存读后仍得到相同权威结果。

## 5. 显式迁移链

```text
r2.authority.v0
→ r2.authority.v1
→ r4.authority.v2
→ r5.authority.v3
→ r6.authority.v4
→ r7.authority.v5
→ r8.authority.v6
```

`r7.authority.v5 → r8.authority.v6`：

- 为正式 Act 1 写入固定的 R8 环境配置；旧验证场景保持 `null`；
- 为配置区和运行区写入确定性的光照／污染迁移值；
- 为每个已知设施类型写入匹配的强类型效果；
- 为现有设施初始化 `waste_stored = 0`；
- 为旧遮光套补全试管宿主区域；
- 为旧小型觅食盒建立稳定动态区域，并在旧标准放置位置恢复等价连接；
- 保留旧连接 ID 和闸门开关，更新下一连接 ID 与布局 revision；
- 更新游戏版本和 schema，重新计算 `frozen_config_hash` 与 `save_checksum`；
- 不读取当前 Resource，不修改输入对象。

迁移测试从真实 R7 形状删除所有 R8 字段，证明迁移后的环境、设施、动态区域、连接和冻结值可恢复，并继续覆盖更早 schema 的完整单向迁移链。
