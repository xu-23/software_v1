# chess in war

`v0.1.1` 是一个使用 Godot 4.7.2 制作的单机 2D 回合制战棋可运行原型。

当前版本包含一张 10x10 地图、2 个玩家单位、3 个敌方单位、地形与高度、河流与悬崖边界、移动寻路、近战与远程攻击、护盾伤害、敌方 AI、回合循环及胜负结算。v0.1.1 增加悬停信息、路径与成本预览、战斗日志、最近行动标记、攻击取消状态恢复和敌方分步行动。

## 启动

1. 打开 `D:\software\Godot\Godot_v4.7.2-stable_win64.exe`。
2. 导入项目：`\\wsl.localhost\Ubuntu-20.04\home\xu\program-909\software\v1\chess\project.godot`。
3. 点击 Godot 右上角运行项目按钮，或按 `F6`/`F5`。

## 操作

- 左键选择玩家单位、移动到蓝色范围格、选择红色范围内的敌人。
- `Attack` 进入攻击目标选择。
- `Wait` 完成当前单位行动。
- `End Turn` 跳过剩余玩家单位。
- 悬停可移动格可查看最小消耗路径和路径成本。
- 右键或 `Esc` 取消当前选择；在攻击目标选择中会返回上一操作状态。
- `Restart Battle` 重置关卡。

## 自动测试

在 WSL 中执行：

```bash
/mnt/d/software/Godot/Godot_v4.7.2-stable_win64.exe \
  --headless \
  --path '\\wsl.localhost\Ubuntu-20.04\home\xu\program-909\software\v1\chess' \
  --script res://tests/test_runner.gd
```

测试成功时退出码为 `0`，并输出 `TEST SUMMARY: 46 passed, 0 failed`。

## 文档

- `docs/game_rules_v0.1.0.md`：版本规则基线。
- `docs/code_structure.md`：模块和调用关系。
- `docs/data_format.md`：JSON 配置格式与扩展方式。
- `docs/v0.1.0_test_record.md`：测试结果和已知限制。
- `docs/final_report_v0.1.0.md`：最终形态报告。
- `docs/v0.1.1_test_record.md`：v0.1.1 回归和新增功能测试。
- `docs/final_report_v0.1.1.md`：v0.1.1 最终形态报告。
