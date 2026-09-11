# chess in war

`v0.1.5` 是使用 Godot 4.7.2 制作的单机 2D 回合制战棋原型。当前版本包含六张可选地图、8 种己方单位、10 种普通/精英敌人、隐藏一次性机遇、分段移动、近战/远程攻击、元素能力、中文单位信息、敌方 AI、回合循环和胜负结算。

## 纯 Windows 最小运行包

只通过 Godot 编辑器打开并游玩源码项目时，最少需要两个包：

1. `Godot_v4.7.2-stable_win64.exe`：从 [Godot Windows 官方下载页](https://godotengine.org/download/windows/) 获取标准版压缩包并解压。不需要 .NET 版，也不需要 Export Templates。
2. `software_v1-main`：从 [GitHub 仓库](https://github.com/xu-23/software_v1) 选择 `Code > Download ZIP`，然后解压；也可使用 Git 获取仓库。

建议放置结构：

```text
D:\chess-in-war\
├── Godot\
│   └── Godot_v4.7.2-stable_win64.exe
└── software_v1-main\
    └── chess\
        └── project.godot
```

从 `Godot` 文件夹出发，项目文件的相对路径是：

```text
..\software_v1-main\chess\project.godot
```

双击 Godot EXE，选择 `Import`，定位上述 `project.godot`，完成导入后按 `F5`。纯 Windows 游玩不需要 WSL、VS Code、Python、编译器或 Git；首次获得两个压缩包时需要网络，解压并成功导入后可离线运行。

## 启动（开发版本，代码包存在linux环境下）

1. 打开 `D:\software\Godot\Godot_v4.7.2-stable_win64.exe`。
2. 导入 `\\wsl.localhost\Ubuntu-20.04\home\xu\program-909\software\v1\chess\project.godot`。
3. 按 `F5` 运行项目。
4. 选择任一关卡并点击 `Deploy`。

## 操作

- 左键选择玩家单位，再点击蓝色可达格移动；仍有移动点时可继续分段移动。
- `Move` 从攻击选择返回移动状态，`Attack` 进入攻击目标选择。
- 远程单位只能攻击基础射程内、地形高度不高于攻击者的敌人。
- `Wait` 完成当前单位行动，`End Turn` 结束玩家回合。
- `Menu > Restart` 重开当前关卡，`Menu > Levels` 返回关卡选择。
- `Menu > Encyclopedia` 打开单位图鉴，`Back` 返回并保留当前战斗。
- 右键或 `Esc` 取消当前操作。

## v0.1.5 内容

- 新增重盾卫士、决斗者、长弓手，以及游击兵、盾牌卫兵、猎手、铁甲统领、行刑官、攻城弓手。
- 普通敌人综合强度约为己方单位的 2/3，精英敌人约为 5/3；百科和战斗详情显示中文级别。
- 六关均部署 3 名己方、6 至 9 名敌方且至少一名精英；新增 10x10 `Orchard Ambush` 和 14x12 `Iron Mire`。
- 水果、精铁、泥沼和补给作为隐藏机遇。双方单位沿移动路径经过后立即获得 HP 或护盾效果，机遇随后从本局消失，Restart 时恢复。
- 地形、单位字段、单位显示名称、战斗状态和最近 8 条战斗日志使用中文；单位 JSON 标准名称、关卡名和命令按钮保持英文。
- 战士、掠夺者和弓手的棋盘头像右上角分别显示剑、马和弓；弓手左下角显示射程数字。
- 第四关 `Shattered Frontier` 继续使用固定种子生成的 12x12 地图。
- `unit_stat_overrides.json` 可按单位标准名称覆盖 HP、护盾、攻击和移动数值，不修改固定身份与规则字段。
- v0.1.4 的能力、AI 绕障、数值覆盖和其他非冲突规则保持不变。

## 调整数值

编辑 `data/units/unit_stat_overrides.json`：

```json
{
  "units": {
    "Vanguard": {"max_hp": 20, "shield": 7, "attack": 6, "move_range": 4},
    "Raider": {"attack": 5}
  }
}
```

允许字段只有 `max_hp`、`shield`、`attack`、`move_range`。键使用英文单位 `name`；同名 Raider 的全部实例会一起改变。保存后 Restart、返回 Levels 重新进入，或重启游戏即可让新关卡使用新数值。进行中的单位不会热更新。

代码可直接传入同样结构：

```gdscript
controller.start_new_battle("stage_001", {
    "units": {"Vanguard": {"max_hp": 20, "attack": 7}}
})
```

也可调用 `UnitStatOverrides.apply_to_definitions()` 修改一组内存定义。未知单位、禁止字段、非整数、负数或 `max_hp < 1` 会被拒绝。

## 自动测试

```bash
/mnt/d/software/Godot/Godot_v4.7.2-stable_win64.exe \
  --headless \
  --path '\\wsl.localhost\Ubuntu-20.04\home\xu\program-909\software\v1\chess' \
  --script res://tests/test_runner.gd
```

成功结果：`TEST SUMMARY: 263 passed, 0 failed`。

## 文档

- `docs/rules_reference_v0.1.5.md`：当前游戏规则、单位、敌方级别、六关与机遇。
- `docs/code_structure.md`：模块职责与调用关系。
- `docs/data_format.md`：JSON 配置、数值覆盖和程序地图格式。
- `docs/v0.1.5_test_record.md`：自动化和图形测试记录。
- `docs/final_report_v0.1.5.md`：v0.1.5 技术完成报告。
- v0.1.0-v0.1.4 的历史规则、记录、报告和截图均保留在 `docs/`。
