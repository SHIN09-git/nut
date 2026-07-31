# R20 无说明行为辨认 Windows 候选验证记录 001

日期：2026-07-31

候选分支：`codex/test/r20-behavior-recognition-candidate`

游戏载荷源码提交：
`3db35e8b29b5642b3fb573e23ff9d784f565519b`

Godot：`4.7.1.stable.official.a13da4feb`

结论：R20 行为辨认候选已冻结并通过本机技术验证；5 名真人样本尚未提供，
R20 行为辨认 Gate 为 `INCOMPLETE`。

## 1. 范围与结论边界

本包不修改游戏载荷、模拟、存档、UI、资产或节奏。载荷与已经人工检查的
R20-F 提交完全相同；本轮只增加：

- 一个不向参与者泄露目标行为的预登记协议；
- 一个逐项 CSV 空白模板和一个汇总空白模板；
- 一份由精确 Godot 4.7.1 Export Templates 导出的 Windows 候选；
- 候选哈希、隔离冒烟和发行剥离记录；
- README 与路线图中的证据入口和停止边界。

用户允许跳过早先“7 名有效首次接触测试者”作为继续开发的阻塞，不等于
R20 独立的 5 人行为辨认 Gate 已通过，也不自动授权进入 R21。本记录没有
伪造参与者、回答、录屏、识别分数或 Gate 结论。

合并 `main`、创建 Tag、GitHub Release、商店或公开发布均未执行，仍需另行
明确授权。

## 2. 无说明流程

协议：

`docs/playtest/R20_BEHAVIOR_RECOGNITION_PROTOCOL.md`

空白模板：

- `docs/playtest/r20_behavior_recognition_results_template.csv.example`
- `docs/playtest/r20_behavior_recognition_summary_template.md`

协议冻结以下规则：

- 测试前预登记顺序，主要分析只取前 5 名有效参与者；
- 无效样本保留原因并按顺序招募替补，不按成绩挑人；
- 参与者测试前看不到六种目标行为、评分规则、开发资料或其他答案；
- 每项判断必须有本次候选画面、时间码和逐字回答；
- 事后用稳定 ID `WALK`、`CARRY_BROOD`、`CARRY_FOOD`、
  `FEED_BROOD`、`CLEAN`、`MIGRATE` 编码；
- 每人识别至少 4/6，且前 5 名有效参与者至少 4 人达到门槛，才可写
  `PASS`；
- 有效样本不足 5 人时只能写 `INCOMPLETE`。

候选 ZIP 不放发行说明、行为列表、评分表或本协议。参与者目录只包含游戏
载荷和法律／隐私资料；记录员在候选目录外单独持有协议。

## 3. 实际验证

在仓库根目录实际运行：

| 检查 | 结果 | 退出码 |
| --- | --- | ---: |
| `Godot_v4.7.1-stable_win64_console.exe --version` | `4.7.1.stable.official.a13da4feb` | 0 |
| `--headless --editor --path . --quit` | 最终解析干净，无脚本或资源错误 | 0 |
| `--headless --path . --script res://tests/test_runner.gd` | `PASS: 41053 project assertions` | 0 |
| `--headless --path . --quit-after 30` | 默认标题外壳与主场景冒烟通过 | 0 |
| `--headless --path . --script res://tools/release/generate_godot_notices.gd` | 精确 4.7.1 许可副本生成 | 0 |
| `--headless --export-release "Windows Desktop" ...` | Windows x86_64 release 导出完成 | 0 |
| 解压后的 EXE `--headless --quit-after 30` | 隔离 `APPDATA`／`LOCALAPPDATA`，stderr 为空 | 0 |

项目测试没有新增断言，因为本轮没有修改运行时代码。此前 R20-F 的
10,000 Tick 最大规模验证、稳定签名、1280×720 真实首工路径和 16×窗口
检查继续适用于同一载荷，见
`docs/validation/r20_worker_emergence_pose_001.md`。

本轮没有重新执行精确 ZIP 的人工窗口操作，因此不能把它列为新增人工通过。
R20-E、R20-F 已对相同载荷完成 1280×720、中文 100%、F3 关闭的实际画面
检查；本候选的新增工作不包含显示改动。

## 4. 隔离运行与发行剥离

ZIP 解压并从下列仓库外目录运行：

```text
E:\GAME_R20_BEHAVIOR_RUNTIME_3db35e8
```

该目录使用自己的：

```text
E:\GAME_R20_BEHAVIOR_RUNTIME_3db35e8\APPDATA
E:\GAME_R20_BEHAVIOR_RUNTIME_3db35e8\LOCALAPPDATA
```

隔离 headless 进程退出码为 0，stderr 为空，没有读取或覆盖正常用户档案。

PCK 二进制标记检查确认以下内部内容不存在：

```text
res://tests/
res://tools/
res://docs/
res://sucai/
res://scenes/debug/
res://scenes/main/main.tscn
```

同时确认 `profile_playtime_state` 存在，表示正式档案有效时长能力仍在载荷
中。候选目录和 ZIP 位于已忽略的 `builds/`，没有进入 Git。

## 5. 冻结文件与哈希

候选目录：

```text
E:\GAME\builds\windows_r20_behavior_candidate_3db35e8
```

| 文件 | bytes | SHA-256 |
| --- | ---: | --- |
| `ColonyUnderGlass_R20_behavior_candidate_3db35e8.exe` | 109071360 | `04baf75cc1d69dd93eb709533ecab4fd7770bb8a530645717017a06a9d9809fc` |
| `ColonyUnderGlass_R20_behavior_candidate_3db35e8.pck` | 7914456 | `b05ea770e4c5b1fa59ef7afb45cab81174536baa330b79eb35cbe9c79264a609` |
| `CREDITS.txt` | 1377 | `c66e03e9e7b8c22fd5c897deb6c58635352bce7e0c279a2af4e45841d584faac` |
| `PRIVACY.txt` | 1543 | `cf1dbba6db6d56b5b6faf1888d3cff0749ead4a60aaf48942c783bdba0fb4d8e` |
| `THIRD_PARTY_NOTICES.txt` | 98986 | `fff8a198590dfe153ab88260ecf40b09e74265fb608a781d0d422f615ef48bc2` |

冻结 ZIP：

```text
E:\GAME\builds\ColonyUnderGlass_R20_behavior_candidate_3db35e8_windows_x86_64.zip
bytes=43591495
sha256=1d7c274748c048fcc972d09a85f380496a2fbceb59594f86b99bfcd1c4294432
```

ZIP 恰好包含上表 5 个根文件。它是内部无说明测试候选，不是已授权的公开
发布包。

## 6. 最终自审

- 首次编辑器解析发现普通 `.csv` 会被 Godot 当作翻译表导入并产生 locale
  警告；模板已改为 `.csv.example`，删除生成的 `.import` 后重新解析干净。
- 没有修改固定 Tick、模拟更新顺序、任务状态、所有权、存档 schema、章节
  条件、生命周期参数、节奏配置或引擎版本。
- 没有新增玩法、生产依赖、正式素材、测试专用运行时代码或发行插件。
- 协议不把目标动作作为参与者提示，评分只在测试后由逐字回答编码。
- 模板没有预填参与者或结果，不会把候选存在误写为 Gate 通过。
- `DEVELOPMENT_PLAYBOOK.md` 保持用户自有、未读取、未修改、未暂存。
- Git 最终只应包含协议、空白模板、验证记录、README 和路线图更新；构建、
  `.godot/`、隔离运行目录和本机配置不进入版本控制。

## 7. 剩余外部步骤

1. 按协议预登记并招募首批 5 名有效参与者。
2. 分发本记录哈希完全匹配的 ZIP。
3. 取得同意后在仓库外保留录屏，提交脱敏逐字答案和时间码。
4. 按冻结编码规则计算每人 4/6 与总体 4/5。
5. 只有真实结果满足门槛时，才把 R20 Gate 从 `INCOMPLETE` 改为 `PASS`。
