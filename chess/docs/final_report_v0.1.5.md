# chess in war v0.1.5 最终形态报告

## 当前状态

**技术完成，待试玩评价。**

v0.1.5 已完成 3 个新己方、6 个新敌方、全敌方普通/精英分层、六关部署、两张新地图、四类隐藏一次性机遇和纯 Windows 最小运行说明。Windows Godot 导入、运行与图形检查通过，自动化测试为 `263 passed, 0 failed`。

## 完成功能

| 系统 | 最终状态 |
|---|---|
| 己方单位 | 总计 8 种；新增重盾卫士、决斗者、长弓手，全部单位具备明确强项和弱项 |
| 敌方单位 | 总计 10 种；新增 6 种，全部定义具有 `normal` 或 `elite` 级别 |
| 数值分层 | 普通敌人平均综合值约为己方的 2/3，精英约为 5/3；级别不改变行动规则 |
| 六个关卡 | 每关 3 名己方、6-9 名敌方、至少 1 名精英；部署并集覆盖全部单位种类 |
| 新地图 | Orchard Ambush 10x10；Iron Mire 14x12；第四关固定种子继续可复现 |
| 机遇 | 水果、精铁、泥沼、补给；双方沿实际路径逐格触发，HP 有上限、护盾可增加、触发后消失、Restart 恢复 |
| 隐藏表现 | 棋盘和悬停不显示未触发机遇，只在触发后通过中文日志反馈 |
| 中文化 | 18 个单位中文名、敌方普通/精英级别和机遇日志；英文内部键、缩写及导航保持不变 |
| Windows 说明 | README 记录最少两个包、获取位置、建议目录、相对项目路径和 F5 启动步骤 |
| 兼容性 | 元素能力、分段移动、护盾伤害、远程高度、AI 绕障、百科、数值覆盖和 Menu 继续通过回归 |

## 技术验收

| 验收项 | 结果 |
|---|---|
| 上一版保护 | `chess_v0.1.4` 快照存在；修改前基线复测 196/0 |
| 数据与单位 | 六关全部通过校验；8 种己方、10 种敌方、18 个中文名称和敌方级别通过测试 |
| 数值目标 | 测试加权模型中普通比例位于 0.58-0.75、精英比例位于 1.55-1.78 |
| 机遇规则 | 路径中间格/终点、多个实例、双方、满 HP、一次性和 Restart 均通过 |
| 自动化 | 完整回归 263 项通过，0 失败 |
| 图形 | 七张 1100x720 截图非空且检查无不可访问关卡、裁切、重叠或文本溢出 |
| 导入与运行 | Windows Godot 4.7.2 导入退出码 0；图形运行成功 |
| 文档 | README、规则、结构、数据格式、测试记录、本报告和策划基线已同步 |

以上是技术验收，不代表人类试玩验收。当前状态保持“技术完成，待试玩评价”。

## 运行位置

```text
Godot: D:\software\Godot\Godot_v4.7.2-stable_win64.exe
项目:  \\wsl.localhost\Ubuntu-20.04\home\xu\program-909\software\v1\chess\project.godot
WSL:   /home/xu/program-909/software/v1/chess
快照:  /home/xu/program-909/software/v1/chess_v0.1.4
```

## 交付物

- v0.1.5 活动项目源码、六关及全部 JSON 数据。
- `BattleOpportunityState`、机遇定义与地图实例。
- `docs/rules_reference_v0.1.5.md`、`docs/v0.1.5_test_record.md`、本报告。
- 七张 `v0.1.5_*.png` 图形检查截图。
- `/home/xu/program-909/v1/main_v0.1.5.md` 和追加后的 `code_note`。

## 导出与 Git

Windows Desktop 导出目标为 `export/chess-in-war-v0.1.5.exe`。本轮导出已实际执行并因缺少 Godot 4.7.2 的 `windows_debug_x86_64.exe` 与 `windows_release_x86_64.exe` Export Templates 失败，未生成独立 EXE；项目可直接通过 Godot 运行。

本轮未创建提交、标签或推送。活动仓库保持 `main`，远端为 `git@github.com:xu-23/software_v1.git`；历史快照继续作为未跟踪目录保留。
