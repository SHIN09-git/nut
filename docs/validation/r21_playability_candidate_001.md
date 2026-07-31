# R21 第 1～2 章可玩性 Windows 候选验证记录 001

日期：2026-07-31

候选分支：`codex/feat/r21-playability-slice`

游戏载荷源码提交：`8fc25b9f4c69b82c78cc36b7b4b5c2b17dfb3957`

Godot：`4.7.1.stable.official.a13da4feb`

结论：R21 第 1～2 章技术候选完成本机自动、窗口、导出和隔离运行验证。
R21 的 5 人无讲解 Gate 没有真人数据，状态为 `INCOMPLETE`；没有新的明确
豁免时停止在 R21，不进入 R22。

R20 的 5 人行为辨认 Gate 已由用户于 2026-07-31 明确豁免为进入 R21 的前置
条件。该决定不等于 R20 通过，本记录也没有伪造 R20 或 R21 参与者证据。

## 1. 候选范围

本候选只增强现有第 1～2 章：

- 手册显示当前问题、干预前预测、前后对照和相对时间线；
- 第 2 章显示首工会话名称和最近行为历史；
- 糖液提供远端喂食口与近巢通道两项冻结高层选择；
- 近巢路线较短，但下一 Tick 放置时会重置蚁后当前护理循环；
- 首工羽化、首次糖液采集／分享和章节完成在高倍速下切回 1×；
- 近巢扰动使用事件和模拟 Tick 驱动显示反馈。

没有修改固定 Tick、生命周期参数、章节 3～6 内容、权威存档 schema、设施
目录、正式资产、音频、Steam 或外部依赖。预测、首工名称和实验基线属于会话
注释，不进入权威存档；已越过干预点的旧档不会被缺失预测倒退阻塞。

## 2. 模拟与命令边界

糖液按钮只提交 `feeding_port` 或 `near_nest`。`ColonySimulation` 在提交时
验证冻结白名单，命令进入原队列，并在下一连续固定 Tick 开始时由冻结
`HabitatScenarioConfig` 解析为区域。UI 不提供区域 ID、份数、路程或扰动量。

近巢选择在糖液源成功创建后调用既有 `FoundingCareSystem` 的明确扰动入口，
只把护理状态重置到休息起点并记录事件。远端选择不改变护理循环。两个新事件
追加在既有枚举末尾，旧数值和 `r12.authority.v10` schema ID 保持不变；待处理
糖液选择复用已有命令记录的 `argument_id` 字段。

## 3. 自动验证

在仓库根目录实际运行：

| 检查 | 结果 | 退出码 |
| --- | --- | ---: |
| `Godot_v4.7.1-stable_win64_console.exe --version` | `4.7.1.stable.official.a13da4feb` | 0 |
| `--headless --editor --path . --quit` | 最终解析干净，无脚本或资源错误 | 0 |
| `--headless --path . --script res://tests/test_runner.gd` | `PASS: 41481 project assertions`，最终日志无错误 | 0 |
| `--headless --path . --quit-after 30` | 默认标题外壳和主场景冒烟通过 | 0 |
| `--headless --path . --script res://tools/release/generate_godot_notices.gd` | 精确 4.7.1 许可副本生成 | 0 |
| `--headless --export-release "Windows Desktop" ...` | Windows x86_64 release 导出完成 | 0 |
| 解压后的候选 EXE `--headless --quit-after 30` | 隔离 `APPDATA`／`LOCALAPPDATA` 运行通过 | 0 |

新增回归覆盖：

- 一章一个不可覆盖的干预前预测和基线；
- 已有进度不因会话预测缺失而倒退；
- 任意区域／选择 ID 被拒绝；
- 糖液选择提交当下不改变权威状态，下一 Tick 使用冻结配置；
- 源 Resource 在模拟创建后被修改，不改变目标区域；
- 待处理选择通过严格存档重建；
- 近巢选择打断护理，远端选择不打断；
- 选择数组和已选 ID 的快照隔离；
- 真实手册预测、首工命名、糖液下拉框、下一 Tick 和扰动事件路径；
- 首工关键事件自动恢复 1×；
- 新章节手册从问题顶部打开，不继承旧滚动位置。

验证过程中曾出现一次“断言总数通过但 `%Scroll` 未登记为唯一节点”的日志
错误。该次运行不计作通过；场景节点登记修正后重新执行完整测试，最终
41,481 项断言与日志均干净。

## 4. 1280×720 人工窗口检查

实际启动：

```text
Godot_v4.7.1-stable_win64.exe --path E:\GAME --resolution 1280x720 res://scenes/main/act1_test_tube.tscn
```

窗口客户区为 1280×720，简体中文、100% UI、开发 F3 关闭。检查结果：

- Tick 0 准备门、普通观察、侧栏和情境操作栏无重叠；
- 第 1 章遮光按钮在预测前禁用，记录预测后立即解除门控且不残留旧提示；
- 手册问题、三项预测、前后对照和时间线在滚动区内可达；
- 16× 下首工关键事件出现后自动切回 1×，首工在原节点上可见；
- 第 2 章手册从当前问题和预测顶部打开，不继承第 1 章滚动位置；
- 远端／近巢两项糖液说明在情境栏可读；
- 选择近巢并放置后，糖液落点与护理扰动圆环在普通画面可见；
- 首工会话命名与最近行为历史在手册中可读；
- 未打开检查器也能看见蚁后、首工和近巢干预反馈。

本次未重新检查英文、125%／150% UI、1920×1080 或完整第 3～6 章窗口流程；
这些不属于本 R21 垂直切片的新增显示范围，既有自动回归继续通过。

## 5. Windows 候选与哈希

候选目录：

```text
E:\GAME\builds\windows_r21_playability_candidate_8fc25b9
```

| 文件 | bytes | SHA-256 |
| --- | ---: | --- |
| `ColonyUnderGlass_R21_playability_candidate_8fc25b9.exe` | 109071360 | `04baf75cc1d69dd93eb709533ecab4fd7770bb8a530645717017a06a9d9809fc` |
| `ColonyUnderGlass_R21_playability_candidate_8fc25b9.pck` | 7940436 | `ab1a1356c5ddcba5192651129e86c1a53df034c122bb476ddbff154514051e96` |
| `CREDITS.txt` | 1377 | `c66e03e9e7b8c22fd5c897deb6c58635352bce7e0c279a2af4e45841d584faac` |
| `PRIVACY.txt` | 1543 | `cf1dbba6db6d56b5b6faf1888d3cff0749ead4a60aaf48942c783bdbda0fb4d8e` |
| `THIRD_PARTY_NOTICES.txt` | 98986 | `fff8a198590dfe153ab88260ecf40b09e74265fb608a781d0d422f615ef48bc2` |

冻结 ZIP：

```text
E:\GAME\builds\ColonyUnderGlass_R21_playability_candidate_8fc25b9_windows_x86_64.zip
bytes=43612344
sha256=59558c5b9bc88ad30434b623064ea0bec696817a38e58bee30568d048ac0b03d
```

ZIP 恰好包含上表 5 个根文件。隔离运行目录为：

```text
E:\GAME_R21_PLAYABILITY_RUNTIME_8fc25b9
```

PCK 字符串检查未发现 `res://tests/`、`res://tools/`、`res://docs/`、
`res://sucai/`、`res://scenes/debug/` 或旧 `scenes/main/main.tscn`；同时确认
档案有效时长载荷仍存在。`builds/` 与隔离目录不进入 Git。

## 6. 外部步骤与停止条件

按 `docs/playtest/R21_PLAYABILITY_PROTOCOL.md`：

1. 预登记本 ZIP、哈希、源码提交和参与者顺序；
2. 招募至少 5 名有效首次接触玩家；
3. 全程无讲解，保留逐人时间线、录屏或操作日志；
4. 记录卡住、误解、跳过、主观感受和逐字回答；
5. 只在协议中全部 Gate 阈值满足时写 `PASS`。

当前没有参与者数据，因此 R21 Gate 为 `INCOMPLETE`。没有真实 `PASS` 或新的
明确豁免时，不进入 R22，不扩写第 3～6 章，也不讨论合并 `main`、Tag、
GitHub Release 或商店发布。

## 7. 最终 diff 自审

- 修改集中在 R21 第 1～2 章实验记录、冻结糖液取舍、事件反馈、会话注释、
  本地化、测试和文档。
- 没有修改生命周期 `.tres`、固定 Tick、章节 3～6 条件、设施／环境参数、
  权威存档 schema ID、引擎版本或生产依赖。
- 新枚举只在末尾追加；旧事件数值不变。
- 普通 UI 只读快照与会话注释；糖液区域和扰动规则由模拟冻结配置决定。
- 没有新增行为树、ECS、事件总线、正式素材、玩法货币或无关重构。
- `DEVELOPMENT_PLAYBOOK.md` 保持用户自有、未读取、未修改、未暂存。
- R20 豁免、R20 未通过、R21 候选完成和 R21 Gate 未完成四种状态分别记录，
  没有把本机验证写成真人证据。
