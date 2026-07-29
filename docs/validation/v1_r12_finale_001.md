# v1 R12 第 6 章与完整结局验证记录 001

> 分支：`feat/v1-act4-finale`
>
> 日期：2026-07-29
>
> 结论：技术候选通过；外部完整档案与首次接触 Gate 仍为 `INCOMPLETE`

## 1. 本轮范围

本轮交付正式 Act 1 第 6 章与明确档案终点：

- 第五条正确推论进入“稳定群落总结”，不再提前结算；
- 以首工历史、关键干预、最终双室布局和连续稳定模式形成四条权威证据；
- 最后一条推论继续使用现有下一 Tick 命令边界；
- 成功后写入报告 Tick、解锁 `glass_observation_report`、记录 `FINAL_REPORT_GENERATED` 并完成六章档案；
- 结局面板展示快照生成的“玻璃观察报告”，提供继续自由观察与保存返回标题；
- 手册普通视图只列当前章证据，终章推论在 1280×720 无需穿过前五章长列表；
- `r12.authority.v10` 保存终章中途／完成状态，并显式迁移 R11 五章完成档案；
- 独立 144,000 Tick 长时档案验证包含中点存读。

没有加入第二物种、战斗、温度、经济、离线成长、自动存档、Steam、正式素材、音频、通用 AI 框架或第三方依赖。

## 2. 模拟更新与结算顺序

R12 保留 0.1 秒固定 Tick 与既有更新顺序：

```text
拒绝非连续 Tick
→ 按 sequence 应用待处理高层命令
→ 推进设施环境效果
→ 推进生命周期与现有工蚁系统
→ 收集当前章节权威证据
→ 刷新章节状态
→ 校验章节、所有权、任务、资源与有限数值
→ 创建复制快照
```

第五章正确推论只执行：

```text
completed_chapter_count = 5
→ ACT1_STABLE_COLONY_SUMMARY
→ finale_stable_ticks = 0
→ 保持 campaign_completed_tick = -1
```

第六章最后推论在提交 Tick 只显示 `inference_action_pending`。下一合法 Tick 同时确认推论、写入报告／完成 Tick、解锁报告卡并记录结构化事件。UI 不提交报告文字、完成 Tick、首工 ID 或稳定时长。

## 3. 第 6 章权威条件

终章只复用已有能力，不建立新的行为树或任务系统：

1. **首工历史**：稳定首工 ID 仍指向工蚁，羽化 Tick 合法，且已留下育幼护理记录。
2. **关键干预**：前五章已经记录遮光护理、首次营养交换、垃圾托盘清理、补水响应和功能分区。
3. **最终布局**：双室巢已连接，育幼室舒适且有补水模块，两室已发现，蚁后与当前幼体位于育幼室，食物／废物路径可达。
4. **长期模式**：上述条件持续达到冻结 `finale_stable_ticks`，且没有进行中的核心迁巢。护理、觅食和清洁可以继续可见，不要求画面静止。

报告完成状态要求 `completed_chapter_count == 6`、第六条推论、报告卡、报告 Tick 与完成 Tick 严格一致。快照中的报告字段、卡片数组或推论数组被修改时不会改变内部权威。

## 4. 季度存档迁移

当前 schema 为 `r12.authority.v10`，游戏版本为 `0.12.0-dev`。

R11→R12 迁移：

- 冻结终章稳定窗口与报告卡 ID；
- 写入初始终章稳定计数和未生成报告 Tick；
- 已完成 R11 五章的 Act 1 档案恢复为第 6 章活动状态；
- 保留双室、连接、实体、任务、资源、事件与前五章历史；
- 不伪造第 6 章证据、最后推论、报告卡或报告事件。

完整字段与不变量见 `docs/architecture/SAVE_SCHEMA_R12.md`。

## 5. 自动验证

标准 runner 新增 `tests/simulation/act1_finale_test_suite.gd`，并扩展真实场景路径，覆盖：

- 终章窗口与报告卡 ID 的启动时冻结；
- 稳定／不稳定最终布局的证据边界；
- 最后推论提交 Tick 不立即完成、下一 Tick 生成报告；
- 报告卡、结构化事件、首工历史主体和完成 Tick；
- 完成后继续使用既有糖液／蛋白环境干预；
- 报告快照、推论数组和卡片数组隔离；
- 第 6 章中途及完成后的存读往返；
- R11 五章完成档案进入第 6 章而非伪造报告；
- 1×、4×、16×在相同 Tick 产生相同终章快照；
- 真实观察手册最终推论、报告面板、继续观察和保存返回标题；
- 既有生命周期、湿度、营养、设施、迁巢、快照、存档和 10,000 Tick 所有权回归。

最终标准结果：

```text
PASS: 37900 project assertions
```

独立 `tests/performance/act1_144k_soak.gd` 结果：

```text
R12_SOAK_PASS
ticks=144000
start_tick=46
end_tick=144046
avg_tick_us=385.74
p95_tick_us=591
max_tick_us=2489
elapsed_s=63.076
static_memory_bytes=34035784
save_bytes=30431
signature=2fd15ac67d8a3aab5906e37719d5a72585a91a3d1c374a837aadf76b89833352
```

脚本每 1,000 Tick 检查有限环境值、非负资源、报告完成状态和单一所有权，周期提交既有补给／清理动作，并在 72,000 Tick 后执行实际 Envelope 存读与签名比较。该证据只覆盖当前小型六章档案，不代表 R16 的 60～80 工蚁最大规模已经通过。

## 6. 实际运行命令

| 命令 | 结果 | 退出码 |
| --- | --- | ---: |
| `Godot_v4.7.1-stable_win64_console.exe --version` | 精确版本 `4.7.1.stable.official.a13da4feb` | 0 |
| `Godot_v4.7.1-stable_win64_console.exe --headless --editor --path . --quit` | 编辑器解析和资源导入通过 | 0 |
| `Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd` | 37,900 条项目断言通过 | 0 |
| `Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/performance/act1_144k_soak.gd` | 144,000 Tick、中点存读与签名检查通过 | 0 |
| `Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 30` | 默认应用外壳冒烟通过 | 0 |
| `Godot_v4.7.1-stable_win64_console.exe --headless --path . --scene res://scenes/main/act1_test_tube.tscn --quit-after 30` | 正式 Act 1 场景冒烟通过 | 0 |
| 非 headless OpenGL Compatibility 1280×720 终章手册捕获 | NVIDIA 渲染成功 | 0 |
| 非 headless OpenGL Compatibility 1280×720 报告捕获 | NVIDIA 渲染成功 | 0 |

## 7. 1280×720 人工窗口检查

已检查：

- 第 6 章标题、四项目标、四条当前章证据和三条最终推论在手册内清晰可读；
- 最终推论按钮无需穿过前五章全部证据，滚动区和“返回观察”按钮没有重叠；
- “玻璃观察报告”标题、首工／设施／迁巢／喂食／清理摘要和结论可辨；
- “继续自由观察”与“保存档案并返回标题”两个按钮在 1280×720 同时可见；
- 报告面板外仍能辨认双室巢、工蚁和现有工具，F3 保持关闭；
- 画面由真实 `GameSnapshot`、报告状态和现有实体投影产生，没有用 Tween 伪造完成行为。

检查图保存在仓库外：

```text
G:/codexhome/visualizations/2026/07/22/019f8830-a4b5-71b1-940a-989119858217/r12_finale_journal_1280.png
G:/codexhome/visualizations/2026/07/22/019f8830-a4b5-71b1-940a-989119858217/r12_report_1280.png
```

## 8. 差异自审

- `CampaignState.Chapter`、推论和 `ObservationEvent.Type` 只在枚举末尾追加，旧数值不漂移。
- 第 6 章复用现有 `SELECT_CAMPAIGN_INFERENCE_ACTION`，没有增加通用命令或事件总线。
- 报告文字只从快照排版；模拟只保存稳定 ID、证据、卡片和 Tick。
- 自审发现终章若要求全部工作任务连续空闲，会让正常清洁行为阻断结局；已收紧为只要求核心迁巢结束，使护理／觅食／清洁仍可观察。
- 1280×720 初检发现终章手册列出前五章全部证据，推论按钮过深；已改为普通手册只显示当前章证据，权威历史仍完整保存。
- 新报告事件已加入存档解码白名单并由完成存读测试覆盖。
- 没有修改固定 Tick、生命周期参数、引擎版本、生产依赖或用户未跟踪文件 `DEVELOPMENT_PLAYBOOK.md`。

## 9. 已知限制与外部 Gate

- 当前六章使用未经科学审校的原型物种、环境与节奏参数。
- R12 要求的 10 个首次完整档案、中位 180～240 分钟、至少 7/10 完成率尚无外部数据，Gate 保持 `INCOMPLETE`。
- v0.2 要求的 7 名有效首次接触测试者数据仍未提供，Gate 同样保持 `INCOMPLETE`；用户允许继续开发不等于通过。
- 第 3～6 章的无讲解设施理解度和实际章节时长仍待外部验证。
- 正式美术、音频、最终英文审校、资产许可终审、发行标签与商店交付尚未完成。
- 合并 `main`、创建 Tag、发布 GitHub Release 或商店发布仍需另行明确授权。
