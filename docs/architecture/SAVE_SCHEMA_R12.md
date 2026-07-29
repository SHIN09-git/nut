# R12 第 6 章与最终报告存档 Schema

> 当前 schema：`r12.authority.v10`
>
> 游戏版本：`1.0.0-beta`
>
> 状态：已实现并由自动测试覆盖

权威状态 schema 仍为 `r12.authority.v10`。R17 只把外层
`SaveEnvelope` 升级为格式 v2，用于保存不参与模拟的档案有效游玩时长；
字段、迁移和校验边界见 `SAVE_ENVELOPE_V2.md`。

## 1. 变更目的

R12 在 R11 的双室巢、核心迁巢和前五章权威上加入明确的第 6 章与完整档案结局：

- 第五条正确推论进入 `ACT1_STABLE_COLONY_SUMMARY`，不再提前完成档案；
- 首工历史、关键干预、最终布局和长期模式继续进入同一 `CampaignState`；
- 最后一条推论生成持久观察卡、结构化事件和报告 Tick；
- 结局报告由 UI 从只读快照排版，报告文本和面板关闭状态不进入权威存档。

## 2. 冻结配置

`frozen_config_bundle.habitat.act1_progression_config` 新增：

```text
finale_stable_ticks
final_report_observation_card_id
```

两者均来自 `prototype_pacing_fixture`。前者只定义最终布局持续稳定后开放最后推论的窗口；后者定义完成时解锁的稳定观察卡 ID。运行中的模拟、控制器和 UI 不读取源 `.tres`。

## 3. 权威状态

`state_payload.act1` 新增：

```text
finale_stable_ticks
final_report_generated_tick
```

R12 的合法正式 Act 1 序列为：

```text
ACT1_FOUNDING
→ ACT1_FIRST_WORKERS
→ ACT1_FORAGING_EXPANSION
→ ACT1_ENVIRONMENT_MANAGEMENT
→ ACT1_MODULAR_MIGRATION
→ ACT1_STABLE_COLONY_SUMMARY
→ COMPLETED
```

完成状态必须同时满足：

- `completed_chapter_count == 6`；
- 第六条长期布局推论已经确认；
- `campaign_completed_tick == final_report_generated_tick`；
- 报告 Tick 非负且不晚于当前模拟 Tick；
- 冻结的 `final_report_observation_card_id` 已解锁；
- `FINAL_REPORT_GENERATED` 使用稳定首工实体作为报告历史主体。

报告卡、报告 Tick、完成章节数或确认推论任一不一致都会使恢复失败。完成面板是否已关闭、报告换行排版、标题页焦点和镜头状态不保存。

## 4. 固定 Tick 与命令

R12 不增加新的命令类型。最终报告仍使用既有：

```text
SELECT_CAMPAIGN_INFERENCE_ACTION
```

UI 只提交当前 `CampaignSnapshot.available_inference_ids` 中的稳定推论 ID。提交 Tick 只显示待处理；下一连续固定 Tick 开始时按队列顺序确认推论，再写入报告 Tick、报告卡和结构化事件。

完成后，既有糖液、蛋白、清理、布局和环境命令继续走原命令边界，使“继续自由观察”保持可用；这些操作不会撤销已经生成的报告。

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
→ r12.authority.v10
```

`r11.authority.v9 → r12.authority.v10`：

- 为正式 Act 1 冻结进度配置写入终章稳定窗口和报告卡 ID；旧独立场景保持原形；
- 为 `Act1State` 写入 `finale_stable_ticks = 0` 与 `final_report_generated_tick = -1`；
- 若 R11 正式 Act 1 已完成五章，则恢复为第 6 章活动状态，并把章节进入 Tick 设为存档 Tick；
- 保留前五章证据、推论、双室区域、设施、连接、实体、任务、资源、事件、待处理命令和 next IDs；
- 不伪造第 6 章证据、报告卡、报告事件或完成 Tick；
- 更新游戏版本与 schema，重新计算冻结配置哈希和 Envelope checksum；
- 不读取当前 Resource，不原地修改输入字典。

测试使用真实 R11 形状的降级夹具验证五章完成档案进入第 6 章；原生 R12 档案还覆盖终章中途稳定计数、完成报告、结构化事件和冻结配置的存读往返。
