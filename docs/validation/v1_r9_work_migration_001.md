# v1 R9 清理、侦察与迁巢任务验证记录 001

> 分支：`feat/v1-work-migration`
> 日期：2026-07-28
> 引擎：Godot `4.7.1.stable.official.a13da4feb`
> 外部首次接触 Gate：`INCOMPLETE`

## 1. 范围

本轮只交付 R9“清理、侦察与迁巢任务”的技术候选：

- 冻结 `ColonyWorkConfig`；
- 废物批次搬运与高层垃圾托盘清理命令；
- 动态区域未发现／已发现权威状态与往返侦察任务；
- 持续稳定、明显改善的迁巢目标选择；
- 幼体按稳定 ID 迁移、蚁后最后迁移；
- 六类工蚁任务互斥、路径中断与环境失效恢复；
- 工作快照、结构化事件、只读画面投影与 F3 诊断；
- `r9.authority.v7` 存档与 R8→R9 迁移。

正式 Act 1 仍只有前两章。R9 没有开放第 3～5 章，没有加入温度、正式素材、音频、行为树、GOAP、ECS 或第三方依赖。

## 2. 模拟顺序

```text
验证连续 Tick
→ 按 sequence 应用高层命令
→ EnvironmentSystem
→ 更新迁巢候选
→ 生命周期
→ 校验并推进全部既有任务
→ 分配废物／侦察／迁巢任务
→ 分配育幼／喂食／觅食任务
→ Director 与全部不变量
→ 深复制快照
```

清理命令只携带稳定垃圾托盘 ID。提交 Tick 只发布待处理状态；下一连续 Tick 才由冻结配置重新校验并清理。

## 3. 状态机与所有权

```text
Waste: MOVING_TO_WASTE → PICKING_UP → CARRYING_TO_TRAY → DROPPING
Scout: MOVING_TO_ZONE → OBSERVING → RETURNING
Migration: MOVING_TO_MEMBER → PICKING_UP → CARRYING_TO_ZONE → DROPPING
```

- 同一工蚁最多有一个活跃任务。
- 未携带的幼体与蚁后各属于一个有效区域。
- 被迁移成员的区域为空，且恰好属于一个迁移工蚁。
- 一个成员、废物来源批次或托盘容量不会被重复预订。
- 路径中断保留已携带所有权；目标环境失效把成员送回来源。
- 未发现区域不会被普通搬运、觅食、喂食或迁巢选择。
- 任务取消、放下和清理不残留目标、路线、预订或携带关系。

## 4. 自动覆盖

`tests/simulation/colony_work_test_suite.gd` 覆盖：

- 工作配置冻结与快照隔离；
- 动态区域只发现一次；
- 废物拾取、携带、送达和下一 Tick 清理；
- 幼体先迁移、蚁后最后迁移；
- 环境失效时携带幼体返回来源；
- 活动侦察任务存读后逐 Tick 结果一致。

标准 runner 同时继续覆盖三档速度、暂停、布局、环境、生命周期、湿度搬运、糖／蛋白守恒、旧 schema 迁移和既有 10,000 Tick soak。R9 场景测试额外覆盖迁巢携带投影、稳定 View 节点和真实清理按钮命令边界。

## 5. 实际执行结果

| 命令或检查 | 结果 | 退出码 |
| --- | --- | ---: |
| `Godot_v4.7.1-stable_win64_console.exe --version` | `4.7.1.stable.official.a13da4feb` | 0 |
| `--headless --editor --path . --quit` | 项目扫描、脚本类注册、翻译与场景解析通过 | 0 |
| `--headless --path . --script res://tests/test_runner.gd` | `PASS: 37287 project assertions` | 0 |
| `--headless --path . --quit-after 30` | 默认应用外壳冒烟通过 | 0 |
| `--headless --path . --scene res://scenes/main/act1_test_tube.tscn --quit-after 30` | 正式 Act 1 场景冒烟通过 | 0 |
| 非 headless OpenGL 1280×720 视口捕获 | 迁巢与清理／侦察两组实际画面生成成功 | 0 |
| `git diff --check` | 通过；仅报告本机 CSV／导入文件行尾转换提示 | 0 |

## 6. 人工画面审阅

实际非 headless OpenGL 运行使用 NVIDIA GeForce RTX 4070 SUPER Compatibility 渲染器，捕获 1280×720 Viewport 像素并人工审阅：

- 迁巢画面中，工蚁、被携带幼体、轻量光晕与短连线形成同一视觉组；关闭 F3 也能辨认携带关系。
- 已发现动态区域显示独立腔室、连接和湿度色调；未发现区域使用暗色轮廓与点状线索。
- 废物搬运显示随工蚁移动的棕色颗粒；侦察观察阶段显示青色光晕，两者不需要任务枚举文字。
- 1280×720 下标题、速度、侧栏、工具栏和试管观察区没有重叠；新增清理按钮默认隐藏，只有快照报告可清理托盘时出现。
- 普通画面没有稳定 ID、精确环境值、任务枚举或目标 ID。

捕获辅助脚本与 PNG 位于仓库外的 Codex 可视化目录，不进入版本控制。

## 7. 已知限制与 Gate

- 正式前两章尚未解锁补水、蛋白和垃圾设施；R9 是后续章节可复用的权威基础，不是第 3～5 章已完成。
- 所有工作、环境和物种参数仍是未经科学审校的 `prototype_pacing_fixture`。
- 温度没有区别于湿度的独立闭环证据，继续延期。
- v0.2 要求的 7 名有效首次接触测试者数据未提供，外部理解度 Gate 保持 `INCOMPLETE`。用户允许跳过该阻塞继续开发，不等于 `PASS`，也没有生成或伪造测试数据。
- 合并 `main`、Tag、GitHub Release 和商店发布没有执行，仍需另行明确授权。

## 8. 最终 diff 自审

- 没有改变 0.1 秒固定 Tick、Godot 版本或 Species_A 生命周期参数。
- 三个工作任务保持专用小状态机，没有通用任务框架、行为树、GOAP 或 ECS。
- 模拟只使用稳定区域／实体／设施 ID；屏幕坐标、颜色、Tween 和渲染帧率没有进入权威状态。
- View 只读取工作、区域和实体快照；清理 UI 不传递权威效果量。
- R8 旧档沿纯迁移获得等价发现状态和空闲工作任务；加载不读取当前 Resource。
- `DEVELOPMENT_PLAYBOOK.md` 保持未读、未修改、未暂存。
- Godot 可执行文件、`.godot/`、日志、构建和仓库外捕获没有进入版本控制。
