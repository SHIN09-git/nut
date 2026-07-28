# v1 R7 模块化布局与镜头验证记录 001

> 分支：`feat/v1-modular-layout-camera`
> 日期：2026-07-28
> 引擎：Godot `4.7.1.stable.official.a13da4feb`
> 外部首次接触 Gate：`INCOMPLETE`

## 1. 范围

本轮只交付 R7“模块化布局与镜头”的技术候选：

- 冻结 `FacilityCatalogData` 与运行时复制配置；
- 稳定设施实例、逻辑槽位、方向、接口、设施库存和连接实例；
- `HabitatLayoutState` 作为区域可达图唯一权威；
- 放置、旋转、拆除和闸门状态的下一 Tick 命令；
- `HabitatLayoutSnapshot` 与只读 `FacilityLayoutView`；
- 正式 Act 1 的鼠标／键盘布局路径和平移缩放镜头；
- 遮光套复用设施权威；
- `r7.authority.v5` 存档与 R6→R7 迁移；
- 1280×720、1920×1080 和 100%／150% UI 缩放回归。

没有实现新设施的湿度、营养、垃圾或迁巢效果，没有加入自由坐标、自动迁移、温度、正式素材、音频、Steam 或第三方插件。

## 2. 权威更新顺序

```text
验证连续 Tick
→ 按提交顺序应用设施与既有高层命令
→ 更新稳定设施、库存、连接和可达缓存
→ 推进生命周期与既有搬运／觅食／育幼系统
→ 通过 HabitatLayoutState 查询稳定路径
→ 校验设施几何、库存守恒、连接和实体所有权
→ 创建深复制 GameSnapshot
→ 控制器与 FacilityLayoutView 投影快照
→ 渲染帧独立处理镜头偏移与缩放
```

镜头输入不进入命令队列，不推进 Tick，也不写入存档。

## 3. 自动覆盖

`tests/simulation/facility_layout_test_suite.gd` 覆盖：

- 设施目录启动冻结；
- 非法重叠、越界、接口和方向拒绝；
- 未解锁类型、库存耗尽和固定设施保护；
- 稳定设施 ID 与库存守恒；
- 放置、旋转、拆除和闸门命令在下一 Tick 生效；
- 关闭／打开闸门后路径缓存失效；
- 旧区域邻接与布局图可达性等价；
- 遮光套创建同一布局权威中的设施；
- 重复快照与快照隔离；
- R6 已安装／未安装遮光套档案迁移。

`tests/scenes/act1_test_tube_scene_test_suite.gd` 通过实际节点信号和输入事件完成鼠标放置、键盘拆除／放置、滚轮缩放和键盘平移，并以真实视口矩形检查 1280×720／1920×1080、100%／150% 下关键控件不越界。布局新增后，旧生命周期、湿度、觅食、营养、章节、存档和 10,000 Tick soak 继续由标准 runner 覆盖。

## 4. 实际执行结果

| 命令或检查 | 结果 | 退出码 |
| --- | --- | ---: |
| `Godot_v4.7.1-stable_win64_console.exe --version` | `4.7.1.stable.official.a13da4feb` | 0 |
| `--headless --editor --path . --quit` | 项目扫描、脚本类注册、翻译导入与场景解析通过 | 0 |
| `--headless --path . --script res://tests/test_runner.gd` | `PASS: 36601 project assertions` | 0 |
| `--headless --path . --quit-after 30` | 默认应用外壳冒烟通过 | 0 |
| `--headless --path . --scene res://scenes/main/act1_test_tube.tscn --quit-after 30` | 正式 Act 1 场景冒烟通过 | 0 |
| 非 headless OpenGL 视口直接捕获 | 三组布局运行帧生成成功 | 0 |
| `git diff --check` | 通过 | 0 |

## 5. 人工画面审阅

实际非 headless OpenGL 运行使用 NVIDIA GeForce RTX 4070 SUPER Compatibility 渲染器。Windows 桌面捕获接口只返回 Godot 灰帧，因此没有把该帧记为通过；改由同一运行时的 Godot Viewport 直接保存像素，并人工审阅：

- 1280×720／100%：标题、速度、布局网格、固定试管、微型喂食口、已放置小型觅食盒、侧栏和两行工具栏完整可见。
- 1280×720／150%：标题与所有布局／镜头按钮仍在视口内；侧栏通过可见滚动条访问长证据，没有把根布局撑出屏幕。
- 1920×1080／100%：设施标签、接口占位轮廓、导航提示、侧栏和工具栏清晰，无截断或重叠。
- 设施的轮廓与选中边框不是纯文字反馈；关闭 F3 时无需内部 ID 即可识别固定试管、喂食口和觅食盒。

第一次捕获暴露了完成章节后侧栏长文本导致 1280×720 根布局上下裁切。修复为侧栏内部滚动，并把场景测试从“扩张后的控制器矩形”改为真实视口矩形；修复后的三组帧重新检查通过。

运行帧与临时捕获脚本保存在仓库外的 Codex 可视化目录，不进入版本控制。

## 6. 已知限制与 Gate

- R7 新设施除遮光套既有护理门控外，不产生湿度、营养、垃圾或迁巢效果；这些属于 R8 以后。
- 当前正式章节只解锁并开放小型觅食盒；连接管和闸门已有权威类型与测试夹具，但尚未成为本章玩家工具。
- 镜头位置不保存；重新进入场景时恢复默认镜头。
- 玩家可见英文仍是临时翻译，尚未人工终校。
- v0.2 要求的 7 名有效首次接触测试者数据未提供，外部理解度 Gate 保持 `INCOMPLETE`。用户允许跳过该阻塞继续开发，不等于 `PASS`。

## 7. 最终 diff 自审

- 没有修改 0.1 秒固定 Tick、Godot 版本或 Species_A 生命周期参数。
- 区域运行时只保存环境值；搬运、觅食和营养统一查询布局权威。
- UI 与 View 只读快照；没有取得 `ColonyState`、`QueenModel` 或 `AntModel` 引用。
- 设施命令在下一连续 Tick 生效；镜头操作不会改变模拟或存档。
- 没有对象池、行为树、GOAP、ECS、通用事件总线或推测性框架。
- `DEVELOPMENT_PLAYBOOK.md` 保持未读、未修改、未暂存。
- Godot 可执行文件、`.godot/`、日志、构建和仓库外运行帧未进入版本控制。
- 合并 `main`、Tag、GitHub Release 和商店发布没有执行，仍需另行明确授权。
