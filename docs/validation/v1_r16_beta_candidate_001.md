# v1 R16 Windows Beta 技术候选验证记录 001

日期：2026-07-29
分支：`release/v1.0-beta`
发行源码提交：`3ca4166eb830907ca419982ce39ddc7baad52f33`
引擎：Godot `4.7.1.stable.official.a13da4feb`
结论：本机技术 Beta 候选通过；外部首次接触与完整档案 Gate 仍为
`INCOMPLETE`

## 结论边界

R16 已完成最终 Windows x86_64 release 包、最大规模长时验证、存档迁移
回归、干净隔离目录流程、显示矩阵、许可、Credits、隐私说明、发布说明
和构建哈希冻结。没有开放的已知 P0／P1 技术缺陷。

本结论不把以下缺失数据写成通过：

- v0.2 要求的 7 名有效首次接触测试者数据；
- R16 要求的 10 个首次完整档案；
- 180～240 分钟中位完成时长、7／10 完成率、最终理解度与外部卡点数据。

用户允许跳过 7 人数据继续完成开发，只解除开发阻塞，不构成外部
Gate 的证据。合并 `main`、创建 `v1.0.0` Tag、GitHub Release 和公开
发布均未授权、未执行。

## 候选内容

候选保留单一 0.1 秒固定 Tick 和六章正式档案，覆盖：

1. 单后试管护理与蛹观察；
2. 第一只工蚁、首次糖液交换与育幼；
3. 小型觅食区、糖／蛋白和废物管理；
4. 环境梯度、备用试管、连接件与部分迁移；
5. 双室模块巢、幼体优先和蚁后最后的核心迁巢；
6. 长期证据整理、“玻璃观察报告”和自由观察。

最大规模 fixture 固定为 80 只工蚁、180 个幼体、48 项设施、36 个区域、
72 条连接和 20 个食物源。权威模拟保留全部实体；画面使用稳定 ID
选择活动个体，并把同时存在的 `AntView` 限制为 240 个。

R16 还完成：

- release 构建禁用 F3 诊断入口；
- 测试、工具、文档、`sucai/`、调试场景和旧独立入口的发行剥离；
- 标题页双语 Credits／隐私入口；
- 精确 Godot 4.7.1 引擎与第三方许可副本；
- release 存档高精度浮点规范化和旧数值校验迁移；
- 1280×720 终章工具栏滚动容器，避免已解锁工具挤出安全区。
- 新存档展示版本固定为 `1.0.0-beta`，内容兼容键保持不变。

## 自动与运行验证

所有命令都从候选仓库根目录执行。

| 命令 | 结果 | 退出码 |
|---|---|---:|
| `Godot_v4.7.1-stable_win64_console.exe --version` | 精确版本 `4.7.1.stable.official.a13da4feb` | 0 |
| `--headless --editor --path . --quit` | 脚本、场景、资源和导入解析通过 | 0 |
| `--headless --path . --script res://tests/test_runner.gd` | `PASS: 40381 project assertions` | 0 |
| `--headless --path . --quit-after 30` | 默认标题外壳与主场景冒烟通过 | 0 |
| `--headless --path . --script res://tests/performance/act1_144k_soak.gd` | 最终提交完整档案长时验证通过；结果见下节 | 0 |
| `--headless --path . --script res://tests/performance/act1_300k_max_scale_soak.gd` | 最终提交最大规模长时验证通过；结果见下节 | 0 |
| 非 headless 最大规模脚本，`-- --ticks=1 --frame-samples=600` | 600 帧样本全部低于 22 ms | 0 |
| `--headless --export-release "Windows Desktop" ...` | 干净 worktree 导出成功 | 0 |
| 导出 EXE `--headless --quit-after 30` | 隔离目录 release 冒烟通过，无 stderr | 0 |

40,381 项回归包含固定 Tick、确定性、命令边界、单一所有权、快照隔离、
三档速度等价、全部章节真实 UI 路径、存档 schema 迁移、备份与删除、
设置迁移、双语格式、生产资产、音频、release F3 门控、发行排除规则、
最大规模视图上限，以及 1280×720／1920×1080、100%／150% 布局边界。

## 长时与性能证据

最终提交复跑结果：

```text
R12_SOAK_PASS ticks=144000 start_tick=46 end_tick=144046
avg_tick_us=275.72 p95_tick_us=430 max_tick_us=2482
elapsed_s=46.895 static_memory_bytes=34137944 save_bytes=30878
signature=2fd15ac67d8a3aab5906e37719d5a72585a91a3d1c374a837aadf76b89833352

R16_MAX_SCALE_SOAK_PASS
ticks=300000 start_tick=46 end_tick=300046 elapsed_s=359.714
avg_tick_us=1190.02 p95_tick_us=1793 p99_tick_us=2157
max_tick_us=5383 tick_over_5000=1
avg_snapshot_us=2422.07 p95_snapshot_us=2802 max_snapshot_us=5433
snapshot_over_4000=1
avg_view_us=2378.93 p95_view_us=2879 max_view_us=3954
view_over_7000=0
memory_start_bytes=37414112 memory_peak_bytes=42770312
memory_final_bytes=46583212 memory_growth_bytes=9169100
memory_trend_slope_bytes_per_sample=161.72 save_bytes=212897
workers=80 brood=180 facilities=48 zones=36 connections=72
food_sources=20 active_tasks=80 visible_ant_views=240
signature=ad21e7f54e3a2832223048f4a8f4748fa108e60b5a5dbf02a8e11e493564dd3e
```

非 headless 1280×720、600 帧最大规模样本：

```text
R16_MAX_SCALE_FRAME_PASS samples=600
avg_frame_us=5614.20 p95_frame_us=7920 p99_frame_us=8716
max_frame_us=9672 frame_over_22000=0
window_width=1280 window_height=720
```

测试机：

- Windows 11 Pro `10.0.26100` x64；
- AMD Ryzen 7 7800X3D，8 核／16 线程；
- 33,397,133,312 bytes 物理内存；
- NVIDIA GeForce RTX 4070 SUPER；
- OpenGL Compatibility。

性能口径只用于当前目标硬件和当前 fixture，不外推到其他硬件。最终
300,000 Tick 中 P95 Tick 为 1.793 ms；1 次超过 5 ms，最大 5.383 ms。
300 次快照／View 样本中，快照 1 次超过 4 ms，View 没有超过 7 ms。
600 个实际渲染帧没有超过 22 ms。静态内存终值相对起点增加
9,169,100 bytes；脚本保留完整增长斜率、存档大小和原始长尾，不以
平均值掩盖异常。

## 隔离 Windows 流程

最终六文件包复制到空的隔离应用目录，并使用隔离的 Godot 用户数据根。
实际窗口完成：

- 首次启动进入标题页；
- 新游戏进入 Tick 0 准备门；
- 开始观察、16×、暂停、保存并返回标题；
- “继续”恢复相同 Tick、16×和暂停状态；
- 加载完成的 `r12.authority.v10` 档案；
- 查看完整报告，进入自由观察和模块布局；
- 再次通过真实暂停菜单保存，标题页显示“进度已保存”；
- 正常退出，进程关闭。

最终隔离存档在真实 UI 保存后的状态：

```text
simulation_tick=14385
clock_paused=true
clock_speed=16
campaign.chapter=7
campaign.completed_chapter_count=6
campaign.campaign_completed_tick=46
state_schema_id=r12.authority.v10
```

损坏恢复、备份选择和确认删除由自动档案套件覆盖；本次隔离窗口没有再次
人为损坏文件。候选不写注册表、不依赖安装器或仓库文件。取证 worktree
已移除；宿主安全策略两次拒绝递归删除本轮两个隔离运行目录，因此
`E:\GAME_R16_FINAL_RUNTIME_3ca4166` 和
`E:\GAME_R16_RUNTIME_d31ad3e` 仍保留，未把“清理目录”伪装为已通过。
手动删除这两个只含候选副本、日志和隔离档案的目录即可完成清理。

## 实际显示与交互矩阵

真实 Windows release 窗口覆盖：

| 组合 | 检查结果 |
|---|---|
| 1280×720，窗口，100%，中文／英文 | 标题、设置、Credits／隐私、准备门、观察、手册、布局、暂停、报告通过 |
| 1280×720，窗口，150%，中文／英文 | 设置和主要面板安全区通过 |
| 1920×1080，窗口，100%／150%，中文／英文 | 标题、设置和主观察布局通过 |
| 全屏，100%／150% | 返回、分辨率、焦点和主要面板通过 |
| 普通动效／减少动效 | 状态仍可由文字和形状辨认；减少动效不改模拟 |
| F3 | release 标题与游戏内均无效果 |

关闭 F3 时仍能辨认携带、设施状态、放置合法性和环境线索。终章完成档案
在 1280×720 下验证了报告、自由观察和全部已解锁工具；工具行使用水平
滚动，不再遮挡标题、侧栏或第二行布局控制。

## 发行包与剥离

PCK 二进制标记检查没有发现：

```text
res://tests/
res://tools/
res://docs/
res://sucai/
res://scenes/debug/
res://scenes/main/main.tscn
```

发行目录恰好包含六个文件：

| 文件 | bytes | SHA-256 |
|---|---:|---|
| `ColonyUnderGlass_v1.0_beta.exe` | 109071360 | `04baf75cc1d69dd93eb709533ecab4fd7770bb8a530645717017a06a9d9809fc` |
| `ColonyUnderGlass_v1.0_beta.pck` | 7828596 | `0269319180cc847371442efae05f2048121a9d2d89db0f0d25976f617ece4823` |
| `CREDITS.txt` | 1377 | `c66e03e9e7b8c22fd5c897deb6c58635352bce7e0c279a2af4e45841d584faac` |
| `PRIVACY.txt` | 1543 | `cf1dbba6db6d56b5b6faf1888d3cff0749ead4a60aaf48942c783bdba0fb4d8e` |
| `RELEASE_NOTES.txt` | 2969 | `550eb32162dd944a7baccd4f0df6b1df7513269e819df1482b3e7415497078b1` |
| `THIRD_PARTY_NOTICES.txt` | 98986 | `fff8a198590dfe153ab88260ecf40b09e74265fb608a781d0d422f615ef48bc2` |

最终 ZIP：

```text
ColonyUnderGlass_v1.0_beta_windows_x86_64.zip
bytes=43522654
sha256=c48354862b8268806f77a0887191c1c3faf204eff92f888aad90c920dd792df3
```

候选未签名。代码和项目自有资产权利见 Credits 与生产台账；Godot 和
随引擎分发的第三方许可来自精确 4.7.1 二进制导出的
`GODOT_COPYRIGHT.txt` 读者副本。

## 验证中发现并修复的问题

### 完成档案保存失败

旧规范化编码直接使用高精度浮点 JSON 表示；解析往返可能改变最低有效位，
使刚写入的 checksum 无法再次验证。修复后：

- 当前编码使用 17 位往返稳定表示；
- 旧数值 checksum／配置哈希仍可验证并重新封装；
- 新增高精度幂等、旧数值迁移和完成报告落盘重载回归；
- 完成档案通过真实 UI 再次保存和加载。

### 终章工具栏越界

完成档案同时显示全部工具时，1280×720 工具行把标题和侧栏挤出画面。
修复后两个工具行分别位于水平自动滚动容器，设施类型下拉不再强制采用
最长项目宽度。场景回归覆盖最大工具集、双分辨率和双缩放；最终 release
窗口复查通过。

## 最终差异自我审查

- 固定 Tick、模拟更新顺序、生命周期参数、设施接口和章节条件未因发行
  收口而改变。
- 存档修复保持旧数值 checksum 兼容，没有静默接受任意损坏档。
- 工具栏修复只作用于 View／场景布局，不反写模拟。
- 发行包没有测试、工具、内部文档、调试场景、`sucai/`、凭据、日志、
  `.godot/` 或本机配置。
- 没有加入 Steam、联网、多人、云存档、第二物种、战斗、自由挖洞、
  第三方插件或无关重构。
- 用户自有未跟踪 `DEVELOPMENT_PLAYBOOK.md` 未读取、未修改、未暂存。

## 剩余风险与停止条件

- 外部首次接触、完整档案、时长、完成率和母语理解度数据仍未知。
- 候选未进行代码签名、安装器、平台 SDK、商店审核或公开分发。
- 隔离运行目录清理由宿主安全策略阻止，仍需手动删除上述两个明确目录。
- 物种与原型节奏参数未经科学审校。
- 温度仍没有区别于湿度的独立闭环。
- 未获得明确授权前，不合并 `main`、不创建 Tag、不创建 GitHub Release、
  不公开发布。
