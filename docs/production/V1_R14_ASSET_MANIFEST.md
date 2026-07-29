# v1 R14 原创视觉资产清单

状态：生产中

## 视觉原则

- 暗色桌面、暖色观察灯、冷色玻璃反光构成统一基调。
- 蚁群、幼体、设施和环境线索必须优先服务观察可读性。
- 关键状态同时使用轮廓、材质或符号，不只依赖颜色。
- 不复制参考游戏、视频、商家产品或 `sucai/` 中图片的具体造型。
- 所有正式视觉资产必须在 `asset_ledger.csv` 中登记为
  `approved_production` 后才能进入发行导出。

## 生产包

| 稳定资产 ID | 仓库位置 | 用途 | 完成条件 |
| --- | --- | --- | --- |
| `r14_title_observation_desk` | `assets/production/backgrounds/title_observation_desk.png` | 标题、档案和设置外壳背景 | 16:9 双分辨率裁切安全；菜单文字保持清晰 |
| `r14_ant_lifecycle_procedural` | `scripts/view/ant_view.gd` | 卵、幼虫、蛹、工蚁 | 四阶段轮廓、明暗和比例均可独立辨认 |
| `r14_queen_procedural` | `scripts/view/queen_view.gd` | 蚁后 | 腹、胸、头、足、触角和工蚁尺寸差异清晰 |
| `r14_act1_environment_procedural` | `scripts/view/act1_test_tube_view.gd` | 试管、玻璃、棉、水、基质、凝水和污染 | 不遮挡实体；环境状态仍由快照驱动 |
| `r14_facility_set_procedural` | `scripts/view/facility_layout_view.gd` | 十二类目录设施与连接件 | 每类具有独立轮廓和材质符号；旋转仍可读 |
| `r14_chapter_markers` | `scripts/view/chapter_art_view.gd` | 六章观察手册章节标记 | 当前、完成和未来章节使用形状、亮度与独立图案区分 |
| `r14_observation_report_seal` | `scripts/view/observation_report_seal_view.gd` | 结局观察报告印记 | 六章完成节点与蚁群轮廓形成原创报告识别符 |
| `r14_shell_materials` | `scenes/app/game_shell.tscn` | 标题、档案、设置和确认页 | 面板、焦点和状态文字满足 R13 可用性基线 |
| `r14_game_materials` | `scenes/main/act1_test_tube.tscn` | 六章主界面 | 普通界面层级清晰；F3 关闭时玩法可读 |

## 明确不进入 R14

- 音乐、环境音和效果音：由 R15 单独处理。
- 第二物种、战斗、自由挖洞或新设施。
- 商店胶囊图、预告片和平台截图：由 R16 从已批准资产派生。
- 未知来源字体、照片、搜索结果或 `sucai/` 参考图。

## 验收矩阵

- 1280×720 与 1920×1080。
- 100% 与 150% UI 缩放。
- 正常动效与减少动效。
- F3 关闭。
- 标题页、主场景、布局模式、终章报告。
- 生产资产路径、SHA-256、生成提示、许可来源和审批状态完整。
