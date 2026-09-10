# chess in war v0.1.2 最终形态报告

## 完成结论

v0.1.2 已完成关卡选择、第二关、累计移动点、多段移动、Move 命令、Menu、动态棋盘、沼泽以及远程不可低打高规则。第一关继续保持 v0.1.1 的地图、出生点和单位数量。

Windows Godot 4.7.2 的项目导入通过，自动化测试 `80 passed, 0 failed`；关卡选择、第一关、第二关和 Menu 四种图形状态均通过 1100x720 截图检查。

## 最终功能

| 系统 | 最终状态 |
|---|---|
| 关卡选择 | 启动时显示 First Contact 与 Flooded Pass，两关均可直接进入 |
| 第一关 | 10x10，2 名玩家对 3 名敌人，保持原配置 |
| 第二关 | 12x12，3 名玩家对 5 名敌人，包含 Plain/Forest/Swamp/Water/Mountain |
| 累计移动 | 单位可在剩余移动点内分段移动，显示剩余值与累计消耗 |
| Move | 保留直接点击移动，同时可从攻击状态返回移动状态 |
| 沼泽 | 至少 2 点方可进入，进入后清空剩余移动点 |
| 高度 | 不参与移动；远程可攻击基础射程内同高或更低的目标 |
| AI | 维护移动预算，远程单位优先选择可形成合法攻击的高地 |
| Menu | 提供当前关卡 Restart 与返回 Levels，并在打开时锁定棋盘输入 |
| 动态棋盘 | 10x10 与 12x12 均按可用区域居中完整绘制 |
| 数据 | 目录驱动关卡加载，按关卡出生点实例化单位并执行校验 |

## 验收结果

| 验收范围 | 结果 |
|---|---|
| C001-C008 | 版本、多段移动、Move/直接移动、扣点与行动结束规则通过 |
| C009-C013 | 两关选择、第一关兼容、第二关内容和沼泽规则通过 |
| C014-C018 | 规则文档、1100x720 UI、80 项测试、远程高度规则和 Menu 通过 |

## 运行位置

```text
Godot: D:\software\Godot\Godot_v4.7.2-stable_win64.exe
项目:  \\wsl.localhost\Ubuntu-20.04\home\xu\program-909\software\v1\chess\project.godot
WSL:   /home/xu/program-909/software/v1/chess
```

## 交付状态

当前交付物为可在 Godot 中运行和继续开发的 v0.1.2 项目，包含源码、两关 JSON 数据、自动化测试、规则参考、测试记录、最终报告和四张图形检查截图。

Windows Desktop 导出预设已将目标文件更新为 `export/chess-in-war-v0.1.2.exe`。本机仍缺少 Godot 4.7.2 Export Templates，因此未生成独立 EXE。
