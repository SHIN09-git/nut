# v1 R15 正式音频与文本校对验证记录 001

日期：2026-07-29
分支：`content/v1-audio-localization`
引擎：Godot `4.7.1.stable.official.a13da4feb`
结论：R15 技术候选通过；R16、外部母语理解度与完整档案 Gate
仍为 `INCOMPLETE`

## 范围

本轮没有修改固定 Tick、模拟更新顺序、生命周期、行为参数、设施
接口、存档权威 schema、章节条件或外部依赖。

完成内容：

- 一条 16 秒低干扰玻璃观察循环氛围。
- 八个有限反馈音：界面确认、玻璃遮光、补水、设施、闸门、手册、
  章节完成和报告出现。
- `Master`、`Ambient`、`SFX` 三条总线和独立主音量、环境音量、
  操作反馈音量。
- 设置格式 v3，以及 v1／v2 到 v3 的安全默认分音量迁移。
- 简体中文与英文玩家文本逐条编辑校对。
- 正式 Act 1 场景中会被运行时覆盖的硬编码中文占位清理。

声音只强化已经存在的按钮状态、文字、画面和章节变化。控制器只在
模拟接受高层命令，或快照显示章节／报告变化时请求表现提示；
`AudioDirector` 不读取或修改权威模拟。

## 音频来源与权利

九个 WAV 均由
`tools/audio/generate_r15_audio.gd`
以固定算法生成：

- 44.1 kHz；
- 单声道；
- 16-bit PCM；
- 不使用外部样本、音乐库、语音、插件或字体；
- 最终哈希与权利字段记录在
  `docs/production/V1_R15_AUDIO_MANIFEST.md`
  和 `docs/production/asset_ledger.csv`。

生成器保留在版本控制中以便复现，但 `export_presets.cfg` 将
`tools/**` 从发行包排除。

## 自动与运行验证

| 命令 | 结果 | 退出码 |
|---|---|---:|
| `Godot_v4.7.1-stable_win64_console.exe --version` | 精确版本 `4.7.1.stable.official.a13da4feb` | 0 |
| `--headless --path . --script res://tools/audio/generate_r15_audio.gd` | 九个 SHA-256 与冻结清单完全一致 | 0 |
| `--headless --editor --path . --quit` | 脚本解析、总线资源、WAV 与翻译资源导入无错误 | 0 |
| `--headless --path . --script res://tests/test_runner.gd` | `PASS: 40238 project assertions`；退出无对象泄漏警告 | 0 |
| `--headless --path . --quit-after 30` | 默认应用外壳 headless 冒烟通过 | 0 |
| `--path . --script res://tests/audio/production_audio_runtime_check.gd` | NVIDIA OpenGL Compatibility；环境与效果播放器均实际进入播放状态 | 0 |

R15 新增或扩展的回归覆盖：

- 九个 WAV 的存在、SHA-256、导入类型、44.1 kHz、单声道和有效时长。
- 16 秒氛围长度、有限提示 ID、未知提示拒绝。
- `Master`、`Ambient`、`SFX` 总线和独立静音／音量。
- 遮光与手册真实 UI 事件选择正确提示，且同步存在可见状态。
- v1 设置获得默认快捷键和分音量。
- v2 设置保留快捷键并获得默认分音量。
- v3 三路音量独立持久化，NaN／无穷和不完整字段被拒绝。
- 双语每行完整、键唯一、格式参数一致、无替换字符、无 TODO／TBD、
  无英文 CJK 残留。
- 正式玩家场景与控制器没有硬编码中文玩家文案。
- 1280×720／1920×1080、100%／150% 设置页布局边界。

## 实际窗口检查

使用非 headless Godot OpenGL Compatibility 和真实 Windows 窗口执行，
窗口内容为 1280×720，F3 关闭。

检查了：

- 中文 100% 三路音量、分辨率、全屏、语言、减少动效和返回操作；
- 英文 100% 的全部设置标签；
- 中文与英文 150% 设置布局；
- 语言弹出列表中的“简体中文”与“English”；
- 标题页和设置页切换时的实际效果音请求；
- 非 headless 环境与效果播放器实际开始播放。

首次检查发现：中文为当前语言时，首次进入设置页的下拉框显示为空，
切换一次语言后才出现名称。修复为在填充 `OptionButton` 时直接写入
本地化项，并新增“首次设置变更前语言名称可见”的场景回归。重新启动
应用后复查通过。

主观混音听感、不同扬声器／耳机响度和母语文案理解度没有人类外部样本，
不会在本记录中伪装为通过；R16 最终外测仍需收集。

## 差异自我审查

- 音频提示只从控制器向外壳表现层单向发送。
- 快照、命令队列和模拟模型没有音频引用。
- 旧组合湿度补水仍获得水滴反馈；新档案继续走正式 Act 1。
- 声音关闭后所有任务、推论和状态仍可从画面与文字完成。
- `sucai/`、外部样本、第三方插件和生成缓存未进入生产引用。
- `.godot/`、构建产物、本机设置和凭据未纳入提交。
- 没有新玩法、无关重构、引擎升级、Steam、第二物种或发行操作。
- `DEVELOPMENT_PLAYBOOK.md` 保持用户自有未跟踪文件，未读取、
  未修改、未暂存。

## 未完成与 Gate

- R16 的 300,000 Tick 最大规模 soak、最终 Windows release、发行包
  剥离、Credits、发布说明、哈希冻结和干净环境流程尚未执行。
- v0.2 的 7 人首次接触、R6／R10／R11 的外部理解度，以及 R12 的
  10 个完整档案数据仍为 `INCOMPLETE`。
- 用户允许跳过 7 人数据继续开发，不等于任何外部 Gate 已通过。
- 合并 `main`、创建 Tag、GitHub Release 和商店发布仍需另行授权。
