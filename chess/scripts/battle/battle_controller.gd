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


func _ready() -> void:
	start_new_battle()


func start_new_battle() -> bool:
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

	var data := GameDataLoader.load_game_data()
	var errors := GameDataValidator.validate(data)
	if not errors.is_empty():
		for error in errors:
			push_error("[BattleController.start_new_battle] %s" % error)
		_set_message("Data validation failed")
		state_changed.emit()
		return false

	grid = BattleGrid.new()
	grid.setup(data.map, data.terrain, data.edges)
	registry = BattleUnitRegistry.new()
	var spawns: Dictionary = data.chapter.player_spawns.duplicate()
	spawns.merge(data.chapter.enemy_spawns)
	for definition in data.players.units + data.enemies.units:
		var unit_id := str(definition.id)
		var spawn_data: Array = spawns[unit_id]
		var spawn := Vector2i(int(spawn_data[0]), int(spawn_data[1]))
		if not grid.is_passable(spawn):
			push_error("[BattleController.start_new_battle] impassable spawn: %s" % unit_id)
			return false
		if not registry.add_unit(BattleUnit.from_data(definition, spawn)):
			return false
	registry.reset_team("player")
	initialized = true
	_set_message("Round 1 - Player turn")
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
		_set_message("%s has already acted" % unit.display_name, false)
	else:
		phase = "action" if unit.has_moved else "move"
		movement_data = {} if unit.has_moved else MovementCalculator.calculate(unit, grid, registry)
		_set_message("Selected %s" % unit.display_name, false)
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
		unit.grid_pos = pos
		unit.has_moved = true
		last_action = {"type": "move", "unit_id": unit.id, "from": origin, "to": pos, "path": path}
		phase = "action"
		movement_data = {}
		_set_message("%s moved from %s to %s" % [unit.display_name, _pos_text(origin), _pos_text(pos)])
		state_changed.emit()
		return true
	return false


func request_attack() -> bool:
	var unit := selected_unit()
	if not _can_player_input() or unit == null or unit.has_acted:
		return false
	phase = "attack"
	attack_cells = AttackRangeCalculator.range_cells(unit, grid)
	_set_message("Choose a target for %s" % unit.display_name, false)
	state_changed.emit()
	return true


func attack_selected(target_id: String) -> bool:
	var attacker := selected_unit()
	var target := registry.get_unit(target_id)
	if not _can_player_input() or attacker == null or target == null:
		return false
	if not AttackRangeCalculator.can_attack(attacker, target, grid):
		_set_message("Target is out of range", false)
		state_changed.emit()
		return false
	var combat := DamageCalculator.apply(attacker, target)
	last_action = {
		"type": "attack",
		"attacker_id": attacker.id,
		"target_id": target.id,
		"from": attacker.grid_pos,
		"to": target.grid_pos,
		"target_dead": target.is_dead
	}
	attacker.has_acted = true
	attacker.has_moved = true
	_set_message(_combat_text(attacker, target, combat))
	_finish_player_action()
	return true


func wait_selected() -> bool:
	var unit := selected_unit()
	if not _can_player_input() or unit == null or unit.has_acted:
		return false
	unit.has_moved = true
	unit.has_acted = true
	_set_message("%s waits" % unit.display_name)
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
	if unit.has_moved:
		phase = "action"
		movement_data = {}
	else:
		phase = "move"
		movement_data = MovementCalculator.calculate(unit, grid, registry)
	_set_message("Attack cancelled", false)
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
	registry.reset_team("enemy")
	_set_message("Round %d - Enemy turn" % round_number)
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
		var events := EnemyAI.take_turn(enemy, grid, registry)
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
					"path": event.get("path", [event.from, event.to])
				}
				_set_message("%s moved to %s" % [enemy.display_name, _pos_text(event.to)])
			elif event.type == "wait":
				_set_message("%s waits" % enemy.display_name)
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
	_set_message("Round %d - Player turn" % round_number)
	state_changed.emit()


func _check_result() -> void:
	result = VictoryChecker.check(registry)
	if result == "victory":
		phase = "finished"
		_set_message("Victory")
	elif result == "defeat":
		phase = "finished"
		_set_message("Defeat")


func _can_player_input() -> bool:
	return initialized and result.is_empty() and current_team == "player"


func _set_message(message: String, record_log: bool = true) -> void:
	last_message = message
	if record_log:
		battle_log.append(message)
		while battle_log.size() > MAX_BATTLE_LOG:
			battle_log.pop_front()
	battle_message.emit(message)


static func _combat_text(attacker: BattleUnit, target: BattleUnit, combat: Dictionary) -> String:
	if combat.get("is_true_damage", false):
		return "%s hit %s: HP %d -> %d" % [attacker.display_name, target.display_name, combat.hp_before, combat.hp_after]
	if int(combat.shield_before) > 0:
		return "%s hit %s: Shield %d -> %d" % [attacker.display_name, target.display_name, combat.shield_before, combat.shield_after]
	return "%s hit %s: HP %d -> %d" % [attacker.display_name, target.display_name, combat.hp_before, combat.hp_after]


static func _pos_text(pos: Vector2i) -> String:
	return "(%d, %d)" % [pos.x, pos.y]
