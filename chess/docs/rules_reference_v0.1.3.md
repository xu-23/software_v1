# chess in war v0.1.3 规则参考

## 回合与操作

- 玩家与敌方轮流行动；玩家可按任意顺序操作存活且尚未行动的单位。
- 单位在回合开始时恢复 `move_range` 点移动力，可在攻击或待机前分多段移动。
- 每段移动立即扣除最低路径成本；攻击、待机或手动结束回合会清空未使用移动力。
- 单位攻击或待机后结束本回合行动。敌方 AI 逐个移动、攻击或待机。
- 击败全部敌人即 Victory，玩家单位全部阵亡即 Defeat。
- `Menu` 提供 Restart、Levels 和 Encyclopedia；图鉴返回时保留当前战斗状态。

## 地形与移动

棋盘仅允许上下左右移动。友军格可经过但不可停留，敌军格不可经过或停留。高度不改变移动成本。

| 目标地形 | 通行 | 最低进入移动力 | 成功进入消耗 | 高度 |
|---|---|---:|---|---:|
| Plain | 是 | 1 | 1 | 0 |
| Forest | 是 | 2 | 2 | 0 |
| Hill | 是 | 2 | 2 | 1 |
| Swamp | 是 | 2 | 全部剩余移动力 | 0 |
| Water | 否 | - | - | 0 |
| Mountain | 否 | - | - | 10 |

| 边界 | 移动 | 近战 | 远程 |
|---|---|---|---|
| Normal | 正常 | 可跨越 | 可跨越 |
| River | 额外消耗 1 | 可跨越 | 可跨越 |
| Cliff | 阻挡 | 阻挡 | 不直接阻挡 |

进入普通地形、Forest 或 Hill 时，River 代价与目标地形代价相加。一次多格移动中的特殊能力只检查最终停留格，不检查路径经过格。

## 攻击与伤害

- 近战只能攻击曼哈顿距离 1 的敌人，不受高度影响，但不能跨 Cliff。
- 远程只能攻击基础 `attack_range` 内，且目标高度不高于攻击者高度的敌人。
- 高地不增加射程；同高和高打低允许，低打高禁止。
- 普通伤害优先扣护盾。一次攻击击碎护盾后，剩余伤害不溢出到 HP。
- 无护盾时普通伤害扣 HP；真实伤害绕过护盾直接扣 HP。
- 火属性的 2 倍倍率先形成实际伤害值，再执行上述护盾/HP 规则。

## 敌方 AI

- 若当前位置已有合法目标，AI 保持低 HP、低护盾优先并立即攻击。
- 无法立即攻击时，AI 比较本回合可达终点到合法攻击位置的实际路线代价。
- 合法攻击位置同时满足射程、高度和近战 Cliff 规则；路线遵守 Water、Mountain、Cliff、地形与边界移动代价。
- AI 可以暂时增大与玩家的曼哈顿距离，只要该移动缩短实际攻击路线。
- 所有攻击位置不可达时回退到曼哈顿接近规则；不存在更近终点时稳定待机。

## 特殊能力

### 生生不息

Verdant Guard 具有木属性。每回合第一次以 Forest 为移动终点时，当前护盾 +2；即使进入前护盾为 0 也生效。同回合再次进入不触发，下一回合恢复一次机会。

### 万物之源

Earth Warden 具有土属性。每局第一次以 Hill 为移动终点时，若当前护盾大于 0，则当前护盾翻倍。该次进入会消耗本局机会，即使当时护盾为 0；回合重置不会恢复，Restart 会恢复。

### 火烧联营

Flamecaster 具有火属性。它攻击当前位于 Forest 的单位时，基础攻击乘 2；目标位于其他地形时倍率为 1。AI 使用同一判定。

## 单位模板

`name` 是单位模板的一致性标准，`id` 只供关卡识别具体实例。同名定义的阵营、类型、职业、全部基础数值、真实伤害、特殊属性、能力和资源路径必须相同。战斗中的 HP、护盾、位置和 buff 不参与模板比较。

| ID | 名称 | 阵营 | 类型/职业 | HP | 护盾 | 攻击 | 移动 | 射程 | 属性/能力 |
|---|---|---|---|---:|---:|---:|---:|---:|---|
| player_001 | Vanguard | 玩家 | 近战/Soldier | 18 | 6 | 6 | 4 | 1 | None |
| player_002 | Archer | 玩家 | 远程/Archer | 14 | 3 | 4 | 4 | 2 | None |
| player_003 | Ranger | 玩家 | 远程/Archer | 16 | 4 | 5 | 5 | 2 | None |
| player_004 | Verdant Guard | 玩家 | 近战/Soldier | 18 | 4 | 5 | 4 | 1 | Wood/生生不息 |
| player_005 | Earth Warden | 玩家 | 近战/Soldier | 20 | 6 | 5 | 4 | 1 | Earth/万物之源 |
| enemy_001/002/004 | Raider | 敌方 | 近战/Raider | 10 | 3 | 4 | 3 | 1 | None |
| enemy_003 | Marksman | 敌方 | 远程/Archer | 12 | 2 | 3 | 3 | 2 | None |
| enemy_005 | Sentry | 敌方 | 远程/Archer | 14 | 4 | 4 | 2 | 3 | None |
| enemy_006 | Flamecaster | 敌方 | 远程/Archer | 14 | 3 | 4 | 3 | 2 | Fire/火烧联营 |

## Encyclopedia

- 从进行中战斗的 `Menu > Encyclopedia` 打开。
- Allies 与 Enemies 分页显示所有已定义模板，并按名称去重；三个 Raider ID 只形成一张 Raider 卡片。
- `Unit Encyclopedia`、`Back`、Allies/Enemies 和单位英文名称保持英文。
- 每张卡片头像按名称显示英文缩写，例如 Archer=`A`、Verdant Guard=`VG`；独立后缀 `man/woman` 不生成字母。
- 单位类型、职业、生命、护盾、攻击、移动、射程、真实伤害、特殊属性、能力和能力说明使用中文。
- 没有特殊属性或能力时显示“无”；内容区域可滚动。
- `Back` 返回原战斗，不改变单位选择、回合、关卡或单位数值。

## 关卡

| 关卡 | 地图 | 玩家/敌人 | 主要内容 |
|---|---|---:|---|
| Stage 01 First Contact | 10x10 | 2/3 | 基础战斗；Plain、Forest、Mountain |
| Stage 02 Flooded Pass | 12x12 | 3/5 | Swamp、Water、Mountain 与有限边界 |
| Stage 03 Elemental Crossing | 12x12 | 3/5 | Forest、Hill、Water、Mountain，6 River 和 6 Cliff |

第三关玩家为 Verdant Guard、Earth Warden、Ranger；敌方为 Raider x2、Marksman、Sentry、Flamecaster。三关均可直接选择，不设解锁、存档、评分或成长系统。
