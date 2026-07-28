# v1 生产规格索引

状态：R1 完成候选

用户于 2026-07-28 明确要求跳过缺失的 7 人外测阻塞并继续完成游戏。这构成继续执行 `CODEX_V1_MASTER_PLAN.md` 的授权，但不表示外部 Gate 通过，也不代表用户已经逐条校对所有内容与英文文案。

## 冻结规格

| 交付 | 文件 | 后续主要使用里程碑 |
| --- | --- | --- |
| 六章内容矩阵 | `docs/design/V1_CHAPTER_CONTENT_MATRIX.md` | R4、R6、R10～R12 |
| 设施职责表 | `docs/design/V1_FACILITY_RESPONSIBILITY_TABLE.md` | R7～R11 |
| 失败与恢复规则 | `docs/design/V1_FAILURE_RECOVERY_RULES.md` | R2～R12 |
| 物种与参数审校计划 | `docs/research/V1_SPECIES_REVIEW_PLAN.md` | R1、R6、R15 |
| 资产与许可计划 | `docs/production/V1_ASSET_LICENSE_PLAN.md` | R13～R16 |
| 资产许可台账模板 | `docs/production/asset_ledger.csv` | R13～R16 |
| 性能与最大实体预算 | `docs/technical/V1_PERFORMANCE_BUDGET.md` | R2、R7～R16 |

## 已锁定决定

- 单档中位 210 分钟，可接受 180～240 分钟。
- 6 章、1 个物种、10 种核心设施。
- 单侧温区只有独立闭环 Gate 通过后才作为第 11 种设施。
- 工蚁正常目标 60、压力上限 80；不承诺数百只。
- 失败以可恢复环境问题为主，首发不做突然灭群或不可逆坏档。
- 固定 Tick、命令队列、配置冻结、稳定 ID、快照隔离和单一所有权继续作为架构硬约束。
- 正式资产默认原创／明确许可；`sucai/` 继续只作内部参考。
- 合并 `main`、Tag、GitHub Release 和商店发布仍需另行明确授权。

## 下一实现入口

R2 只实现版本化存档核心：

- 规范化状态 schema。
- 冻结配置包与哈希。
- 待处理高层命令持久化。
- 崩溃安全提交、轮换备份和加载隔离。
- 版本迁移与故障注入测试。

R2 不实现档案 UI、设施、章节内容、美术或音频。
