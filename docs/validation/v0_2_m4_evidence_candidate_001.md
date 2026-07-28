# v0.2 M4 外测证据候选验证记录 001

日期：2026-07-28

分支：`test/v0.2-m4-evidence`

冻结源提交：`671928b880c2f178e4b5b1e28fa424b3eedf93d7`

来源分支：`fix/v0.2-m4-evidence-validity`

## 结论

R0-B 候选已从 R0-A 最终完整提交的干净独立 worktree 使用 release 模板导出。自动测试、编辑器解析、默认主场景冒烟、发行 EXE 冒烟、包内容复核及 1280×720 实际发行窗口流程均通过。

实际 release EXE 的标题不含 `DEBUG`；F3 在准备门、运行中、完成页和重新开始后的准备门均无可见效果。完整流程可以到达三条观察线索总结，重新开始回到准备门，随后正常退出。

本记录只证明候选构建可用于外测，不证明 M4 外部 Gate 已通过。7 名有效首次接触测试者的无讲解数据尚未取得，R0 当前结论仍为 `INCOMPLETE`，不得进入 M5。

## 干净来源

独立 worktree：

```text
C:\tmp\nut-r0b-freeze-671928b
```

构建前检查：

- `git rev-parse HEAD`：`671928b880c2f178e4b5b1e28fa424b3eedf93d7`
- detached HEAD 指向冻结提交。
- `git status --short`、`git diff` 与 `git diff --cached` 均为空。
- 导出后仅生成被忽略的 `.godot/` 本机缓存，版本控制状态仍无改动。

候选不包含 R0-B 后续新增的验证文档；玩家场景、规则、参数、文本与普通 UI 全部对应冻结源提交。

## 工具链

- Godot：`4.7.1.stable.official.a13da4feb`
- Export Templates：`4.7.1.stable`
- Windows release 模板：`windows_release_x86_64.exe`
- 模板文件尺寸：`109,212,160` 字节
- 导出预设：`Windows Desktop`
- 导出方式：`--export-release`
- PCK：独立文件，不嵌入 EXE

## 自动验证与导出

所有命令均在干净 worktree 根目录执行。

| 检查 | 精确命令 | 结果 | 退出码 |
| --- | --- | --- | ---: |
| 引擎版本 | `& 'E:\GAME\Godot_v4.7.1-stable_win64_console.exe' --version` | `4.7.1.stable.official.a13da4feb` | 0 |
| 编辑器解析 | `& 'E:\GAME\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit --log-file 'C:\tmp\nut-r0b-freeze-editor.log'` | 通过；无脚本错误 | 0 |
| 全量自动测试 | `& 'E:\GAME\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script 'res://tests/test_runner.gd' --log-file 'C:\tmp\nut-r0b-freeze-tests.log'` | `PASS: 2341 project assertions` | 0 |
| 默认主场景冒烟 | `& 'E:\GAME\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 30 --log-file 'C:\tmp\nut-r0b-freeze-smoke.log'` | 通过；无脚本错误 | 0 |
| release 导出 | `& 'E:\GAME\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop' 'C:\tmp\ColonyUnderGlass_R0B_671928b.exe' --log-file 'C:\tmp\nut-r0b-freeze-export.log'` | EXE 与独立 PCK 成功生成 | 0 |
| release EXE 冒烟 | `& 'C:\tmp\ColonyUnderGlass_R0B_671928b.exe' --headless --quit-after 30 --log-file 'C:\tmp\nut-r0b-release-smoke.log'` | 通过；无脚本错误 | 0 |

## 冻结构建清单

| 文件 | 尺寸（字节） | SHA-256 |
| --- | ---: | --- |
| `ColonyUnderGlass_R0B_671928b.exe` | 109,071,360 | `04BAF75CC1D69DD93EB709533ECAB4FD7770BB8A530645717017A06A9D9809FC` |
| `ColonyUnderGlass_R0B_671928b.pck` | 309,012 | `4C0AAA3985D33E782E32878C501C8750765FDDF2CD5FC796C94C6A300108DE85` |
| `ColonyUnderGlass_R0B_671928b.zip` | 38,234,613 | `C8100C6B0CEF7D8D9057021B12F49764C02D1B94AA9AB704CB94CBBBC8F20A3B` |

分发包只包含上表中的 EXE 与 PCK。将 ZIP 解压到独立目录后重新计算两个文件的 SHA-256，均与源文件完全一致。

构建产物保存在本机临时目录，不提交仓库。向所有正式测试者分发时必须使用同一 ZIP 哈希。

## 1280×720 实际 release 窗口检查

使用上表 EXE 直接启动 Windows 发行版，窗口内容为 1280×720；包含 1 像素边框和标题栏的桌面捕获尺寸为 1282×752。窗口标题为 `Colony Under Glass`，不含开发构建的 `(DEBUG)`。

通过真实鼠标和键盘输入完成：

1. 初次启动显示 Tick 0 准备门，三张观察卡均为中性锁定状态。
2. 准备门按 F3，无诊断层、调试文本或布局变化。
3. 点击开始观察，切换 16×，首工羽化后进入身份阶段。
4. 使用真实阶段按钮进入湿度阶段；第一次搬运后补水入口开放。
5. 真实点击三次补水，工蚁改变幼体分布，湿度观察卡解锁。
6. 进入糖水阶段，启用放置工具并在右侧觅食区落点。
7. 工蚁完成觅食反馈，第三张卡解锁并进入三条线索总结。
8. 运行中和总结页按 F3，均无诊断层、调试文本或布局变化。
9. 点击重新开始，回到 Tick 0 准备门；再次按 F3 仍无效果。
10. 使用正常窗口关闭操作退出；窗口和进程均正常结束。

检查结果：

- 关闭诊断层的真实 release 版仍可辨认蚁后、首工、幼体、搬运关系和糖水落点。
- 准备门、标题栏、栖息地、个体观察、观察卡、工具按钮和总结在 1280×720 下无重叠或截断。
- 完整真实 UI 路径、总结、重新开始和退出可完成。
- 本轮人工检查使用 16×缩短验证时间，不能替代新玩家 12～15 分钟有效首通时长证据。
- 桌面截图只用于本次人工检查，未写入仓库。

## 外测协议

- 无讲解脚本：`docs/playtest/v0.2_m4_unmoderated_script.md`
- 结果模板：`docs/playtest/v0.2_m4_results_template.md`
- 正式结果文件：取得数据后才创建 `docs/playtest/v0.2_m4_results_round_001.md`

第一名测试者开始前已在脚本中冻结样本有效性、完成、湿度因果、糖液往返分享、主动选择、主动命名并回忆、卡住和阻塞问题的统一判定口径。结果模板要求保留逐人计时、操作、介入和逐字回答，不能只记录汇总结论。

## 冻结规则与剩余人工步骤

从本候选开始，任何玩家 UI、规则、参数或文本改动都会使当前哈希失效，必须重新导出、重新计算哈希并新建 round；不同构建的数据不得混池。

用户仍需：

1. 招募并预登记 7 名有效的首次接触、未参与开发测试者。
2. 按冻结脚本进行无讲解试玩，不向参与者展示记录员部分或评分答案。
3. 保存逐人匿名原始计时、操作、介入与逐字回答；个人信息和原始录屏不进入仓库。
4. 使用结果模板形成 `v0.2_m4_results_round_001.md`，交由用户审阅。

正式 Gate 必须同时满足：

- 至少 5/7 完成。
- 至少 4/7 正确描述湿度因果。
- 至少 4/7 正确描述糖液往返与分享。
- 至少 3/7 主动选择工蚁。
- 至少 2/7 主动命名且能回忆行为。
- 无人因不知道下一步卡住超过 2 分钟。
- 无阻塞崩溃、无法启动、无法重开或无法退出。
- 完成者有效首通时长中位数为 12～15 分钟。

在这些外部数据取得并通过用户审阅前，不合并 `main`、不创建 Tag、不发布 GitHub Release、不进入 M5，也不声明 R0 完成。
