# v1 R1 生产规格锁定验证记录 001

日期：2026-07-28

分支：`docs/v1-production-plan`

基线：`release/v0.2-demo-candidate` / `9220fb1415d48f55224e33f03c387c7845f18dcb`

## 结论

R1 已把 v1 主计划拆分为可直接供后续里程碑使用的职责规格，并新增统一索引与资产许可台账模板。该分支只修改文档，不改变运行时代码、Resource、场景、测试、导出预设或 Godot 版本。

必需的 7 名有效首次接触测试者数据仍未提供，外部 Gate 保持 `INCOMPLETE`。用户于 2026-07-28 明确豁免它作为继续开发的前置条件；本记录不把豁免写成测试通过。

## 交付

- `docs/V1_PRODUCTION_SPEC_INDEX.md`
- `docs/design/V1_CHAPTER_CONTENT_MATRIX.md`
- `docs/design/V1_FACILITY_RESPONSIBILITY_TABLE.md`
- `docs/design/V1_FAILURE_RECOVERY_RULES.md`
- `docs/research/V1_SPECIES_REVIEW_PLAN.md`
- `docs/production/V1_ASSET_LICENSE_PLAN.md`
- `docs/production/asset_ledger.csv`
- `docs/technical/V1_PERFORMANCE_BUDGET.md`

同时更新 `CODEX_V1_MASTER_PLAN.md`、`ROADMAP.md` 和 `README.md` 的当前推进状态与链接。

## 锁定决定

- 6 章，目标中位 210 分钟，可接受 180～240 分钟。
- 1 个物种，10 种核心设施；温区为条件性第 11 种。
- 工蚁正常目标 60、压力上限 80。
- 失败以可恢复环境问题为主，不实现第一次误操作导致的不可逆坏档。
- R2 只做版本化存档核心，不提前实现档案 UI、设施或章节内容。
- 正式资产必须原创或具有明确商业发行与宣传权利；`sucai/` 保持内部参考。

## 一致性审查

- 六章矩阵与主计划 0～210 分钟时段一致。
- 设施职责与 10 个核心设施、条件温区边界一致。
- 设施命令继续遵守下一 Tick 原子应用、逻辑槽位和冻结配置。
- 失败恢复没有引入直接命令工蚁、免费资源经济或静默修复。
- 性能预算不承诺超过 80 只工蚁，且保持固定 Tick 与快照隔离。
- 科学审校明确区分事实、养护实践、游戏抽象和节奏参数。
- 许可计划明确阻止未授权参考素材进入发行包。

## 实际验证

| 命令或检查 | 结果 | 退出码 |
| --- | --- | ---: |
| `Godot_v4.7.1-stable_win64_console.exe --headless --editor --path . --quit` | 通过；加入 `docs/production/.gdignore` 后无资产台账导入警告 | 0 |
| `Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd` | `PASS: 3000 project assertions` | 0 |
| `Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 30` | 主场景冒烟通过 | 0 |
| `git diff --check` | 通过 | 0 |
| 规格索引中的 8 个交付路径 | 全部存在 | 不适用 |
| 运行时代码、Resource、场景、测试和导出预设 diff | 无 | 不适用 |
| `DEVELOPMENT_PLAYBOOK.md` | 未读取、未修改、未暂存 | 不适用 |

R1 没有画面或模拟变更，因此没有执行新的人工窗口检查。R1 基线 M5 的实际窗口流程记录在 `docs/validation/v0_2_m5_demo_candidate_001.md`。

## 风险

- 物种尚未最终确定，也未完成专家审校。
- 设施数量、章节时长和性能目标尚无 v1 实装数据。
- 资产尚未购买或制作，许可台账当前只有模板示例行。
- 7 人首次接触外测数据仍缺失。
- R2 必须先冻结规范化 schema 和权威跨系统 Tick 顺序，不能从文档直接推断可写对象图。
