# v1 R6 Act 1 试管前两章验证记录 001

> 分支：`feat/v1-act1-test-tube`
> 日期：2026-07-28
> 引擎：Godot `4.7.1.stable.official.a13da4feb`
> 外部首次接触 Gate：`INCOMPLETE`

## 1. 范围

本轮只交付 R6“第 1～2 章内容”的技术候选：

- 新档案进入正式 `act1_test_tube` 场景；
- 第 1 章的遮光动作、蚁后护理、蛹观察、证据、推论和微型喂食口解锁；
- 第 2 章的稳定首工、首次糖液、觅食返巢、分享、育幼、证据、推论和小型觅食盒解锁；
- `Act1State`、`FoundingCareSystem`、`Act1CampaignDirector` 与只读 `Act1Snapshot`；
- `Act1TestTubeView` 的稳定实体映射、快照进度位置、糖液携带标记和减少动效；
- `r6.authority.v4` 存档、R5→R6 迁移和旧组合档案场景路由；
- 中文与临时英文玩家文案；
- 正式场景、模拟、存档、外壳和双分辨率布局回归。

没有实现设施摆放、镜头、蛋白放置 UI、后四章、正式素材、音频、Steam 或第三方插件。

## 2. 权威更新顺序

```text
验证连续 Tick
→ 写入当前 Tick
→ 应用遮光／糖液／推论等待处理命令
→ 推进生命周期
→ 校验并推进搬运／觅食／育幼任务
→ 按章节门控分配新任务
→ FoundingCareSystem 更新蚁后护理与证据
→ Act1CampaignDirector 更新章节、提示和解锁
→ 校验所有权、营养守恒、Act1 与章节不变量
→ 创建深复制 GameSnapshot
→ 控制器与 View 投影
```

## 3. 自动覆盖

`tests/simulation/act1_test_tube_test_suite.gd` 覆盖：

- 冻结配置与初始稳定实体；
- 遮光命令下一 Tick 生效；
- 蚁后护理循环和蛹证据；
- 首工在原实体 ID 上羽化；
- 两章正确／错误推论与设施解锁；
- 糖液、营养交换和育幼证据；
- 相同输入的确定性；
- 快照隔离；
- 1×／4×／16× 同 Tick 等价；
- 任务中存读等价；
- 10,000 Tick 所有权与守恒 soak。

`tests/scenes/act1_test_tube_scene_test_suite.gd` 通过真实按钮完成：

```text
开始观察
→ 安装遮光套
→ 第一章证据
→ 手册推论
→ 首工羽化
→ 放置糖液
→ 工蚁觅食、分享与育幼
→ 第二章推论
→ 完成
→ 继续观察并保持完成面板关闭
```

场景套件还检查同一个 `AntView`、暂停与插值、F3 和 1280×720／1920×1080 关键操作布局。外壳套件确认新档进入 Act 1，旧组合档案仍进入旧场景。

## 4. 实际执行结果

| 命令或检查 | 结果 | 退出码 |
| --- | --- | ---: |
| `Godot_v4.7.1-stable_win64_console.exe --version` | `4.7.1.stable.official.a13da4feb` | 0 |
| `--headless --editor --path . --quit` | 项目扫描、脚本类注册与场景解析通过 | 0 |
| `--headless --path . --script res://tests/test_runner.gd` | `PASS: 36447 project assertions` | 0 |
| `--headless --path . --quit-after 30` | 默认应用外壳冒烟通过 | 0 |
| `--headless --path . --scene res://scenes/main/act1_test_tube.tscn --quit-after 30` | 正式 Act 1 场景冒烟通过 | 0 |
| 非 headless OpenGL 运行与渲染帧捕获 | 1280×720、1920×1080 捕获成功 | 0 |
| `git diff --check` | 通过 | 0 |

## 5. 人工画面审阅

使用实际非 headless OpenGL 运行并人工审阅运行时渲染帧：

- 1280×720 准备门：标题、三项目标、说明和“开始观察”完整可读，背景遮罩清楚，无控件越界。
- 1280×720 第 1 章：完整试管、储水端、棉端、遮光套、蚁后、两枚卵和晚期蛹可辨；目标、证据和工具栏无重叠。
- 1280×720 第 2 章携带状态：F3 关闭；首工与蚁后尺寸差异明确，返巢工蚁旁的糖滴光点由 `carried_portions` 快照派生并随工蚁位置显示。
- 1920×1080 准备门：居中遮罩、主画面、侧栏与底部工具栏保持比例，无截断或越界。

Windows 桌面复制接口对 OpenGL 窗口返回了黑帧，因此证据改由同一非 headless 运行的 Godot MovieWriter／Viewport 直接捕获；没有把黑帧记为通过。1920×1080 的活动中章节没有另行人工逐帧审阅，活动布局由场景自动测试覆盖。

临时捕获脚本已删除，渲染帧保存在仓库外的 Codex 可视化目录，不进入版本控制。

## 6. 已知限制与 Gate

- R6 的真实按钮因果闭环已自动完成，但当前是压缩节奏候选；尚未由 5～7 名新玩家证明 35～60 分钟目标。
- v0.2 要求的 7 名有效首次接触测试者数据未提供，外部理解度 Gate 保持 `INCOMPLETE`。用户允许跳过该阻塞继续开发，不等于 `PASS`。
- 正式 Act 1 只开放糖液；蛋白放置属于后续内容。
- 微型喂食口与小型觅食盒目前只以稳定设施 ID 解锁；没有摆放、旋转、接口或环境效果。
- 玩家可见英文仍是临时翻译，尚未人工终校。
- 正式美术、音频和后四章尚未实现。

## 7. 最终 diff 自审

- 没有修改 0.1 秒固定 Tick、Godot 版本或 Species_A 生命周期参数。
- UI 与 View 只读快照；没有取得 `ColonyState`、`QueenModel` 或 `AntModel` 引用。
- 蚁后护理与章节使用小型显式系统，没有加入任务 DSL、行为树、ECS 或事件总线。
- 糖滴携带标记直接读取快照携带量和插值位置，没有使用脱离模拟的 Tween。
- 旧组合档案通过 `scenario_id` 路由原场景；R5 迁移不会伪造 Act 1 状态。
- `DEVELOPMENT_PLAYBOOK.md` 保持未读、未修改、未暂存。
- Godot 可执行文件、`.godot/`、日志、构建、临时捕获脚本和运行帧未进入版本控制。
- 合并 `main`、Tag、GitHub Release 和商店发布没有执行，仍需另行明确授权。
