# chess in war v0.1.3 最终形态报告

## 当前状态

**技术完成，待试玩评价。**

v0.1.3 已根据 `pre_v0.1.3.md` 及试玩反馈完成单位名称模板规范、Encyclopedia、Forest/Hill 规则、三个元素单位及能力、第三关、单位信息中文化、名称缩写图标和 AI 绕障优化。Windows Godot 导入与图形运行通过，自动化测试为 `141 passed, 0 failed`，五个版本化界面状态已完成截图检查。

## 完成功能

| 系统 | 最终状态 |
|---|---|
| 单位模板 | `name` 作为静态模板一致性键，`id` 用于具体实例；同名冲突阻止关卡启动 |
| Encyclopedia | Menu 入口、Allies/Enemies 分页、按名称去重、完整数值/属性/能力、Back 保留战斗 |
| 单位信息中文化 | 保留英文导航和单位名称，单位字段、类型、职业、属性、布尔值及能力说明显示中文 |
| 名称图标 | 棋盘与图鉴按英文单位名称生成 A、VG、EW 等统一缩写 |
| 地形 | Forest 高度 0、Hill 高度 1，两者最低进入移动力和消耗均为 2 |
| 生生不息 | Verdant Guard 每回合首次移动至 Forest，当前护盾 +2，零护盾也生效 |
| 万物之源 | Earth Warden 每局首次移动至 Hill，有护盾时当前护盾翻倍 |
| 火烧联营 | Flamecaster 攻击 Forest 目标时伤害 x2，继续遵守护盾击碎无溢出 |
| 玩家与 AI | 地形进入和攻击倍率共用能力解析器；AI 以合法攻击位置规划路线，可主动绕过障碍 |
| 第三关 | Elemental Crossing，12x12，3 对 5，包含三个新单位、更多 Forest、6 River 和 6 Cliff |
| 兼容性 | 第一、第二关和 v0.1.0-v0.1.2 非冲突规则继续通过回归测试 |

## 技术验收

| 验收项 | 结果 |
|---|---|
| D001-D009 | 版本、名称规则、图鉴、地形、三种能力、第三关和旧关兼容均已实现并验证 |
| D010 | 141 项自动化断言，0 失败 |
| D011 | 关卡选择、第三关能力反馈、Menu、图鉴双方页完成 1100x720 图形检查 |
| D012 | README、规则、结构、数据、测试记录和本报告已同步 |
| D013-D017 | 单位信息中文化、名称图标、AI 暂时远离绕障、最终攻击和新增验证全部通过 |

上述为技术验收结果，不代表人类试玩验收。版本状态在用户实际游玩并评价前保持“技术完成，待试玩评价”。

## 运行位置

```text
Godot: D:\software\Godot\Godot_v4.7.2-stable_win64.exe
项目:  \\wsl.localhost\Ubuntu-20.04\home\xu\program-909\software\v1\chess\project.godot
WSL:   /home/xu/program-909/software/v1/chess
快照:  /home/xu/program-909/software/v1/chess_v0.1.2
```

## 交付物

- 活动项目源码、三个关卡及全部 JSON 数据。
- `docs/rules_reference_v0.1.3.md`。
- `docs/v0.1.3_test_record.md`。
- `docs/final_report_v0.1.3.md`。
- 五张 `v0.1.3_*.png` 图形检查截图。
- `/home/xu/program-909/v1/main_v0.1.3.md` 和追加后的 `code_note`。

## 导出与 Git

Windows Desktop 导出预设目标已更新为 `export/chess-in-war-v0.1.3.exe`。当前环境缺少对应 Export Templates，因此没有生成独立 EXE；项目可直接通过 Godot 运行。

本轮没有创建提交、标签或推送。活动仓库仍在 `main`，远端为 `git@github.com:xu-23/software_v1.git`，v0.1.2 与 v0.1.3 变更保留在工作区，等待用户试玩评价和后续明确的版本控制指令。
