# Colony Under Glass

《玻璃蚁国》的 Godot 4.7.1 可行性灰盒。当前里程碑只包含项目入口、主场景和 0.1 秒固定模拟时钟。

## 当前功能

- `project.godot` 启动 `scenes/main/main.tscn`。
- 模拟以 0.1 秒固定 Tick 前进。
- 支持暂停、1×、4×、16×。
- 倍速不改变单 Tick 步长。
- 默认每帧最多处理 16 Tick；上限可配置，剩余 Tick 保留到后续帧，不丢模拟时间。
- 无第三方插件的 headless 时钟测试。

最近一次验证使用 `4.7.1.stable.official.a13da4feb`，共通过 40 项断言，并完成主场景 30 帧无头启动。

2026-07-22 人工窗口验收：1280×720 下中文与布局正常；4×切换生效；暂停两秒期间 Tick 与模拟时间保持不变。

## 运行

在仓库根目录执行：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --editor --path .
```

也可以直接运行主场景：

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --path .
```

## 测试

```powershell
& '.\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script 'res://tests/test_runner.gd'
```

## 导出状态

当前机器尚未检测到 Godot 4.7.1 Export Templates，因此暂不提供 Windows 导出命令。Export Templates 安装并创建 `export_presets.cfg` 后再验证导出流程。

## 项目约束

开始实现前阅读：

- `GDD.md`
- `ARCHITECTURE.md`
- `AGENTS.md`

`sucai/` 仅用于本地观察参考，授权确认前不得作为发行素材。
