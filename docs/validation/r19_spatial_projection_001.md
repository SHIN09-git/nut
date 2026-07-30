# R19-A 统一空间投影基础验证记录

## 结果

R19-A 已建立后续“观察与布局共用同一世界”的纯空间基础，但尚未宣称 R19
完成。当前画面仍沿用既有观察／布局投影；下一工作包才会把两个显示路径
迁入统一投影。

分支：`codex/feat/r19-spatial-projection`

基线提交：`47348dc`

## 实现

- 新增 `HabitatSpatialProjection`：
  - 将逻辑网格等比适配到调用方内容矩形。
  - 投影设施槽位和占地矩形。
  - 在单元边界给出旋转后设施接口坐标。
  - 给单室和四种方向的双室设施生成区域锚点。
  - 生成连接端点。
  - 按布局层和稳定设施 ID 生成确定性命中结果。
- 新增 `FacilityPortSnapshot`。
- `FacilitySnapshot` 深复制设施接口几何。
- `ColonySimulation` 创建布局快照时，从冻结目录计算旋转后的全局接口
  单元和方向；运行中的 View 不读取原始 Resource。

## 边界

- 没有修改 `ColonyState`、`HabitatLayoutState` 或设施效果。
- 没有修改固定 Tick、命令顺序、章节条件、配置 Resource 或存档 schema。
- 新接口字段只存在于复制后的布局快照，修改它不能改变权威状态。
- 没有加入 HUD、相机跟随、直接世界交互、正式素材或新玩法。

## 自动测试

新增 `habitat_spatial_projection_test_suite.gd`，覆盖：

- 非法网格与过大边距被拒绝。
- 等比适配、居中、槽位矩形和逆向槽位映射。
- 北、东、南、西四个接口的精确单元边界坐标。
- 正式 Act 1 初始试管接口的旋转后全局单元、方向与连接种类。
- 接口快照隔离。
- 双室设施四种方向的主／次区域锚点。
- 内部连接端点。
- 设施数组倒序不改变区域锚点和命中所有权。

最终验证：

| 命令 | 结果 | 退出码 |
|---|---|---:|
| `.\Godot_v4.7.1-stable_win64_console.exe --version` | `4.7.1.stable.official.a13da4feb` | 0 |
| `.\Godot_v4.7.1-stable_win64_console.exe --headless --editor --path . --quit` | 编辑器完成资源扫描，无解析错误 | 0 |
| `.\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd` | `PASS: 40514 project assertions` | 0 |
| `.\Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 30` | 主场景 headless 冒烟完成 | 0 |
| `git diff --check 47348dc` | 无空白错误 | 0 |

## 人工检查

未执行，也不需要把现有画面误判为新投影已经可见。R19-A 没有把投影接入
渲染节点，因此没有可见画面变化。R19-B 接入统一世界后必须重新执行真实
窗口对照。
