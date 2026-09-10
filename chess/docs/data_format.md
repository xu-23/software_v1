# v0.1.0 数据格式

所有配置文件使用 UTF-8 JSON，运行时路径以 `res://data/` 为根。

## 地形

文件：`data/terrain/terrain_defs.json`

```json
{
  "id": "forest",
  "name": "Forest",
  "passable": true,
  "move_cost": 2,
  "height": 1,
  "color": "#65876a"
}
```

`move_cost` 和 `height` 必须是非负整数；`color` 仅供棋盘表现使用。

## 边界类型

文件：`data/terrain/edge_defs.json`

```json
{
  "id": "river",
  "name": "River",
  "passable": true,
  "extra_move_cost": 1,
  "blocks_melee": false,
  "blocks_ranged": false
}
```

地图未声明的相邻格边界自动视为 `normal`。

## 单位

文件：`data/units/player_units.json`、`data/units/enemy_units.json`

```json
{
  "id": "player_002",
  "name": "Archer",
  "team": "player",
  "unit_type": "ranged",
  "class_id": "archer",
  "max_hp": 14,
  "shield": 3,
  "attack": 4,
  "move_range": 4,
  "attack_range": 2,
  "true_damage": false,
  "sprite": ""
}
```

近战单位的 `attack_range` 必须为 1；远程单位必须至少为 1。当前占位表现不读取 `sprite`，字段保留供后续替换资源。

## 地图

文件：`data/maps/map_001.json`

- `width`、`height`：地图尺寸。
- `tiles`：按 y 行、x 列存储的二维地形 ID 数组。
- `edges`：只记录非普通边界，每项包含唯一 `id`、坐标数组 `a`、`b` 和 `edge_type`。
- 边界两端必须在地图内且曼哈顿距离为 1，运行时自动双向生效。

```json
{
  "id": "edge_001",
  "a": [3, 6],
  "b": [3, 7],
  "edge_type": "river"
}
```

## 关卡

文件：`data/chapters/chapter_001.json`

关卡引用地图 ID，并以单位 ID 到 `[x, y]` 的对象定义双方出生点。出生点必须在地图内、地形可通行且不能重复。

## 最小扩展步骤

新增单位：在对应阵营 JSON 的 `units` 数组中增加对象，并在关卡出生点中添加该 ID。

新增普通地形或边界类型：先增加定义，再在地图 `tiles` 或 `edges` 中引用其 ID。

新增关卡：增加地图与关卡 JSON，并在 `GameDataLoader.load_game_data()` 中切换加载路径；多关卡选择器属于后续版本。

修改数据后必须执行自动测试。数据校验失败时，游戏阻止进入战斗并在 Godot 输出中给出错误字段。
