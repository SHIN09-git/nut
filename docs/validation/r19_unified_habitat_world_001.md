# R19-B 普通观察与布局统一世界验证记录

## 结果

R19-B 已把正式 Act 1 的普通观察与布局编辑接入同一个栖息地空间。设施和
连接始终可见；“模块布局”只切换编辑网格、标签、预览和输入，不再切换到
另一张画面。当前工作包不宣称整个 R19 完成；新 HUD、直接世界操作、情境
检查器和完整镜头跟随仍属于后续工作包。

分支：`codex/feat/r19-unified-habitat-world`

基线提交：`55ea978`

## 实现

- `FacilityLayoutView` 在普通观察和布局编辑中复用同一设施节点化绘制和
  相机状态。
- `Act1TestTubeView` 的蚁后、幼体、工蚁、觅食点和任务路线全部改用
  `HabitatSpatialProjection`，删除正式区域的字符串哈希落点。
- 没有独立设施的逻辑通道区域按稳定区域拓扑投影到相邻设施锚点之间。
- `Act1WorldOverlay` 在同一投影中绘制食物、污染、护理、侦察、迁移和
  携带提示；只读取快照，不修改模拟。
- 相机变化统一重算设施和实体显示端点；布局开关不改变投影、Tick 或权威
  状态。

## 自动测试

新增或扩展覆盖：

- 普通观察中设施可见但不捕获布局输入。
- 进入和退出布局编辑不改变设施矩形。
- 放置后的设施退出布局后仍在相同位置。
- 相机平移时设施锚点和实体显示节点获得相同位移。
- 未表示为设施的逻辑通道使用相邻设施锚点，且不依赖拓扑数组顺序。
- 未知逻辑区域不会获得哈希生成的伪坐标。

最终验证：

| 命令 | 结果 | 退出码 |
|---|---|---:|
| `.\Godot_v4.7.1-stable_win64_console.exe --version` | `4.7.1.stable.official.a13da4feb` | 0 |
| `.\Godot_v4.7.1-stable_win64_console.exe --headless --editor --path . --quit` | 编辑器完成资源扫描，无解析错误 | 0 |
| `.\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd` | `PASS: 40525 project assertions` | 0 |
| `.\Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 30` | 主场景 headless 冒烟完成 | 0 |
| `git diff --check 55ea978` | 无空白错误 | 0 |

## 人工窗口检查

环境：Windows，Godot 4.7.1，简体中文，UI 100%，1280×720 逻辑窗口；
系统 200% 缩放使捕获文件为 2560×1440 物理像素。

已检查：

- 普通观察中试管和喂食口可见。
- 打开布局后设施位置不变，只增加网格、设施名称和镜头控制。
- 关闭布局后设施不消失、不跳位。
- WASD 平移和重置视图时，蚁后与幼体跟随其设施移动。
- F3 调试层可打开和关闭，关闭后普通观察仍可使用。
- 1280×720 下没有横向滚动或面板重叠；世界画面区域超过主界面 65%。

截图：

- `docs/ux/r19_unified_world/01_observation_same_world_1280x720_zh_100.png`
- `docs/ux/r19_unified_world/02_layout_editing_same_world_1280x720_zh_100.png`

## 边界与未完成项

- 未新增玩法、权威状态、Resource 参数、命令、固定 Tick 语义或存档字段。
- 未加入正式生物／设施素材。
- 新顶部栏、目标轨迹、情境操作栏、检查器抽屉、直接世界交互和完整镜头
  聚焦／跟随尚未实现。
- 用户已明确允许不等待“7 名有效首次接触测试者”；本记录不把缺失的外部
  首测数据声明为通过。
