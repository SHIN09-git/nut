# Colony Under Glass

《玻璃蚁国》的 Godot 4.7.1 可行性灰盒。当前里程碑已包含项目入口、0.1 秒固定模拟时钟，以及蚁后产卵到首批工蚁羽化的最小生命周期。

## 当前功能

- `project.godot` 启动 `scenes/main/main.tscn`。
- 模拟以 0.1 秒固定 Tick 前进。
- 支持暂停、1×、4×、16×。
- 倍速不改变单 Tick 步长。
- 默认每帧最多处理 16 Tick；上限可配置，剩余 Tick 保留到后续帧，不丢模拟时间。
- `Species_A` 数据资源驱动蚁后最多产下 3 枚首代卵，个体依次经历卵、幼虫、蛹、工蚁并保持稳定 ID。
- 生命周期配置会在开局时验证并复制；运行中编辑原始 Resource 不会改变当前模拟。无效配置或 Tick 失步会阻止继续推进。
- 模拟状态保持私有；主场景通过新建的 `ColonySnapshot`／`AntSnapshot` 副本读取生命周期状态，不直接持有内部模型。
- 主场景当前用阶段计数、稳定个体 ID、阶段标记和观察记录显示生命周期，不暴露完成百分比或羽化倒计时；这些是灰盒诊断 UI，不是最终视觉方案。
- 无第三方插件的 headless 固定时钟、主场景控制和生命周期测试。

最近一次验证使用 `4.7.1.stable.official.a13da4feb`，共通过 134 项断言。此前已完成主场景 30 帧无头启动。

2026-07-22 固定时钟阶段人工窗口验收：1280×720 下中文与布局正常；4×切换生效；暂停两秒期间 Tick 与模拟时间保持不变。当前生命周期改动已由主场景集成断言覆盖控件和首枚卵显示，窗口布局仍需在下一次本地窗口会话中复验。

## 当前生命周期节奏夹具

参数事实来源为 `data/species/species_a.tres`：

| 参数 | Tick |
| --- | ---: |
| 首枚卵延迟 | 1200 |
| 后续产卵间隔 | 300 |
| 卵阶段 | 800 |
| 幼虫阶段 | 1000 |
| 蛹阶段 | 1000 |
| 首代幼体上限 | 3 |

以上全部是**原型节奏夹具／非真实生物数据**，只服务于有限时长的灰盒验证。当前三枚卵在 Tick 1200、1500、1800 产生，三只工蚁在 Tick 4000、4300、4600 羽化；不得将这些值描述为真实物种周期。
资源内另有 `data_status = prototype_pacing_fixture` 与 `scientifically_validated = false` 两个显式标记。

## 运行

先从 [Godot 4.7.1 官方发布页](https://github.com/godotengine/godot/releases/tag/4.7.1-stable) 下载 Windows 标准版 `Godot_v4.7.1-stable_win64.exe.zip`，将其中的可执行文件解压到仓库根目录。仓库不包含引擎程序；请使用固定的 4.7.1-stable 版本。

在仓库根目录执行：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --editor --path .
```

也可以直接运行主场景：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --path .
```

## 测试

`tests/test_runner.gd` 是唯一顶层入口，聚合固定时钟、主场景控制和 `tests/simulation/lifecycle_test_suite.gd`：

首次克隆后，先导入项目以生成 Godot 的脚本类缓存，再运行测试：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script 'res://tests/test_runner.gd'
```

GitHub Actions 在推送到 `main` 和提交 PR 时自动使用同一版本引擎，校验下载文件的 SHA-256，依次执行项目导入、134 项断言和主场景 30 帧无头启动。这些检查不替代窗口布局与玩法的人工验收。

## 导出状态

当前机器尚未检测到 Godot 4.7.1 Export Templates，因此暂不提供 Windows 导出命令。Export Templates 安装并创建 `export_presets.cfg` 后再验证导出流程。

## 项目约束

开始实现前阅读：

- `GDD.md`
- `ARCHITECTURE.md`
- `AGENTS.md`

`sucai/` 仅用于本地观察参考，授权确认前不得作为发行素材。
