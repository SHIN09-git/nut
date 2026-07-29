# SaveEnvelope v2 · 档案有效游玩时长

> 外层格式：`format_version = 2`
>
> 权威模拟 schema：`r12.authority.v10`（未改变）
>
> 游戏版本：`1.0.0-beta`

## 目的

v2 在存档外层增加档案级的有效游玩时长，使档案页可以区分真实投入时间与受 `1×／4×／16×` 影响的模拟历程。它只为试玩节奏和档案摘要提供本机证据，不改变固定 Tick、章节规则、资源消耗或模拟结果。

计时从玩家在 Tick 0 准备门点击“开始观察”后开始：

- 窗口获得焦点时计入；
- 暂停菜单、帮助、手册阅读和玩家选择倍速的时间计入；
- 标题页、Tick 0 准备门和应用失焦时间不计入；
- 从失焦恢复后的第一个帧样本丢弃，避免把系统挂起间隔算入；
- 完成后继续自由观察仍累计档案总时长，但首次结局时长只记录一次。

这比外测协议“失焦超过 30 秒才排除”更保守。正式外测仍应保留人工起止、阻塞和介入记录，不能只依赖存档数字。

## 外层字段

`profile_playtime` 不进入 `state_payload`，也不参与模拟快照：

```text
profile_playtime:
  format_version
  active_microseconds
  chapter_active_microseconds[8]
  completion_active_microseconds
  has_legacy_gap
```

- `active_microseconds` 是该档案已记录的有效总时长。
- `chapter_active_microseconds` 按稳定 `CampaignState.Chapter` 枚举槽位保存。各槽位之和不得超过总时长。
- `completion_active_microseconds` 为首次生成结局时的有效总时长；未完成时为 `-1`，后续自由观察不能覆盖。
- `has_legacy_gap` 标记格式 v1 档案在升级前没有可恢复的墙钟历史。
- 所有时长都使用有界非负整数微秒，避免浮点累积进入持久格式。

完整 `profile_playtime` 与其他外层字段一起由 `save_checksum` 覆盖。UI 只读取 `ProfileStore` 返回的摘要；模拟和 View 都不能修改它。

## 迁移

读取格式 v1 时，加载器先按原始字段验证 checksum 和冻结配置哈希，再执行：

1. 将外层格式升级到 v2；
2. 保持 `state_schema_id`、冻结配置、Tick、命令队列和权威状态不变；
3. 写入零时长、`has_legacy_gap = true` 的默认计时元数据；
4. 使用当前规范化编码重新封装 checksum。

迁移不会猜测历史墙钟时间。档案页显示“自本版本起”，直到玩家新建没有历史缺口的档案。未知格式、非法数组长度、负数、非有限数、章节和大于总时长、完成时长晚于总时长或未封装的篡改都会被拒绝。

## 验证边界

自动测试覆盖：

- 计时、章节拆分、首次结局冻结和返回数据隔离；
- 格式 v1 → v2 迁移不伪造历史时长；
- 时长元数据的 checksum、防篡改和非法形状拒绝；
- 主档摘要、暂停保存、返回标题、继续和再次保存；
- 倍速不改变有效时长，暂停阅读计入，失焦与恢复首帧不计入；
- 旧模拟 schema 迁移和全部固定 Tick 回归继续通过。

该记录只证明本机证据链可靠。3～4 小时中位时长、完成率和理解度仍必须由冻结候选上的外部首次完整档案证明。
