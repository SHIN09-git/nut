# R18 建群护理空幼体稳定性修复

日期：2026-07-30
分支：`codex/fix/r18-founding-care-empty-brood`

## 问题

R18-0 的真实新档案在第三章完成布局和补给、切换到 16× 后显示：

```text
Simulation rejected Tick 10407
```

该横幅不能区分 Tick 不连续与 Tick 内状态校验失败。

## 隔离复现

使用临时、未提交的 headless 场景探针执行：

1. 通过真实按钮完成第一章遮光、推论；
2. 等待首工羽化并通过真实按钮补糖；
3. 通过真实手册按钮进入第三章；
4. 通过真实布局控件放置觅食盒、糖台、蛋白盘和垃圾托盘；
5. 通过普通补给按钮提交糖和蛋白；
6. 切换 16×，连续推进固定 Tick。

修复前连续两次在同一状态中断。第二次诊断结果：

```text
R18_PROBE_REJECTED error=Simulation rejected Tick 3850
clock_tick=3850 state_tick=3850
config=Habitat ownership invariant failed at Tick 3850
validators brood=true foraging=true nutrition=true founding=false
act1=true environment=true work=true layout=true overall=false
```

当时三个个体均为工蚁，所有任务均为空闲。时钟与模拟 Tick 相同，因此排除 16× 跳 Tick。

## 根因

最后一个幼体羽化后，`FoundingCareSystem.advance()` 会把蚁后护理状态复位为：

- `RESTING`
- elapsed Tick 为 `0`
- 目标幼体为 `-1`

这是没有幼体时的合法状态。但 `FoundingCareSystem.has_valid_state()` 只检查环境是否适合护理；只要环境适合，它仍要求存在目标幼体，于是把合法的空幼体状态判为非法。

## 修复

校验现在同时判断：

- 环境是否适合护理；
- 当前是否仍有非工蚁幼体。

环境不适合或已经没有幼体时，合法状态均为静止、零进度、无目标。存在幼体且环境适合时，原有目标校验不变。

新增回归测试构造全部首代个体均已成为工蚁的权威状态，确认下一固定 Tick 被接受、护理保持静止且整体所有权有效。

## 原路径复验

同一临时探针在修复后完成：

```text
R18_PROBE_PASS tick=12006 ownership=true
```

退出码：`0`。临时探针随后删除，没有纳入版本控制。

## 正式验证

| 检查 | 结果 | 退出码 |
|---|---|---:|
| Godot 精确版本 | `4.7.1.stable.official.a13da4feb` | 0 |
| headless 编辑器解析 | 通过 | 0 |
| 全量自动测试 | `PASS: 40460 project assertions` | 0 |
| headless 主场景冒烟 | 通过 | 0 |
| `git diff --check` | 通过 | 0 |

人工窗口检查：未执行。本分支没有修改场景、View、UI、图形或参数；原交互路径已通过真实 UI 节点的 headless 复现覆盖。R18-0 的既有 1280×720 窗口截图仍是视觉基线。

## 范围审查

- 没有修改固定 Tick、速度、命令队列或生命周期参数。
- 没有修改 UI、场景、Resource、存档格式或本地化。
- 没有增加玩法、依赖或正式素材。
- `DEVELOPMENT_PLAYBOOK.md` 为用户未跟踪文件，未读取、未修改、未暂存。
