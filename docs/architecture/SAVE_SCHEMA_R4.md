# R4 章节与观察手册存档 schema

日期：2026-07-28

实现分支：`feat/v1-campaign-journal`

## 版本轴

| 字段 | 当前值 | 含义 |
| --- | --- | --- |
| `format_version` | `1` | 外层 JSON 容器格式，R4 未改变 |
| `state_schema_id` | `r4.authority.v2` | 权威状态与待处理命令格式 |
| `game_version` | `0.4.0-dev` | 档案展示元数据，不决定兼容性 |
| `content_manifest_id` | `colony-under-glass.r2-base.1` | 冻结模拟配置兼容键，R4 未加入新 Resource |

R4 沿用 R2 的规范化 JSON、4 MiB 限制、配置哈希、完整 Envelope checksum、临时文件提交、轮换备份和恢复顺序。`docs/architecture/SAVE_SCHEMA_R2.md` 保留为历史基线。

## 新增权威章节状态

组合观察场景的 `state_payload` 新增非空 `campaign`：

```text
campaign
├── chapter
├── status
├── chapter_entered_tick
├── completed_chapter_count
├── incorrect_inference_attempts
├── hint_tier
├── campaign_completed_tick
├── collected_evidence_ids[]
├── confirmed_inference_ids[]
└── unlocked_facility_type_ids[]
```

无栖息地生命周期调试、独立湿度和独立糖水场景必须保存 `campaign = null`。只有组合观察场景允许非空章节状态。

加载时除字段类型和稳定 ID 白名单外，还会验证：

- 证据集合与已经解锁的观察卡完全一致。
- 完成章节数、当前章节、状态和完成 Tick 一致。
- 已确认推论与完成章节一致。
- 初始试管巢／遮光套、微型喂食口和小型觅食盒的解锁集合与章节完成数一致。
- 提示层级为 0～3，且不大于累计错误推论次数。
- 快照数组不是权威状态，修改后不能影响内部集合。

设施目前只保存稳定类型 ID。R4 没有 `FacilityState`、摆放坐标、接口或环境效果。

## 待处理命令

`pending_commands` 的每条记录从 R2 的两字段扩展为：

```text
sequence_id
command_type
argument_id
```

- 补水、放置糖水和继续观察命令的 `argument_id` 必须为空。
- 章节推论命令的 `argument_id` 必须是当前章节仍可选择的稳定推论 ID。
- 同一命令类型仍不能重复排队；命令保持 sequence 递增并在加载后的下一合法固定 Tick 恰好应用一次。
- UI 文案、按钮索引和翻译文本不进入存档。

## 迁移链

当前迁移链为：

```text
r2.authority.v0
    ↓ 原 R2 迁移：命令数组转有序记录，补 pending command next ID
r2.authority.v1
    ↓ R4 迁移：命令补空 argument_id，组合场景派生 campaign
r4.authority.v2
```

`r2.authority.v1 → r4.authority.v2` 不猜测玩家尚未作出的最终推论：

- 建群序幕：第一章收集中。
- 身份阶段：记录首工证据，等待第一条推论。
- 已进入湿度阶段或之后：为兼容旧流程，确认第一条推论并解锁微型喂食口，进入第二章。
- 已进入糖水阶段：再记录湿度证据。
- 已进入旧总结阶段：再记录糖水证据，等待第二条推论。

旧档没有章节命令类型，因此迁移补入的 `argument_id` 均为空。迁移在深副本上执行、更新 `game_version` 和 schema、重新计算 checksum，再走与原生 R4 档案相同的冻结配置、状态图、所有权、章节和命令校验。

## 不保存

R4 仍不保存：

- `GameSnapshot`、`CampaignSnapshot` 或其他派生快照。
- View 节点、滚动位置、当前打开的日志／暂停遮罩、焦点或动画。
- 工蚁选择、名称和会话个人行动列表。
- 分辨率、语言、UI 缩放、减少动效和音量；这些继续由独立设置文件保存。
- 未实现的正式六章内容、营养、设施摆放或资源经济字段。
