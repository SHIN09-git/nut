# R7 模块化布局存档 Schema

> 当前 schema：`r7.authority.v5`
> 游戏版本：`0.7.0-dev`
> 状态：已实现并由自动测试覆盖

## 1. 变更目的

R7 在 R6 Act 1 权威状态之外增加可恢复的栖息地布局：

- 冻结设施类型、尺寸、接口、库存和初始设施；
- 保存稳定设施实例、方向、逻辑槽位和下一个设施 ID；
- 保存稳定连接实例、闸门开关和下一个连接 ID；
- 保存设施剩余库存；
- 保存待处理的放置、旋转、拆除和闸门命令；
- 把原先区域对象中的邻接迁移为单一布局权威。

快照、设施命中矩形、放置预览、选中设施、镜头偏移和缩放仍不进入权威存档。

## 2. 冻结配置

`frozen_config_bundle.habitat` 新增：

```text
facility_catalog_config
```

没有设施目录的旧验证场景保存 `null`。正式 Act 1 保存：

```text
grid_width
grid_height
facility_types[]
initial_facilities[]
initial_supplies[]
```

每个设施类型冻结稳定类型 ID、显示角色、槽位宽高、可旋转／可拆除标记、解锁 ID，以及按方向保存的区域接口。加载只使用档案中的冻结值，不读取或合并当前 `.tres`。

## 3. 权威状态

`state_payload.layout` 保存：

```text
next_facility_id
facilities[]
next_connection_id
connections[]
supplies[]
```

设施实例至少保存稳定 ID、类型 ID、逻辑槽位和方向。连接实例保存稳定 ID、两个区域 ID、来源设施 ID、是否为闸门和开关状态。库存只保存类型 ID 与剩余数量。

恢复必须证明：

- 稳定 ID 唯一且 next ID 严格大于已有 ID；
- 每个设施类型存在且方向、尺寸、边界和接口有效；
- 不允许逻辑槽位重叠；
- 初始固定设施与冻结配置一致；
- 剩余库存加上非初始已放置数量等于冻结初始库存；
- 连接端点存在、无重复、来源设施有效；
- 闸门和普通连接的开关语义合法；
- 区域、搬运、觅食和营养系统都使用恢复后的布局可达图。

## 4. 待处理命令

R7 在已有命令枚举末尾追加：

```text
PLACE_FACILITY
ROTATE_FACILITY
REMOVE_FACILITY
SET_CONNECTION_GATE
```

放置命令保存类型 ID、槽位和方向；旋转／拆除保存稳定设施 ID；闸门命令保存稳定连接 ID 与目标开关。恢复时重新检查冻结目录、解锁、库存、几何、接口、可拆除性和目标存在性。合法命令仍只在下一连续固定 Tick 开始时按提交顺序应用。

遮光套继续由无参数高层命令提交，但应用时创建冻结目录中的固定 `light_cover` 设施并消耗对应库存。因此护理门控与画面设施使用同一权威事实。

## 5. 显式迁移链

```text
r2.authority.v0
→ r2.authority.v1
→ r4.authority.v2
→ r5.authority.v3
→ r6.authority.v4
→ r7.authority.v5
```

`r6.authority.v4 → r7.authority.v5`：

- 冻结正式 Act 1 的设施目录；旧场景目录保持 `null`；
- 把旧区域连接按稳定顺序写成布局连接实例；
- 为正式 Act 1 建立固定试管巢和微型喂食口；
- 若旧 Act 1 已应用遮光套，则建立对应遮光设施并扣减库存；
- 从区域状态移除运行时邻接字段；
- 初始化稳定 next ID 与设施库存；
- 更新游戏版本与 schema；
- 重新计算 `frozen_config_hash` 与 `save_checksum`；
- 不读取当前 Resource，不改变输入对象。

迁移夹具证明旧区域图在迁移前后具有相同稳定可达关系，并分别覆盖已安装与未安装遮光套的档案。
