# v0.2 M5 Windows Demo 候选验证记录 001

日期：2026-07-28

分支：`release/v0.2-demo-candidate`

冻结运行时提交：`816995e51f82acb732144068f6dcaca7b76c99c0`

来源提交：`51142012af0d418eeed4e628ba1156dfe9ae15bf`

## 结论

M5 技术候选通过 3000 项自动断言、编辑器解析、默认主场景冒烟、Windows release 导出、release EXE 冒烟，以及 1280×720、1920×1080、窗口／全屏和中英文实际窗口检查。

实际 UI 路径从 Tick 0 准备门开始，依次完成首工观察、三次补水、无 F3 的幼体携带观察、糖水放置、返巢分享、三张观察卡总结、重新开始与退出。

这只证明候选可以分发和按当前路径完成。7 名有效首次接触测试者数据没有取得，外部 Gate 仍为 `INCOMPLETE`。用户于 2026-07-28 明确豁免该 Gate 作为继续开发的前置条件；本记录不把豁免写成 `PASS`。

## 范围

本轮只增加：

- 最小暂停菜单与明确退出路径。
- 1280×720、1920×1080、窗口／全屏切换。
- 简体中文与临时英文翻译资源。
- 应用外壳、显示设置和本地化测试。
- M5 导出与外测文档。

没有修改生命周期、湿度、搬运、觅食配置或固定 Tick 语义；没有加入存档、新玩法、正式素材、音频或第三方依赖。

## 工具链

- Godot：`4.7.1.stable.official.a13da4feb`
- Export Templates：`4.7.1.stable`
- 预设：`Windows Desktop`
- 导出：`--export-release`
- PCK：独立文件

## 自动验证

| 检查 | 命令 | 结果 | 退出码 |
| --- | --- | --- | ---: |
| 引擎版本 | `& '.\Godot_v4.7.1-stable_win64_console.exe' --version` | `4.7.1.stable.official.a13da4feb` | 0 |
| 编辑器解析 | `& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit` | 通过；无脚本错误 | 0 |
| 全量自动测试 | `& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script 'res://tests/test_runner.gd'` | `PASS: 3000 project assertions` | 0 |
| 默认主场景冒烟 | `& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 30` | 通过；无脚本错误 | 0 |
| Windows release 导出 | `& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop' 'builds/windows/ColonyUnderGlass_v0.2_demo.exe'` | EXE 与 PCK 生成 | 0 |
| release EXE 冒烟 | `ColonyUnderGlass_v0.2_demo.exe --headless --quit-after 30` | 通过；无脚本错误 | 0 |

自动套件新增覆盖：

- 暂停菜单冻结和恢复模拟。
- 重开返回 Tick 0 准备门。
- 明确退出信号。
- 两档分辨率、全屏请求和语言状态。
- 1280×720、1920×1080 暂停菜单布局边界。
- 翻译键唯一、双语非空、翻译资源加载和运行时即时切换。
- 暂停、显示和语言切换不改变权威模拟结果。

## 构建清单

| 文件 | 字节 | SHA-256 |
| --- | ---: | --- |
| `ColonyUnderGlass_v0.2_demo.exe` | 109,071,360 | `04BAF75CC1D69DD93EB709533ECAB4FD7770BB8A530645717017A06A9D9809FC` |
| `ColonyUnderGlass_v0.2_demo.pck` | 5,132,288 | `62EA6B8FA7379A56BCB424270D56C96D15DA7CA3F6E212ED64D45540963A3D2C` |
| `ColonyUnderGlass_v0.2_demo.zip` | 41,078,537 | `D4FAC61CDC549AEF76EE630D6AC7D983487561F2A93CEE216D1E363A29E29CBF` |

ZIP 只包含 EXE 与 PCK。`builds/` 被 Git 忽略。

## 实际 Windows 窗口检查

直接启动冻结提交导出的 release EXE，使用真实鼠标和键盘完成。

### 1280×720

- Tick 0 准备门、三张中性观察卡、栖息地、个体面板和底部说明没有重叠。
- 开始后标题栏菜单可点击，暂停遮罩完整显示继续、重开、显示、语言和退出。
- 暂停保持两秒，模拟和视觉没有继续推进。
- 简体中文布局通过。
- 切换临时英文后首次发现“Window Resolution”挤压选项；扩大暂停面板与标签／选项最小宽度后重新导出，英文布局复查通过。

### 1920×1080 与全屏

- 从真实暂停菜单切换到 1920×1080，主场景与菜单无截断或重叠。
- 全屏打开后布局完整；关闭全屏返回 1920×1080 窗口。
- 英文和简体中文均即时刷新，不推进模拟。

### 完整流程

1. 从准备门开始。
2. 等首工羽化并自行选择该工蚁。
3. 点击“继续观察环境”进入湿度阶段。
4. 切换 16×；在关闭 F3 的普通视图中清晰看见工蚁携带幼体。
5. 通过真实育幼室补水按钮提交三次补水，每次由后续固定 Tick 应用。
6. 看见工蚁重新评估并改变幼体分布，湿度观察卡解锁。
7. 启用糖水工具并点击右侧觅食区。
8. 看见糖水采集、返巢和分享，进入三张观察卡完成的总结。
9. 点击重新开始，返回 Tick 0 准备门。
10. 按 `Esc` 打开暂停菜单并点击退出；窗口正常关闭。

release 中没有显示 F3 调试入口，人工流程也没有使用 F3 完成判断。

## 最终 diff 审查

- 模拟状态、配置 Resource、生命周期参数和固定 Tick 逻辑未修改。
- 新状态只属于应用设置；没有形成第二套模拟事实来源。
- 玩家文本集中到翻译资源；英文标记为临时文本。
- 没有提交 `builds/`、`.godot/`、日志、Godot 可执行文件、本机配置、凭据或 `sucai/`。
- 没有触碰用户未跟踪的 `DEVELOPMENT_PLAYBOOK.md`。
- 没有加入新玩法、存档、正式素材、音频、插件或无关重构。

## 未通过与未执行

- 7 名有效首次接触测试者数据：未提供、未执行、未通过；仅由用户豁免为前置条件。
- 临时英文最终用户校对：未执行。
- `main` 合并、Tag、GitHub Release、商店发布：未授权、未执行。
