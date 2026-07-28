# R2 版本化存档核心

日期：2026-07-28

实现分支：`feat/v1-save-core`

## 范围

R2 只提供可由后续档案 UI 调用的存档核心：

- 捕获最近一次成功固定 Tick 后的权威状态。
- 保存冻结配置、时钟元数据和有序待处理高层命令。
- 规范化编码、SHA-256 完整性校验、大小限制与严格字段校验。
- 显式单向 schema 迁移。
- `user://` 临时文件、主档与备份的可恢复提交。
- 故障注入和存读等价测试。

R2 不把保存／加载按钮接入当前 Demo，不保存 View、会话注释、显示设置，不实现档案选择、删除确认、自动存档或云存档。这些属于 R3。

## 版本轴

| 字段 | R2 值 | 含义 |
| --- | --- | --- |
| `format_version` | `1` | 外层 JSON 容器格式 |
| `state_schema_id` | `r2.authority.v1` | 权威状态与待处理命令格式 |
| `game_version` | `0.2.0-demo` | 档案列表展示元数据，不决定兼容性 |
| `content_manifest_id` | `colony-under-glass.r2-base.1` | 当前内容兼容键 |

未知 `format_version`、未来 `state_schema_id` 或不同内容清单会被拒绝，不进行猜测性回退。

## SaveEnvelope

顶层字段固定为：

```text
format_version
game_version
content_manifest_id
frozen_config_hash
frozen_config_bundle
save_checksum
slot_id
saved_at_utc
simulation_tick
clock_speed
clock_paused
next_ids
pending_commands
state_schema_id
state_payload
```

`save_checksum` 是除自身外完整 Envelope 的规范化 JSON SHA-256；它用于检测损坏和不完整写入，不是密钥签名或反作弊机制。`frozen_config_hash` 是 `frozen_config_bundle` 的独立规范化 SHA-256。

所有 Dictionary 键按 Unicode 字符串顺序编码；整数值和数学上为整数的 JSON 浮点数编码为相同形式；NaN、无穷和不支持的 Variant 不能编码。读取文件上限为 4 MiB。

## 冻结配置

`frozen_config_bundle` 只保存当前模拟真正使用的值：

- 生命周期六项时长／数量。
- 有栖息地场景时的八项育幼行为值。
- 场景种类、稳定区域 ID、初始连接和初始环境值。
- 湿度动作、糖水动作和组合流程的实际冻结参数。

新游戏仍从 `.tres` 验证并冻结一次。加载只从存档 bundle 重建临时强类型 Resource，再经过原有验证路径形成私有运行时配置；不读取或合并安装目录中的 `.tres`。源 Resource 后续变化不能改变旧档轨迹。

## 权威状态

`state_payload` 保存 R2 已有的真实权威状态：

- 模拟 Tick、蚁后、蚂蚁与生命周期年龄。
- 区域湿度、连接和可用状态。
- 搬运与觅食任务的完整状态和进度。
- 食物源墓碑、剩余／携带／分享份数。
- 湿度动作次数、门控、稳定计数和观察卡。
- 五阶段进度。
- 最多 64 条结构化观察事件。

不保存：

- `GameSnapshot`、`ColonySnapshot` 或任何可重建反向关系。
- `Node`、`AntView`、Tween、插值端点、动画帧或屏幕坐标。
- `PlayerAnnotationState` 中的选择、名称和个人事件列表。
- `DemoSettingsState`、分辨率、语言或窗口模式。

`next_ids` 分别保存实体、观察事件和待处理命令 sequence 的下一个 ID，并严格大于已经使用的同域 ID。

## 待处理命令

每条记录只有：

```text
sequence_id
command_type
```

命令类型只允许补水、放置糖水和继续观察三种现有无参数高层意图。效果数值、目标区域和糖水份数仍来自冻结配置。命令按递增 sequence 保存，加载不消费命令；第一个合法固定 Tick 才按原顺序恰好应用一次。

## 捕获与加载顺序

`ColonySimulation` 在 Tick 执行期间设置内部边界标记。即使生命周期信号的监听者同步请求保存，`SaveGameService` 也会拒绝捕获；同一 Tick 成功结束后可以立即捕获。保存不会推进 Tick。

加载顺序：

1. 限制文件大小并解析 JSON。
2. 校验 Envelope 精确字段、类型、slot、版本、内容清单与 checksum。
3. 重新计算冻结配置哈希。
4. 在深复制上沿单向链迁移；不修改输入。
5. 从冻结 bundle 重建并验证私有运行时配置。
6. 重建新的 `ColonyState`、任务、事件、ID 和命令队列。
7. 校验有限数值、稳定 ID、图结构、任务进度、份数守恒、搬运所有权和组合阶段不变量。
8. 建立新的 `SimulationClock`；累积器清零，Tick、倍速和暂停状态恢复。
9. 全部成功后才把新模拟和时钟返回调用者。

失败结果不接触传入的活跃会话。

## 迁移

R2 包含一条用于固定机制的显式测试迁移：

```text
r2.authority.v0
    pending_commands: [command_type, ...]
    next_ids: entity_id + observation_event_id
        ↓
r2.authority.v1
    pending_commands: [{sequence_id, command_type}, ...]
    next_ids: 追加 pending_command_sequence_id
```

迁移在副本中按原数组顺序分配 sequence，重新计算 checksum，然后走与原生 v1 相同的全部验证。后续里程碑只能在这里追加新的单向迁移，不得修改旧链含义。

冻结旧档夹具为 `tests/fixtures/save/r2_authority_v0_lifecycle.json`；另有带待处理命令的程序化夹具验证命令迁移和下一 Tick 消费语义。

## 磁盘提交与恢复

`SaveGameService.save_to_path()` 只接受 `user://` 文件：

1. 在同目录写 `<slot>.tmp`，flush、close，并完整回读验证。
2. 若现有主档有效，将其轮换为 `<slot>.bak`；损坏主档不会覆盖已有有效备份。
3. 把已验证临时文件提升为主档。
4. 再次回读验证主档。

若平台不能单步覆盖现有文件，任何中断点仍至少保留主档、备份或已验证临时文件之一。读取顺序为主档 → 备份 → 临时文件，并返回实际恢复来源；R3 必须把非主档恢复明确告知玩家。

测试故障点为“临时文件写完后”和“备份轮换后”。它们只用于确定性测试，不由玩家输入触发。
