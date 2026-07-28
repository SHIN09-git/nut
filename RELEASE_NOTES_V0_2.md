# Colony Under Glass v0.2 Demo 候选说明

日期：2026-07-28

冻结运行时提交：`816995e51f82acb732144068f6dcaca7b76c99c0`

分支：`release/v0.2-demo-candidate`

## 版本定位

这是一个 Windows 灰盒 Demo 候选，用于验证：

> 观察首工羽化 → 认识稳定个体 → 改变巢室环境 → 观察幼体搬运改变 → 放置糖水 → 观察自主觅食与分享

本版本没有增加新的模拟玩法，只把现有五阶段连续观察收口为可启动、可完成、可重开、可退出的发行候选。

## 本次新增

- 暂停菜单：继续观察、重新开始、退出游戏。
- 1280×720 与 1920×1080 窗口分辨率。
- 窗口／全屏即时切换。
- 简体中文与临时英文即时切换。
- 玩家可见文本迁移到 Godot 翻译资源。
- 暂停菜单、显示状态、语言和退出路径的自动测试。
- Windows release 导出、headless 冒烟和真实窗口完整流程验证。

暂停菜单与显示设置属于应用层，不推进固定 Tick、不消费模拟命令、不改变快照。当前设置不会跨程序会话保存。

## 构建

分发时必须同时提供 EXE 与 PCK，建议使用 ZIP：

| 文件 | 字节 | SHA-256 |
| --- | ---: | --- |
| `ColonyUnderGlass_v0.2_demo.exe` | 109,071,360 | `04BAF75CC1D69DD93EB709533ECAB4FD7770BB8A530645717017A06A9D9809FC` |
| `ColonyUnderGlass_v0.2_demo.pck` | 5,132,288 | `62EA6B8FA7379A56BCB424270D56C96D15DA7CA3F6E212ED64D45540963A3D2C` |
| `ColonyUnderGlass_v0.2_demo.zip` | 41,078,537 | `D4FAC61CDC549AEF76EE630D6AC7D983487561F2A93CEE216D1E363A29E29CBF` |

本机输出目录为 `builds/windows/`；该目录被 Git 忽略，不进入仓库。

## 已验证

- Godot `4.7.1.stable.official.a13da4feb`。
- 编辑器 headless 解析通过。
- 标准 runner：`PASS: 3000 project assertions`。
- 默认主场景 headless 冒烟通过。
- Windows release 导出和 release EXE headless 冒烟通过。
- 1280×720、1920×1080、窗口和全屏布局通过人工检查。
- 简体中文与临时英文暂停菜单没有重叠或截断。
- 真实 UI 路径完成首工观察、三次补水、可见搬运改变、糖水闭环和三张观察卡总结。
- 关闭 F3 时仍可辨认工蚁携带幼体；release 中 F3 无可见效果。
- 完成后重新开始返回 Tick 0 准备门，随后可从暂停菜单正常退出。

详细证据见 `docs/validation/v0_2_m5_demo_candidate_001.md`。

## 外部 Gate 状态

`CODEX_V0_2_MASTER_PLAN.md` 要求的 7 名有效首次接触测试者数据没有取得，因此外部理解度 Gate 仍为：

```text
INCOMPLETE / WAIVED AS PREREQUISITE
```

用户于 2026-07-28 明确要求跳过该阻塞并继续完成游戏。这里记录的是产品决策，不是测试通过；仓库没有伪造任何测试者结果。

## 已知限制

- 当前无停顿自动路径仍约为 58.6 模拟秒，不是经外测证明的 12～15 分钟首通体验。
- 英文为临时翻译，仍需用户最终人工校对。
- 没有存档或设置持久化。
- 名称、选择和个人行动记录在重开或退出后清除。
- 物种、生命周期、湿度和行为数值均为未经科学审校的 `prototype_pacing_fixture`。
- 没有蛋白质、饥饿、能量、经济、设施建造、自由地图、镜头跟随、正式素材、音频、Steam 或第三方插件。
- 本候选不是 v1.0 完整游戏，也没有合并 `main`、创建 Tag 或发布 GitHub Release。
