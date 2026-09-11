class_name BattleController
extends Node

signal state_changed
signal battle_message(message: String)

const MAX_BATTLE_LOG := 8

var grid: BattleGrid
var registry: BattleUnitRegistry
var selected_unit_id := ""
var phase := "select"
var current_team := "player"
var round_number := 1
var result := ""
var movement_data: Dictionary = {}
var attack_cells: Array[Vector2i] = []
var last_message := ""
var initialized := false
var battle_log: Array[String] = []
var last_action: Dictionary = {}
var enemy_action_delay := 0.35
var battle_generation := 0
var enemy_turn_running := false
var current_chapter_id := ""
var current_chapter_name := ""
var menu_open := false
var ability_defs: Dictionary = {}
var opportunity_state: BattleOpportunityState


func _ready() -> void:
	pass


func start_new_battle(chapter_id: String = "stage_001", stat_overrides: Variant = null) -> bool:
	battle_generation += 1
	initialized = false
	selected_unit_id = ""
	phase = "select"
	current_team = "player"
	round_number = 1
	result = ""
	movement_data = {}
	attack_cells.clear()
	battle_log.clear()
	last_action = {}
	enemy_turn_running = false
	menu_open = false
	ability_defs = {}
	opportunity_state = null
	current_chapter_id = chapter_id

	var data := GameDataLoader.load_game_data(chapter_id, stat_overrides)
	var errors := GameDataValidator.validate(data)
	if not errors.is_empty():
		for error in errors:
			push_error("[BattleController.start_new_battle] %s" % error)
		_set_message("数据校验失败")
		state_changed.emit()
		return false

	grid = BattleGrid.new()
	grid.setup(data.map, data.terrain, data.edges)
	opportunity_state = BattleOpportunityState.new()
	opportunity_state.setup(data.opportunities, data.map)
	for ability in data.abilities.get("abilities", []):
		ability_defs[str(ability.id)] = ability
	current_chapter_name = str(data.chapter.name)
	registry = BattleUnitRegistry.new()
	var definitions := {}
	for definition in data.players.units + data.enemies.units:
		var enriched_definition: Dictionary = definition.duplicate(true)
		var ability_id := str(enriched_definition.get("ability_id", ""))
		if ability_defs.has(ability_id):
			enriched_definition["ability_name"] = str(ability_defs[ability_id].name)
			enriched_definition["ability_description"] = str(ability_defs[ability_id].description)
		definitions[str(enriched_definition.id)] = enriched_definition
	for spawn_group in [data.chapter.player_spawns, data.chapter.enemy_spawns]:
		for unit_id in spawn_group:
			var spawn_data: Array = spawn_group[unit_id]
			var spawn := Vector2i(int(spawn_data[0]), int(spawn_data[1]))
			if not definitions.has(str(unit_id)) or not grid.is_passable(spawn):
				push_error("[BattleController.start_new_battle] invalid spawn: %s" % unit_id)
				return false
			if not registry.add_unit(BattleUnit.from_data(definitions[str(unit_id)], spawn)):
				return false
	registry.reset_team("player")
	initialized = true
	_set_message("第 1 回合 - 玩家回合")
	state_changed.emit()
	return true


func selected_unit() -> BattleUnit:
	if registry == null or selected_unit_id.is_empty():
		return null
	return registry.get_unit(selected_unit_id)


func select_at(pos: Vector2i) -> bool:
	if not _can_player_input() or not grid.in_bounds(pos):
		return false
	var unit := registry.get_at(pos)
	if unit == null or unit.team != "player":
		return false
	selected_unit_id = unit.id
	attack_cells.clear()
	if unit.has_acted:
		phase = "inspect"
		movement_data = {}
		_set_message("%s 已完成本回合行动" % UnitNameLocalizer.localized(unit.display_name), false)
	else:
		phase = "move" if unit.remaining_move_points > 0 else "action"
		movement_data = MovementCalculator.calculate(unit, grid, registry) if unit.remaining_move_points > 0 else {}
		_set_message("已选择 %s" % UnitNameLocalizer.localized(unit.display_name), false)
	state_changed.emit()
	return true


func click_at(pos: Vector2i) -> bool:
	if not _can_player_input() or not grid.in_bounds(pos):
		return false
	var clicked := registry.get_at(pos)
	if clicked != null and clicked.team == "player":
		return select_at(pos)
	var unit := selected_unit()
	if unit == null or unit.has_acted:
		return false
	if phase == "attack" and clicked != null and clicked.team == "enemy":
		return attack_selected(clicked.id)
	if phase == "move" and clicked == null and pos in movement_data.get("reachable", []):
		var origin := unit.grid_pos
		var path := get_selected_path(pos)
		var segment_cost := int(movement_data.get("costs", {}).get(pos, 0))
		unit.grid_pos = pos
		unit.has_moved = true
		unit.remaining_move_points = maxi(unit.remaining_move_points - segment_cost, 0)
		unit.move_spent_this_turn += segment_cost
		var opportunity_events := opportunity_state.apply_path(unit, path)
		var ability_event := SpecialAbilityResolver.apply_terrain_entry(unit, grid.get_terrain_id(pos))
		last_action = {"type": "move", "unit_id": unit.id, "from": origin, "to": pos, "path": path, "cost": segment_cost, "remaining": unit.remaining_move_points, "opportunities": opportunity_events, "ability": ability_event}
		phase = "move" if unit.remaining_move_points > 0 else "action"
		movement_data = MovementCalculator.calculate(unit, grid, registry) if unit.remaining_move_points > 0 else {}
		var move_message := "%s 移动 %s -> %s，消耗 %d，剩余 %d" % [UnitNameLocalizer.localized(unit.display_name), _pos_text(origin), _pos_text(pos), segment_cost, unit.remaining_move_points]
		if not ability_event.is_empty():
			move_message += " | " + _ability_text(ability_event)
		for event in opportunity_events:
			_set_message(_opportunity_text(unit, event))
		_set_message(move_message)
		state_changed.emit()
		return true
	return false


func request_move() -> bool:
	var unit := selected_unit()
	if not _can_player_input() or unit == null or unit.has_acted or unit.remaining_move_points <= 0:
		return false
	phase = "move"
	attack_cells.clear()
	movement_data = MovementCalculator.calculate(unit, grid, registry)
	_set_message("请选择 %s 的目标格" % UnitNameLocalizer.localized(unit.display_name), false)
	state_changed.emit()
	return true


func request_attack() -> bool:
	var unit := selected_unit()
	if not _can_player_input() or unit == null or unit.has_acted:
		return false
	phase = "attack"
	attack_cells = AttackRangeCalculator.range_cells(unit, grid)
	_set_message("请选择 %s 的攻击目标" % UnitNameLocalizer.localized(unit.display_name), false)
	state_changed.emit()
	return true


func attack_selected(target_id: String) -> bool:
	var attacker := selected_unit()
	var target := registry.get_unit(target_id)
	if not _can_player_input() or attacker == null or target == null:
		return false
	if not AttackRangeCalculator.can_attack(attacker, target, grid):
		_set_message("目标不在攻击范围内", false)
		state_changed.emit()
		return false
	var damage_multiplier := SpecialAbilityResolver.attack_multiplier(attacker, target, grid)
	var combat := DamageCalculator.apply(attacker, target, damage_multiplier)
	last_action = {
		"type": "attack",
		"attacker_id": attacker.id,
		"target_id": target.id,
		"from": attacker.grid_pos,
		"to": target.grid_pos,
		"target_dead": target.is_dead,
		"damage_multiplier": damage_multiplier
	}
	attacker.has_acted = true
	attacker.has_moved = true
	attacker.remaining_move_points = 0
	_set_message(_combat_text(attacker, target, combat))
	_finish_player_action()
	return true


func wait_selected() -> bool:
	var unit := selected_unit()
	if not _can_player_input() or unit == null or unit.has_acted:
		return false
	unit.has_moved = true
	unit.has_acted = true
	unit.remaining_move_points = 0
	_set_message("%s 待机" % UnitNameLocalizer.localized(unit.display_name))
	_finish_player_action()
	return true


func cancel_selection() -> void:
	if not _can_player_input():
		return
	selected_unit_id = ""
	phase = "select"
	movement_data = {}
	attack_cells.clear()
	state_changed.emit()


func cancel_current_action() -> void:
	if not _can_player_input():
		return
	if phase != "attack":
		cancel_selection()
		return
	var unit := selected_unit()
	attack_cells.clear()
	if unit == null:
		cancel_selection()
		return
	if unit.remaining_move_points > 0:
		phase = "move"
		movement_data = MovementCalculator.calculate(unit, grid, registry)
	else:
		phase = "action"
		movement_data = {}
	_set_message("已取消攻击", false)
	state_changed.emit()


func end_player_turn() -> bool:
	if not _can_player_input():
		return false
	selected_unit_id = ""
	phase = "enemy"
	movement_data = {}
	attack_cells.clear()
	current_team = "enemy"
	enemy_turn_running = true
	menu_open = false
	for unit in registry.living("player"):
		unit.remaining_move_points = 0
	registry.reset_team("enemy")
	_set_message("第 %d 回合 - 敌方回合" % round_number)
	state_changed.emit()
	_run_enemy_turn(battle_generation)
	return true


func get_selected_path(target: Vector2i) -> Array[Vector2i]:
	var unit := selected_unit()
	if unit == null:
		return []
	return MovementCalculator.build_path(unit.grid_pos, target, movement_data.get("parents", {}))


func _finish_player_action() -> void:
	selected_unit_id = ""
	phase = "select"
	movement_data = {}
	attack_cells.clear()
	_check_result()
	state_changed.emit()
	if result.is_empty() and registry.all_acted("player"):
		end_player_turn()


func _run_enemy_turn(generation: int) -> void:
	for enemy in registry.living("enemy"):
		if generation != battle_generation or not result.is_empty():
			break
		var events := EnemyAI.take_turn(enemy, grid, registry, opportunity_state)
		for event in events:
			if event.type == "attack":
				var target := registry.get_unit(str(event.result.target_id))
				last_action = {
					"type": "attack",
					"attacker_id": enemy.id,
					"target_id": target.id,
					"from": enemy.grid_pos,
					"to": target.grid_pos,
					"target_dead": target.is_dead
				}
				_set_message(_combat_text(enemy, target, event.result))
			elif event.type == "move":
				last_action = {
					"type": "move",
					"unit_id": enemy.id,
					"from": event.from,
					"to": event.to,
					"path": event.get("path", [event.from, event.to]),
					"cost": event.get("cost", 0),
					"remaining": event.get("remaining", 0),
					"opportunities": event.get("opportunities", [])
				}
				_set_message("%s 移动至 %s，消耗 %d" % [UnitNameLocalizer.localized(enemy.display_name), _pos_text(event.to), int(event.get("cost", 0))])
			elif event.type == "opportunity":
				_set_message(_opportunity_text(enemy, event))
			elif event.type == "ability":
				_set_message("%s | %s" % [UnitNameLocalizer.localized(enemy.display_name), _ability_text(event)])
			elif event.type == "wait":
				_set_message("%s 待机" % UnitNameLocalizer.localized(enemy.display_name))
		_check_result()
		state_changed.emit()
		if generation == battle_generation and result.is_empty() and enemy_action_delay > 0.0 and is_inside_tree():
			await get_tree().create_timer(enemy_action_delay).timeout
	if generation != battle_generation:
		return
	if not result.is_empty():
		enemy_turn_running = false
		return
	_check_result()
	if not result.is_empty():
		enemy_turn_running = false
		return
	round_number += 1
	current_team = "player"
	phase = "select"
	enemy_turn_running = false
	registry.reset_team("player")
	_set_message("第 %d 回合 - 玩家回合" % round_number)
	state_changed.emit()


func _check_result() -> void:
	result = VictoryChecker.check(registry)
	if result == "victory":
		phase = "finished"
		_set_message("胜利")
	elif result == "defeat":
		phase = "finished"
		_set_message("失败")


func _can_player_input() -> bool:
	return initialized and result.is_empty() and current_team == "player" and not menu_open


func set_menu_open(value: bool) -> void:
	menu_open = value
	state_changed.emit()


func stop_battle() -> void:
	battle_generation += 1
	initialized = false
	enemy_turn_running = false
	menu_open = false
	current_team = ""
	phase = "level_select"
	selected_unit_id = ""
	movement_data = {}
	attack_cells.clear()
	last_action = {}
	state_changed.emit()


func _set_message(message: String, record_log: bool = true) -> void:
	last_message = message
	if record_log:
		battle_log.append(message)
		while battle_log.size() > MAX_BATTLE_LOG:
			battle_log.pop_front()
	battle_message.emit(message)


static func _combat_text(attacker: BattleUnit, target: BattleUnit, combat: Dictionary) -> String:
	var multiplier_text := " [x%d]" % int(combat.get("damage_multiplier", 1)) if int(combat.get("damage_multiplier", 1)) > 1 else ""
	if combat.get("is_true_damage", false):
		return "%s%s 攻击 %s：HP %d -> %d" % [UnitNameLocalizer.localized(attacker.display_name), multiplier_text, UnitNameLocalizer.localized(target.display_name), combat.hp_before, combat.hp_after]
	if int(combat.shield_before) > 0:
		return "%s%s 攻击 %s：护盾 %d -> %d" % [UnitNameLocalizer.localized(attacker.display_name), multiplier_text, UnitNameLocalizer.localized(target.display_name), combat.shield_before, combat.shield_after]
	return "%s%s 攻击 %s：HP %d -> %d" % [UnitNameLocalizer.localized(attacker.display_name), multiplier_text, UnitNameLocalizer.localized(target.display_name), combat.hp_before, combat.hp_after]


static func _ability_text(event: Dictionary) -> String:
	var ability_name := str(event.get("ability_name", event.get("ability_id", "Ability")))
	return "%s：护盾 %d -> %d" % [ability_name, int(event.get("shield_before", 0)), int(event.get("shield_after", 0))]


static func _opportunity_text(unit: BattleUnit, event: Dictionary) -> String:
	var stat_name := "HP" if str(event.get("effect", "")) == "hp" else "护盾"
	return "%s 触发机遇「%s」：%s %d -> %d" % [UnitNameLocalizer.localized(unit.display_name), str(event.get("opportunity_name", "")), stat_name, int(event.get("value_before", 0)), int(event.get("value_after", 0))]


static func _pos_text(pos: Vector2i) -> String:
	return "(%d, %d)" % [pos.x, pos.y]
