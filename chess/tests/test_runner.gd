extends SceneTree

var passed := 0
var failed := 0
var grid: BattleGrid


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var data := GameDataLoader.load_game_data()
	var errors := GameDataValidator.validate(data)
	_expect("T000 data validation", errors.is_empty(), "; ".join(errors))
	grid = BattleGrid.new()
	grid.setup(data.map, data.terrain, data.edges)

	_test_controller_start_and_select()
	_test_movement_rules()
	_test_attack_range_rules()
	_test_damage_rules()
	_test_ai_and_victory()
	_test_turn_integration()
	_test_result_integration()
	_test_battle_log()
	_test_restart_feedback_state()
	_test_cancel_action_state()
	_test_path_preview_data()
	_test_last_action_data()
	_test_enemy_input_lock()
	await _test_enemy_generation_guard()

	print("\nTEST SUMMARY: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _test_controller_start_and_select() -> void:
	var controller := BattleController.new()
	controller.start_new_battle()
	_expect("T001 battle starts", controller.initialized and controller.registry.living("player").size() == 2 and controller.registry.living("enemy").size() == 3)
	_expect("T001 player selection", controller.select_at(Vector2i(1, 8)) and controller.selected_unit_id == "player_001")
	_expect("T001 movement range shown", not controller.movement_data.get("reachable", []).is_empty())
	controller.free()


func _test_movement_rules() -> void:
	_expect("T002 plain movement costs 1", grid.get_step_cost(Vector2i(0, 0), Vector2i(1, 0)) == 1)
	_expect("T003 uphill forest costs 3", grid.get_step_cost(Vector2i(2, 1), Vector2i(3, 1)) == 3)
	_expect("T003 downhill plain costs 1", grid.get_step_cost(Vector2i(3, 1), Vector2i(2, 1)) == 1)
	_expect("T004 river adds 1", int(grid.get_edge(Vector2i(3, 6), Vector2i(3, 7)).extra_move_cost) == 1)
	_expect("T005 cliff blocks movement", grid.get_step_cost(Vector2i(5, 3), Vector2i(5, 4)) == -1)
	_expect("T006 mountain is impassable", not grid.is_passable(Vector2i(6, 2)))

	var registry := BattleUnitRegistry.new()
	var mover := _unit("mover", "player", "melee", Vector2i(0, 0), 10, 0, 2, 2, 1)
	var friend := _unit("friend", "player", "melee", Vector2i(1, 0), 10, 0, 2, 2, 1)
	registry.add_unit(mover)
	registry.add_unit(friend)
	var movement := MovementCalculator.calculate(mover, grid, registry)
	_expect("T006 friendly unit can be crossed", Vector2i(2, 0) in movement.reachable)
	_expect("T006 occupied tile cannot be destination", Vector2i(1, 0) not in movement.reachable)


func _test_attack_range_rules() -> void:
	var melee := _unit("melee", "player", "melee", Vector2i(0, 0), 10, 0, 3, 3, 1)
	var near_enemy := _unit("near", "enemy", "melee", Vector2i(1, 0), 10, 0, 1, 1, 1)
	var far_enemy := _unit("far", "enemy", "melee", Vector2i(2, 0), 10, 0, 1, 1, 1)
	_expect("T007 melee attacks distance 1", AttackRangeCalculator.can_attack(melee, near_enemy, grid))
	_expect("T007 melee cannot attack distance 2", not AttackRangeCalculator.can_attack(melee, far_enemy, grid))

	melee.grid_pos = Vector2i(5, 3)
	near_enemy.grid_pos = Vector2i(5, 4)
	_expect("T008 cliff blocks melee", not AttackRangeCalculator.can_attack(melee, near_enemy, grid))

	var archer := _unit("archer", "player", "ranged", Vector2i(3, 1), 10, 0, 3, 3, 2)
	far_enemy.grid_pos = Vector2i(0, 1)
	_expect("T009 ranged high-to-low gains range", AttackRangeCalculator.effective_range(archer, far_enemy.grid_pos, grid) == 3 and AttackRangeCalculator.can_attack(archer, far_enemy, grid))
	archer.grid_pos = Vector2i(2, 1)
	far_enemy.grid_pos = Vector2i(3, 1)
	_expect("T010 ranged low-to-high loses range", AttackRangeCalculator.effective_range(archer, far_enemy.grid_pos, grid) == 1)
	archer.grid_pos = Vector2i(5, 3)
	far_enemy.grid_pos = Vector2i(5, 4)
	_expect("T010 ranged crosses cliff", AttackRangeCalculator.can_attack(archer, far_enemy, grid))


func _test_damage_rules() -> void:
	var attacker := _unit("attacker", "player", "melee", Vector2i.ZERO, 10, 0, 6, 3, 1)
	var target := _unit("target", "enemy", "melee", Vector2i.RIGHT, 10, 8, 1, 3, 1)
	var result := DamageCalculator.apply(attacker, target)
	_expect("T011 shield takes damage first", target.current_shield == 2 and target.current_hp == 10 and not result.shield_broken)
	target.current_shield = 3
	target.current_hp = 10
	result = DamageCalculator.apply(attacker, target)
	_expect("T012 shield break has no overflow", target.current_shield == 0 and target.current_hp == 10 and result.shield_broken)
	result = DamageCalculator.apply(attacker, target)
	_expect("T013 no shield means HP damage", target.current_hp == 4)
	result = DamageCalculator.apply(attacker, target)
	_expect("T014 HP zero kills unit", target.current_hp == 0 and target.is_dead and result.target_dead)

	var true_attacker := _unit("true", "player", "ranged", Vector2i.ZERO, 10, 0, 4, 3, 2)
	true_attacker.true_damage = true
	var shielded := _unit("shielded", "enemy", "melee", Vector2i.RIGHT, 10, 7, 1, 3, 1)
	DamageCalculator.apply(true_attacker, shielded)
	_expect("T014 true damage bypasses shield", shielded.current_hp == 6 and shielded.current_shield == 7)


func _test_ai_and_victory() -> void:
	var registry := BattleUnitRegistry.new()
	var enemy := _unit("enemy", "enemy", "melee", Vector2i(5, 5), 10, 0, 3, 3, 1)
	var player := _unit("player", "player", "melee", Vector2i(5, 9), 10, 0, 2, 3, 1)
	registry.add_unit(enemy)
	registry.add_unit(player)
	var before := BattleGrid.manhattan(enemy.grid_pos, player.grid_pos)
	var events := EnemyAI.take_turn(enemy, grid, registry)
	var after := BattleGrid.manhattan(enemy.grid_pos, player.grid_pos)
	_expect("T015 enemy AI acts", enemy.has_acted and not events.is_empty())
	_expect("T015 enemy AI approaches target", after < before)

	registry.units["enemy"].is_dead = true
	_expect("T016 all enemies defeated is victory", VictoryChecker.check(registry) == "victory")
	registry.units["enemy"].is_dead = false
	registry.units["player"].is_dead = true
	_expect("T017 all players defeated is defeat", VictoryChecker.check(registry) == "defeat")


func _test_turn_integration() -> void:
	var controller := BattleController.new()
	controller.start_new_battle()
	controller.enemy_action_delay = 0.0
	controller.select_at(Vector2i(1, 8))
	controller.wait_selected()
	controller.select_at(Vector2i(2, 8))
	controller.wait_selected()
	_expect("T018 full turn returns control to player", controller.round_number == 2 and controller.current_team == "player")
	_expect("T018 player action flags reset", not controller.registry.get_unit("player_001").has_acted and not controller.registry.get_unit("player_002").has_acted)
	_expect("T027 zero-delay turn finishes synchronously", not controller.enemy_turn_running)
	controller.free()


func _test_result_integration() -> void:
	var victory_controller := BattleController.new()
	victory_controller.start_new_battle()
	victory_controller.registry.get_unit("enemy_002").is_dead = true
	victory_controller.registry.get_unit("enemy_003").is_dead = true
	var last_enemy := victory_controller.registry.get_unit("enemy_001")
	last_enemy.grid_pos = Vector2i(1, 7)
	last_enemy.current_shield = 0
	last_enemy.current_hp = 6
	victory_controller.select_at(Vector2i(1, 8))
	victory_controller.request_attack()
	victory_controller.attack_selected("enemy_001")
	_expect("T019 last enemy kill completes victory", victory_controller.result == "victory" and victory_controller.phase == "finished")
	victory_controller.free()

	var defeat_controller := BattleController.new()
	defeat_controller.start_new_battle()
	defeat_controller.registry.get_unit("player_002").is_dead = true
	var last_player := defeat_controller.registry.get_unit("player_001")
	last_player.current_shield = 0
	last_player.current_hp = 3
	defeat_controller.registry.get_unit("enemy_001").grid_pos = Vector2i(1, 7)
	defeat_controller.end_player_turn()
	_expect("T019 enemy final blow completes defeat", defeat_controller.result == "defeat" and defeat_controller.phase == "finished")
	defeat_controller.free()


func _test_battle_log() -> void:
	var controller := BattleController.new()
	controller.start_new_battle()
	for index in range(10):
		controller._set_message("message_%d" % index)
	_expect("T020 battle log keeps eight entries", controller.battle_log.size() == 8)
	_expect("T020 battle log keeps newest order", controller.battle_log.front() == "message_2" and controller.battle_log.back() == "message_9")
	controller.free()


func _test_restart_feedback_state() -> void:
	var controller := BattleController.new()
	controller.start_new_battle()
	controller.last_action = {"type": "move"}
	controller._set_message("old message")
	var generation := controller.battle_generation
	controller.start_new_battle()
	_expect("T021 restart resets feedback state", controller.last_action.is_empty() and controller.battle_log == ["Round 1 - Player turn"])
	_expect("T021 restart advances generation", controller.battle_generation == generation + 1)
	controller.free()


func _test_cancel_action_state() -> void:
	var controller := BattleController.new()
	controller.start_new_battle()
	controller.select_at(Vector2i(1, 8))
	controller.request_attack()
	controller.cancel_current_action()
	_expect("T022 cancel attack keeps unmoved selection", controller.selected_unit_id == "player_001" and controller.phase == "move" and not controller.movement_data.is_empty())
	controller.click_at(Vector2i(1, 7))
	controller.request_attack()
	controller.cancel_current_action()
	_expect("T022 cancel attack after move returns action", controller.selected_unit_id == "player_001" and controller.phase == "action" and controller.movement_data.is_empty())
	controller.free()


func _test_path_preview_data() -> void:
	var controller := BattleController.new()
	controller.start_new_battle()
	controller.select_at(Vector2i(1, 8))
	var target := Vector2i(1, 6)
	var path := controller.get_selected_path(target)
	_expect("T023 preview path has correct endpoints", path.size() == 3 and path.front() == Vector2i(1, 8) and path.back() == target)
	_expect("T023 preview path cost matches movement", int(controller.movement_data.costs[target]) == 2)
	controller.free()


func _test_last_action_data() -> void:
	var move_controller := BattleController.new()
	move_controller.start_new_battle()
	move_controller.select_at(Vector2i(1, 8))
	move_controller.click_at(Vector2i(1, 7))
	_expect("T024 player move records full path", move_controller.last_action.type == "move" and move_controller.last_action.path == [Vector2i(1, 8), Vector2i(1, 7)])
	move_controller.free()

	var attack_controller := BattleController.new()
	attack_controller.start_new_battle()
	attack_controller.registry.get_unit("enemy_001").grid_pos = Vector2i(1, 7)
	attack_controller.select_at(Vector2i(1, 8))
	attack_controller.request_attack()
	attack_controller.attack_selected("enemy_001")
	_expect("T025 player attack records both endpoints", attack_controller.last_action.type == "attack" and attack_controller.last_action.from == Vector2i(1, 8) and attack_controller.last_action.to == Vector2i(1, 7))
	attack_controller.free()


func _test_enemy_input_lock() -> void:
	var controller := BattleController.new()
	controller.start_new_battle()
	controller.current_team = "enemy"
	controller.enemy_turn_running = true
	_expect("T026 enemy turn blocks player selection", not controller.select_at(Vector2i(1, 8)))
	_expect("T026 enemy turn blocks end-turn command", not controller.end_player_turn())
	controller.free()


func _test_enemy_generation_guard() -> void:
	var controller := BattleController.new()
	root.add_child(controller)
	controller.enemy_action_delay = 0.03
	controller.end_player_turn()
	var old_generation := controller.battle_generation
	controller.start_new_battle()
	await create_timer(0.12).timeout
	_expect("T027 old enemy task cannot advance new battle", controller.battle_generation == old_generation + 1 and controller.round_number == 1 and controller.current_team == "player")
	_expect("T027 restart restores original enemy position", controller.registry.get_unit("enemy_001").grid_pos == Vector2i(7, 1))
	controller.free()


func _unit(unit_id: String, team: String, unit_type: String, pos: Vector2i, hp: int, shield: int, attack: int, move: int, attack_range: int) -> BattleUnit:
	return BattleUnit.from_data({
		"id": unit_id,
		"name": unit_id,
		"team": team,
		"unit_type": unit_type,
		"class_id": "test",
		"max_hp": hp,
		"shield": shield,
		"attack": attack,
		"move_range": move,
		"attack_range": attack_range,
		"true_damage": false,
		"sprite": ""
	}, pos)


func _expect(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s%s" % [label, " - " + detail if not detail.is_empty() else ""])
