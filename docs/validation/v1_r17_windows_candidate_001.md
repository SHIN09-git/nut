# v1 R17 Windows 有效时长候选验证记录 001

日期：2026-07-29

分支：`codex/release/v1-r17-evidence-candidate`

发行源码提交：`68c533edf1c28cf2d01d0dc3794d7918db7228b5`

引擎：Godot `4.7.1.stable.official.a13da4feb`

结论：包含 R17 有效时长证据的本机 Windows 技术候选通过；外部首次
接触与完整档案 Gate 仍为 `INCOMPLETE`

## 结论边界

本记录只冻结已完成游戏的 R17 Windows x86_64 技术候选，不新增玩法、
设施、物种、模拟参数或依赖。用户允许跳过缺失的 7 名首次接触测试者数据
继续开发，但没有把该数据或 10 个首次完整档案写成通过。

以下操作仍未获授权、未执行：

- 合并 `main`；
- 创建 `v1.0.0` Tag；
- 创建 GitHub Release；
- 商店或公开发布。

## 候选变化

相对 R16，发行玩法内容不变。本候选增加：

- 档案有效聚焦时长、逐章拆分和首次结局时长；
- 暂停／帮助／手册计入，标题／准备门／失焦排除；
- `SaveEnvelope` v2 和格式 v1 的显式历史缺口迁移；
- 档案页中的有效观察、当前章、首次结局和模拟历程；
- 更新后的 Beta 发布说明，明确计时证据不能替代外部样本。

## 最终源码验证

在发行源码提交上实际执行：

| 检查 | 结果 | 退出码 |
|---|---|---:|
| `Godot_v4.7.1-stable_win64_console.exe --version` | `4.7.1.stable.official.a13da4feb` | 0 |
| `--headless --editor --path . --quit` | 脚本、场景、资源与翻译导入解析通过 | 0 |
| `--headless --path . --script res://tests/test_runner.gd` | `PASS: 40455 project assertions` | 0 |
| `--headless --path . --quit-after 30` | 默认标题外壳与主场景冒烟通过 | 0 |
| `--headless --path . --script res://tools/release/generate_godot_notices.gd` | 精确 4.7.1 许可副本生成完成 | 0 |
| `--headless --export-release "Windows Desktop" ...` | Windows release 导出完成 | 0 |
| 导出 EXE `--headless --quit-after 30` | 隔离用户目录运行，无 stderr | 0 |

导出前后 Git 只有用户自有未跟踪的 `DEVELOPMENT_PLAYBOOK.md`；该文件
未读取、未修改、未暂存。`builds/`、`.godot/` 和隔离运行数据均不进入
版本控制。

本机旧版 Windows PowerShell 不支持 `Start-Process -Environment`，且
最初使用 `Copy-Item -LiteralPath` 通配符的预检没有复制文件；这两次预检
没有启动候选，不能算作运行验证。随后使用明确的六文件复制和
`.NET ProcessStartInfo` 子进程环境执行正式隔离冒烟，退出码为 0。

## 发行内容剥离

最终 PCK 二进制标记检查没有发现：

```text
res://tests/
res://tools/
res://docs/
res://sucai/
res://scenes/debug/
res://scenes/main/main.tscn
```

同一检查确认 `profile_playtime_state` 存在于 PCK。发行目录只有六个根
文件；ZIP 列表也恰好是这六个文件。

## 隔离与实际窗口流程

最终六文件候选复制到：

```text
E:\GAME_R17_PACKAGE_RUNTIME_68c533e
```

并以该目录下独立的 `APPDATA`／`LOCALAPPDATA` 运行 headless release
冒烟。结果为 Godot 4.7.1、退出码 0、stderr 为空。

发行窗口检查在先前草拟候选
`E:\GAME_R17_PACKAGE_RUNTIME_735bfa7` 上实际完成。其 EXE 与 PCK 的
SHA-256 和最终候选完全相同；最终候选只更新了包外
`RELEASE_NOTES.txt`，因此这次实际窗口检查对应相同可执行游戏载荷：

1. 标题页不显示 `DEBUG`，标题页和游戏内按 F3 均无效果；
2. 新游戏进入 Tick 0 准备门，点击“开始观察”后正常推进；
3. 暂停、保存并返回标题；
4. 档案页可见有效观察 `00:00:17`、本章 `00:00:17`、首次结局未记录和
   模拟历程 `00:13`；
5. “继续”恢复暂停中的同一档案；
6. 再次保存并返回标题，正常退出。

最终真实 UI 存档包含：

```text
format_version=2
state_schema_id=r12.authority.v10
simulation_tick=133
clock_paused=true
clock_speed=1
active_microseconds=24830360
chapter_active_microseconds[2]=24830360
completion_active_microseconds=-1
has_legacy_gap=false
```

源码窗口的中文 100%、中文 150% 和英文 150% 档案摘要检查，以及验证中
发现并修复的英文截断，记录在
`docs/validation/v1_r17_playtime_evidence_001.md`。最终
`RELEASE_NOTES.txt` 另外检查了 R17 档案摘要、`SaveEnvelope` v2、
`INCOMPLETE` 边界和可审计计时说明。

## 最终包与哈希

发行目录：

```text
E:\GAME\builds\windows_r17
```

| 文件 | bytes | SHA-256 |
|---|---:|---|
| `ColonyUnderGlass_v1.0_beta_r17.exe` | 109071360 | `04baf75cc1d69dd93eb709533ecab4fd7770bb8a530645717017a06a9d9809fc` |
| `ColonyUnderGlass_v1.0_beta_r17.pck` | 7840568 | `4aa070fd812793a3157ecd45005ad502495119837f3542f23d89b13e2f3b4e96` |
| `CREDITS.txt` | 1377 | `c66e03e9e7b8c22fd5c897deb6c58635352bce7e0c279a2af4e45841d584faac` |
| `PRIVACY.txt` | 1543 | `cf1dbba6db6d56b5b6faf1888d3cff0749ead4a60aaf48942c783bdba0fb4d8e` |
| `RELEASE_NOTES.txt` | 3525 | `63f5313492424396c5347e5818a5317f83234d2de1ccf6440191fe48a2850b4f` |
| `THIRD_PARTY_NOTICES.txt` | 98986 | `fff8a198590dfe153ab88260ecf40b09e74265fb608a781d0d422f615ef48bc2` |

最终 ZIP：

```text
E:\GAME\builds\ColonyUnderGlass_v1.0_beta_r17_68c533e_windows_x86_64.zip
bytes=43530928
sha256=f72ac74a367463429ea7c195cd96ba4e5f0d292e06b314c6b3832ad1d941e1bd
```

先前从 `735bfa7` 生成的草拟 ZIP 已被最终包取代；宿主安全策略拒绝自动
删除这个已忽略的单文件草稿，因此不能声称它已被清理。最终候选以文件名
中的 `68c533e`、本节大小和 SHA-256 为唯一识别依据。

## 最终差异自我审查

- 固定 Tick、三档速度、模拟更新顺序、生命周期、任务、设施和章节参数
  未修改。
- R17 时长仍位于应用存档外层，不进入权威模拟或影响确定性结果。
- View 只读取复制快照，没有取得模拟模型或把墙钟写回模拟。
- 发行 PCK 没有测试、工具、内部文档、参考素材或调试入口。
- 没有加入联网、Steam、云存档、多物种、战斗、自由挖掘、第三方插件
  或无关重构。
- 发布说明明确保留外部 Gate 的 `INCOMPLETE` 状态。

## 未完成与停止条件

- 7 名有效首次接触测试者数据仍未提供，保持 `INCOMPLETE`。
- 10 个首次完整档案、中位 180～240 分钟、至少 7／10 完成率和最终理解度
  仍未取得，保持 `INCOMPLETE`。
- 用户已允许这些缺失项不阻塞继续开发，但不允许伪造数据。
- 候选未签名，也没有安装器、平台 SDK、商店审核或公开分发。
- `E:\GAME_R17_UI_RUNTIME`、两个 R17 package runtime 和草拟 ZIP 需要
  用户在方便时手动清理；它们均为仓库外或已忽略的可重建证据。
- 未获明确授权前，不合并 `main`、不创建 Tag、不创建 GitHub Release、
  不公开发布。
