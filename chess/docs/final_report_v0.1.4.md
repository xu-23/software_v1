# chess in war v0.1.4 最终形态报告

## 当前状态

**技术完成，待试玩评价。**

v0.1.4 已完成战斗侧栏、百科与日志中文化、单位数值覆盖接口、三类职业图标和固定种子第四关。Windows Godot 导入、运行与图形检查通过，自动化测试为 `196 passed, 0 failed`。

## 完成功能

| 系统 | 最终状态 |
|---|---|
| 中文信息 | 地形、单位字段、单位显示名称、状态、移动、攻击、能力和最近 8 条日志使用中文；英文 JSON 名称与导航保留 |
| 名称映射 | 九个现有单位统一中文名；百科、侧栏和日志共用 `UnitNameLocalizer`，未知名称回退原值 |
| 数值覆盖 | 按单位 `name` 只允许 max_hp、shield、attack、move_range；错误配置阻止关卡启动 |
| 代码接口 | `UnitStatOverrides` 提供校验、定义覆盖和数据深拷贝覆盖；控制器允许传入覆盖对象 |
| 生效流程 | 磁盘配置在关卡加载时应用；Restart、重新进入或重启游戏后生效，不热改当前战斗 |
| 职业图标 | 战士剑、掠夺者马、弓手弓位于头像右上角；弓手左下角显示射程 |
| 第四关 | Shattered Frontier，12x12、4 对 6、固定种子 104014、全部地形、10 River 和 10 Cliff |
| 生成安全 | 局部随机数、配额检查、出生保护、锚点连通和相同种子可复现 |
| 兼容性 | 前三关、元素能力、AI 绕障、Menu、Encyclopedia 与历史非冲突规则继续通过回归 |

## 技术验收

| 验收项 | 结果 |
|---|---|
| D001 | v0.1.3 快照存在，版本为 0.1.3，快照复测 141/0 |
| D002-D004 | 中文化、四字段接口、错误拒绝和重载生效通过自动化验证 |
| D005 | 三种职业图标及远程射程数字完成 1100x720 图形验证 |
| D006-D007 | 第四关选择、启动、配额、连通、4 对 6、固定种子与 Restart 一致通过 |
| D008-D009 | 完整回归 196 项通过，0 失败 |
| D010 | 六张目标截图检查无空白、溢出、重叠或文本裁切 |
| D011 | README、规则、结构、数据格式、测试记录和本报告已同步 |
| D012 | 编辑器与游戏在交付时启动供人类试玩 |

以上是技术验收，不代表人类试玩验收。当前状态保持“技术完成，待试玩评价”。

## 运行位置

```text
Godot: D:\software\Godot\Godot_v4.7.2-stable_win64.exe
项目:  \\wsl.localhost\Ubuntu-20.04\home\xu\program-909\software\v1\chess\project.godot
WSL:   /home/xu/program-909/software/v1/chess
快照:  /home/xu/program-909/software/v1/chess_v0.1.3
```

## 交付物

- 活动项目源码、四个关卡及全部 JSON 数据。
- `data/units/unit_stat_overrides.json` 与 `UnitStatOverrides` 接口。
- `ProceduralMapGenerator`、第四关生成规格与出生定义。
- `docs/rules_reference_v0.1.4.md`、`docs/v0.1.4_test_record.md`、本报告。
- 六张 `v0.1.4_*.png` 图形检查截图。
- `/home/xu/program-909/v1/main_v0.1.4.md` 和追加后的 `code_note`。

## 导出与 Git

Windows Desktop 导出目标为 `export/chess-in-war-v0.1.4.exe`。当前电脑缺少 Godot 4.7.2 Windows Export Templates，导出尝试已明确失败，未生成独立 EXE；项目可直接通过 Godot 运行。

本轮未创建提交、标签或推送。活动仓库仍在 `main`，远端为 `git@github.com:xu-23/software_v1.git`；v0.1.2-v0.1.4 变更和版本快照保留在工作区。
