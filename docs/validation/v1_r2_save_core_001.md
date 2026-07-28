# v1 R2 版本化存档核心验证记录 001

日期：2026-07-28

分支：`feat/v1-save-core`

基线：`docs/v1-production-plan` / `237da6029134e2d939b6cac76f685899fe99a73e`

## 结论

R2 已实现可由 R3 档案外壳调用的版本化存档核心。它能在合法固定 Tick 边界捕获当前生命周期、搬运或觅食权威状态，保存暂停／倍速和有序待处理命令，使用档内冻结配置重建新会话，并通过规范化 checksum、内容清单、严格类型／数值／ID／所有权校验拒绝损坏或不兼容数据。

磁盘路径只允许安全的 `user://` 相对文件；提交使用已验证临时文件、主档和备份。故障注入证明“临时写完后”和“备份轮换后”中断仍能恢复最近一次完整提交。

R2 没有接入新游戏、继续、保存、加载、恢复或删除 UI，也没有保存 View、名称、选择或显示设置。这些仍属于 R3。

## 实现边界

- `SimulationClock.restore_save_boundary()` 只恢复 Tick、1×／4×／16×和暂停；累积器归零。
- `ColonySimulation` 用内部 Tick 执行标记拒绝中途捕获；命令队列改为带单调 sequence 的白名单高层意图。
- `SimulationStateCodec` 编码实际冻结值和纯权威状态；加载从档内值重建临时强类型 Resource，不读取当前 `.tres`。
- `SaveGameService` 负责 Envelope、规范化 SHA-256、4 MiB 上限、内容清单、迁移和磁盘事务。
- `r2.authority.v0 → r2.authority.v1` 测试迁移把旧命令类型数组转换为带 sequence 的记录，并补充命令 next ID；迁移不修改输入。仓库保留固定旧档 `tests/fixtures/save/r2_authority_v0_lifecycle.json`。
- 精确字段和恢复顺序见 `docs/architecture/SAVE_SCHEMA_R2.md`。

## 自动覆盖

- 规范化编码不受 Dictionary 插入顺序影响，拒绝 NaN。
- 组合场景在幼体搬运任务中途存读等价，并与未中断轨迹连续 400 Tick 逐 Tick 一致。
- 生命周期独立场景存读等价。
- 有待处理命令时保存；加载不提前消费，在下一合法 Tick 恰好应用一次。
- Tick 执行期间的同步保存请求被拒绝，Tick 成功后立即可保存。
- 暂停、1×、4×、16×元数据正确恢复，相同 Tick 的模拟结果不变。
- 修改源 Resource 后，旧档仍使用档内补水量和舒适范围。
- checksum、冻结配置哈希、内容清单、未来 schema、未知命令、越界湿度、路径穿越和截断 JSON 被拒绝。
- 失败加载不改变活跃模拟；修改 Envelope 或加载结果副本不能反写恢复后的权威状态。
- 首次保存、第二次保存、主档优先、损坏主档回退备份均通过。
- 两个故障注入点都至少保留一个可加载的完整旧档或新候选。
- 完成状态加载后继续 10,000 Tick，无崩溃、NaN 或所有权错误。

## 实际验证

| 命令或检查 | 结果 | 退出码 |
| --- | --- | ---: |
| `Godot_v4.7.1-stable_win64_console.exe --version` | `4.7.1.stable.official.a13da4feb` | 0 |
| `Godot_v4.7.1-stable_win64_console.exe --headless --editor --path . --quit` | 脚本解析与编辑器导入通过，无脚本错误 | 0 |
| `Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd` | `PASS: 4333 project assertions` | 0 |
| `Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 30` | 默认主场景冒烟通过 | 0 |
| `git diff --check` | 通过 | 0 |

测试创建的 `user://r2_save_tests/` 临时主档、备份和临时文件已由套件按精确路径清理。仓库没有加入存档、日志、构建产物或本机配置。

## 人工验证

未执行新的 1280×720／1920×1080 窗口检查。R2 没有修改场景、布局、玩家输入或画面；存档尚未接入 UI。基线 M5 的实际窗口记录仍见 `docs/validation/v0_2_m5_demo_candidate_001.md`。

## 最终 diff 自审

- 没有修改 Godot 版本、固定 Tick 时长、生命周期／湿度／觅食 `.tres`、场景、View 或本地化资源。
- 没有预建章节、设施、营养、经济、云存档或通用序列化框架。
- 保存的是当前真实权威字段，不保存可重建快照或反向关系。
- 时间戳只作档案元数据；不参与模拟，也不推进离线时间。
- checksum 是损坏检测，不宣称反作弊或密码学身份认证。
- `DEVELOPMENT_PLAYBOOK.md` 保持未读取、未修改、未暂存。

## 已知限制与下一步

- 当前 Demo 没有玩家可见的档案 UI，也不会自动保存。
- 非主档恢复只在结果中返回来源；R3 必须明确提示玩家并提供恢复操作。
- `game_version` 只作展示；兼容性由 `format_version`、`state_schema_id` 和 `content_manifest_id` 决定。
- 会话注释和显示设置按设计不属于权威游戏档案；R3 另行决定独立设置文件和档案元数据。
- 7 名有效首次接触测试者数据仍未提供；外部 Gate 保持 `INCOMPLETE`，用户豁免只解除开发阻塞，不构成通过证据。
- 下一里程碑是 R3 档案与设置外壳。
