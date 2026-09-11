# v0.1.5 数据格式

所有配置文件使用 UTF-8 JSON，运行时路径以 `res://data/` 为根。

## 单位基础定义

文件：`data/units/player_units.json`、`data/units/enemy_units.json`

```json
{
  "id": "player_004",
  "name": "Verdant Guard",
  "team": "player",
  "unit_type": "melee",
  "class_id": "soldier",
  "max_hp": 18,
  "shield": 4,
  "attack": 5,
  "move_range": 4,
  "attack_range": 1,
  "true_damage": false,
  "special_attribute": "wood",
  "ability_id": "renewal",
  "sprite": ""
}
```

`id` 标识实例定义，`name` 是英文模板一致性键。同名定义允许不同 ID，但静态字段必须一致。近战射程必须为 1，能力引用必须存在且属性一致。

敌方定义还必须包含 `rank`，值为 `normal` 或 `elite`。玩家定义不需要该字段；级别不改变战斗公式。

JSON 中不增加中文名称字段。百科和战斗信息通过 `UnitNameLocalizer` 将英文 `name` 转为中文显示名称；棋盘缩写和数值覆盖键仍使用英文标准名称。未知名称回退显示原值。

## 单位数值覆盖

文件：`data/units/unit_stat_overrides.json`

```json
{
  "units": {
    "Vanguard": {"max_hp": 20, "shield": 7, "attack": 6, "move_range": 4},
    "Raider": {"attack": 5}
  }
}
```

| 字段 | 最小值 | 说明 |
|---|---:|---|
| `max_hp` | 1 | 新关卡中的最大与初始 HP |
| `shield` | 0 | 新关卡中的基础与初始护盾 |
| `attack` | 0 | 攻击值 |
| `move_range` | 0 | 每回合移动力 |

- 单位键必须是已定义英文 `name`，同名实例全部应用。
- 只填写需要改变的字段；空 `units` 表示全部采用基础值。
- 值必须是整数。其他字段、未知名称和越界值会阻止关卡启动。
- 加载顺序为基础单位 JSON -> 数值覆盖 -> 完整数据校验 -> 创建战斗单位。
- 保存覆盖后 Restart、重新进入关卡或重启游戏生效；进行中的运行时数值不热更新。

## 地形与边界

文件：`data/terrain/terrain_defs.json`、`data/terrain/edge_defs.json`

地形字段包括 `id`、`name`、`passable`、`move_cost`、可选 `minimum_entry_points`、可选 `move_rule`、`height` 和 `color`。Swamp 使用 `consume_all`；Water 与 Mountain 不可通行。

边界字段包括 `id`、`name`、`passable`、`extra_move_cost`、`blocks_melee` 和 `blocks_ranged`。地图未声明边界时使用 Normal；River 额外消耗 1，Cliff 阻挡移动和跨边界近战。

## 能力

文件：`data/abilities/ability_defs.json`

能力必须具有唯一 `id`、`name`、`special_attribute`、`trigger` 和中文 `description`。无特殊属性的单位使用 `none` 且 `ability_id` 为空。

## 机遇定义与地图实例

公共定义文件：`data/opportunities/opportunity_defs.json`

```json
{
  "id": "forest_fruit",
  "name": "水果",
  "terrain_ids": ["forest"],
  "effect": "hp",
  "amount": 1
}
```

`effect` 只允许 `hp` 或 `shield`，`amount` 必须为正整数，`terrain_ids` 中的地形必须存在。

地图根对象可包含：

```json
"opportunities": [
  {"id": "opp_001", "opportunity_id": "forest_fruit", "position": [3, 4]}
]
```

实例 ID 和坐标在单张地图内唯一。坐标必须位于可通行格，底层地形必须被定义允许，且不得与出生点重叠。未声明数组等价于没有机遇。运行时会复制这些实例并在触发后移除，不修改 JSON。

## 静态地图

`map_001.json` 至 `map_003.json`、`map_005.json` 和 `map_006.json` 直接保存：

- `width`、`height`：地图尺寸。
- `tiles`：按 y 行、x 列存储的二维地形 ID。
- `edges`：非普通边界，每项含唯一 ID、相邻端点 `a`/`b` 和 `edge_type`。

## 程序地图规格

`map_004.json` 保存生成规格：

```json
{
  "id": "map_004",
  "width": 12,
  "height": 12,
  "generation": {
    "seed": 104014,
    "terrain_counts": {"forest": 28, "hill": 18, "swamp": 12, "water": 10, "mountain": 8},
    "edge_counts": {"river": 10, "cliff": 10},
    "protected_tiles": [[1, 11]],
    "connectivity_anchors": [[1, 11], [1, 0], [6, 6]]
  }
}
```

加载器识别 `generation` 后调用 `ProceduralMapGenerator`，输出与静态地图相同的 `tiles`、`edges` 和显式 `opportunities`。相同种子生成相同结果；受保护格保持 Plain，锚点在不可通行地形和 Cliff 放置后仍须互相连通。生成配额不足会成为数据校验错误。

## 关卡与目录

`chapter_*.json` 通过 `map_id` 引用地图，并用单位 ID 到 `[x, y]` 的对象定义双方出生点。出生点必须位于可通行地形、不能重叠且阵营引用正确。

`chapter_catalog.json` 提供关卡选择信息与地图/关卡路径。v0.1.5 包含 `stage_001` 至 `stage_006`；每关恰好 3 名玩家、6 至 9 名敌人并至少有 1 名精英。第四关目录仍指向生成规格 JSON，无需 UI 特判。
