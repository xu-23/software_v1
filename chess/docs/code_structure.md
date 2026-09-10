# v0.1.0 代码结构

## 入口与界面

| 文件 | 职责 |
|---|---|
| `project.godot` | 项目名称、窗口、渲染器和主场景配置 |
| `scenes/main/Main.tscn` | 唯一运行入口 |
| `scripts/ui/main.gd` | 创建桌面布局、HUD、日志、悬停信息、按钮并同步控制器状态 |
| `scripts/ui/battle_board.gd` | 绘制地图、地形、边界、范围、路径、最近行动、单位并处理棋盘鼠标输入 |

## 战斗流程

| 文件 | 主要接口 | 职责 |
|---|---|---|
| `scripts/battle/battle_controller.gd` | `start_new_battle`、`select_at`、`click_at`、`request_attack`、`cancel_current_action`、`wait_selected`、`end_player_turn` | 战斗状态机、日志、最近行动和分步回合编排 |
| `scripts/battle/victory_checker.gd` | `check` | 根据存活单位判断胜负 |
| `scripts/ai/enemy_ai.gd` | `take_turn` | 目标选择、移动和攻击决策 |

控制器公开 `state_changed` 信号，并维护最近 8 条 `battle_log` 与只供表现使用的 `last_action`。界面只调用控制器公开操作，不在 UI 中重复计算移动或伤害。

敌方回合在有场景树时按单位间隔播放，通过 `battle_generation` 阻止重开前的异步任务继续修改新战斗；无场景树或测试间隔为 0 时同步完成。

## 地图与规则计算

| 文件 | 主要接口 | 职责 |
|---|---|---|
| `scripts/grid/grid_map_data.gd` | `get_terrain`、`get_edge`、`get_step_cost`、`neighbors` | 地图查询和单步代价 |
| `scripts/grid/movement_calculator.gd` | `calculate`、`build_path` | 按加权代价计算可达范围和路径 |
| `scripts/combat/attack_range_calculator.gd` | `effective_range`、`can_attack`、`range_cells` | 近远程、高度及悬崖规则 |
| `scripts/combat/damage_calculator.gd` | `apply` | 护盾、真实伤害、死亡结算 |

`MovementCalculator` 使用小规模 Dijkstra 搜索，支持不同地形、上坡和边界代价。10x10 地图无需更复杂的优先队列结构。

## 单位与数据

| 文件 | 职责 |
|---|---|
| `scripts/units/unit_model.gd` | 单位静态属性、运行时状态和回合重置 |
| `scripts/units/unit_registry.gd` | 单位 ID 查询、占格查询、阵营存活列表 |
| `scripts/data/data_loader.gd` | 读取项目 JSON 文件并报告解析错误 |
| `scripts/data/data_validator.gd` | 校验 ID、字段、类型、地图尺寸、边界和出生点 |

## 调用关系

```text
Main UI
  -> BattleController
       -> GameDataLoader -> GameDataValidator
       -> BattleGrid
       -> BattleUnitRegistry -> BattleUnit
       -> MovementCalculator
       -> AttackRangeCalculator -> DamageCalculator
       -> EnemyAI
       -> VictoryChecker
```

纯计算模块不依赖场景节点或 UI，可由 `tests/test_runner.gd` 直接执行。

## 扩展约束

- 先通过 JSON 增加普通地形、边界和单位，不在算法中添加 ID 分支。
- 独立规则确实无法由现有字段表达时，才增加计算模块接口。
- UI 继续只显示状态和提交命令。
- 新规则需要在 `tests/test_runner.gd` 中增加对应断言。
