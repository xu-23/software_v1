# v0.1.4 代码结构

## 入口与界面

| 文件 | 职责 |
|---|---|
| `project.godot` | 项目版本、窗口、渲染器和主场景配置 |
| `scenes/main/Main.tscn` | 唯一运行入口 |
| `scripts/ui/main.gd` | 2x2 关卡选择、战斗 HUD、中文战斗信息、Menu 和单位图鉴 |
| `scripts/ui/battle_board.gd` | 动态绘制地形、边界、范围、路径、单位、职业角标和远程射程数字 |
| `scripts/ui/unit_icon_formatter.gd` | 名称缩写与职业标识类型映射 |
| `scripts/ui/unit_name_localizer.gd` | 英文标准单位名到中文显示名称的唯一映射 |

`Main` 只通过控制器接口提交战斗操作。Encyclopedia 读取应用数值覆盖后的静态单位定义，通过 `UnitNameLocalizer` 显示中文名称，只切换视图，不修改进行中的战斗。

## 战斗流程

| 文件 | 主要接口 | 职责 |
|---|---|---|
| `scripts/battle/battle_controller.gd` | `start_new_battle`、`stop_battle`、`select_at`、`click_at`、`request_attack`、`end_player_turn` | 关卡加载、状态机、中文日志、能力接入、输入锁和敌方回合编排 |
| `scripts/battle/victory_checker.gd` | `check` | 根据双方存活单位判断胜负 |
| `scripts/ai/enemy_ai.gd` | `take_turn` | 目标选择、合法攻击位置寻路、绕障移动、攻击和 AI 能力触发 |

`start_new_battle(chapter_id, stat_overrides := null)` 默认读取磁盘覆盖配置，也允许代码直接传入相同结构。控制器维护最近 8 条 `battle_log`、`last_action` 和 `battle_generation`；generation 防止 Restart 或 Levels 前的异步任务修改新状态。

## 地图与战斗规则

| 文件 | 主要接口 | 职责 |
|---|---|---|
| `scripts/grid/grid_map_data.gd` | `get_terrain`、`get_height`、`get_edge`、`get_step_cost` | 地图查询、最低进入移动力、地形与边界代价 |
| `scripts/grid/movement_calculator.gd` | `calculate`、`build_path` | 按剩余预算计算可达范围和最低成本路径 |
| `scripts/combat/attack_range_calculator.gd` | `can_attack`、`can_attack_from`、`range_cells` | 近战 Cliff 与远程不可低打高规则 |
| `scripts/combat/special_ability_resolver.gd` | `apply_terrain_entry`、`attack_multiplier` | 木/土地形效果和火属性攻击倍率的唯一规则源 |
| `scripts/combat/damage_calculator.gd` | `apply` | 倍率、护盾、真实伤害、HP 与死亡结算 |

## 数据模块

| 文件 | 主要接口 | 职责 |
|---|---|---|
| `scripts/data/data_loader.gd` | `load_game_data` | 加载目录、公共定义、单位覆盖、静态或程序地图和关卡 |
| `scripts/data/data_validator.gd` | `validate`、`validate_catalog` | 校验目录、地图、出生点、能力引用、同名模板和生成错误 |
| `scripts/data/unit_stat_overrides.gd` | `apply_to_data`、`apply_to_definitions`、`validate` | 只覆盖 HP、护盾、攻击、移动并拒绝固定字段变更 |
| `scripts/data/procedural_map_generator.gd` | `generate`、`anchors_connected` | 局部随机数、配额放置、出生保护和连通性保持 |
| `scripts/data/unit_definition_catalog.gd` | `unique_by_name` | 生成按名称去重排序的图鉴定义 |
| `scripts/units/unit_model.gd` | `from_data`、`reset_turn`、`snapshot` | 单位静态属性、运行时数值和能力触发记录 |
| `scripts/units/unit_registry.gd` | `add_unit`、`get_unit`、`living` | ID 查询、占格查询和阵营存活列表 |

## 调用关系

```text
Main UI -> BattleController
              -> GameDataLoader
                   -> UnitStatOverrides
                   -> ProceduralMapGenerator
              -> GameDataValidator
              -> BattleGrid / BattleUnitRegistry / BattleUnit
              -> MovementCalculator / AttackRangeCalculator
              -> SpecialAbilityResolver / DamageCalculator
              -> EnemyAI / VictoryChecker

Encyclopedia -> GameDataLoader -> UnitStatOverrides -> UnitDefinitionCatalog
Main / BattleController -> UnitNameLocalizer
BattleBoard -> UnitIconFormatter（继续读取英文标准名）
```

## 扩展约束

- 普通内容优先通过 JSON 扩展；身份和规则字段保留在单位定义中，平衡数值写入覆盖文件。
- `name` 是单位模板一致性键；同名定义的静态字段及覆盖结果必须一致。
- 玩家与 AI 不得复制能力、攻击、移动或地形规则。
- 程序地图必须使用局部随机数、明确种子、受保护出生点和连通性测试。
- 新关卡需增加目录、地图规格、出生点、数据校验和自动化覆盖。
