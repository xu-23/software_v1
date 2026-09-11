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
	var catalog_errors := GameDataValidator.validate_catalog(GameDataLoader.load_chapter_catalog())
	_expect("T000 chapter catalog validation", catalog_errors.is_empty(), "; ".join(catalog_errors))
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
	_test_chapter_system()
	_test_remaining_movement()
	_test_swamp_rules()
	_test_ranged_ai_high_ground()
	_test_unit_icon_formatter()
	_test_unit_name_localization()
	_test_v015_unit_roster_and_balance()
	_test_unit_stat_overrides()
	_test_stage_four_generation()
	_test_six_stage_deployments()
	_test_opportunity_state_and_validation()
	_test_enemy_opportunity_integration()
	_test_ai_obstacle_routing()
	_test_stage_three_sentry_route()
	_test_menu_and_stop()
	_test_name_template_rules()
	_test_elemental_abilities()
	_test_stage_three()
	_test_encyclopedia_catalog()
	await _test_encyclopedia_ui()
	await _test_battle_ui_localization()
	await _test_enemy_generation_guard()

	print("\nTEST SUMMARY: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _test_controller_start_and_select() -> void:
	var controller := BattleController.new()
	controller.start_new_battle()
	_expect("T001 battle starts", controller.initialized and controller.registry.living("player").size() == 3 and controller.registry.living("enemy").size() == 6)
	_expect("T001 player selection", controller.select_at(Vector2i(1, 8)) and controller.selected_unit_id == "player_001")
	_expect("T001 movement range shown", not controller.movement_data.get("reachable", []).is_empty())
	controller.free()


func _test_movement_rules() -> void:
	_expect("T002 plain movement costs 1", grid.get_step_cost(Vector2i(0, 0), Vector2i(1, 0)) == 1)
	_expect("T003 forest costs 2 regardless of height", grid.get_step_cost(Vector2i(2, 1), Vector2i(3, 1)) == 2)
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

	var height_data := GameDataLoader.load_game_data("stage_003")
	var height_grid := BattleGrid.new()
	height_grid.setup(height_data.map, height_data.terrain, height_data.edges)
	var archer := _unit("archer", "player", "ranged", Vector2i(6, 0), 10, 0, 3, 3, 2)
	far_enemy.grid_pos = Vector2i(4, 0)
	_expect("T009 ranged high-to-low uses base range", AttackRangeCalculator.effective_range(archer, far_enemy.grid_pos, height_grid) == 2 and AttackRangeCalculator.can_attack(archer, far_enemy, height_grid))
	far_enemy.grid_pos = Vector2i(3, 0)
	_expect("T009 high ground does not extend range", not AttackRangeCalculator.can_attack(archer, far_enemy, height_grid))
	archer.grid_pos = Vector2i(4, 0)
	far_enemy.grid_pos = Vector2i(6, 0)
	_expect("T010 ranged low-to-high is forbidden", not AttackRangeCalculator.can_attack(archer, far_enemy, height_grid))
	far_enemy.grid_pos = Vector2i(5, 0)
	_expect("T010 ranged same-height is allowed", AttackRangeCalculator.can_attack(archer, far_enemy, height_grid))


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
	controller.select_at(Vector2i(4, 8))
	controller.wait_selected()
	_expect("T018 full turn returns control to player", controller.round_number == 2 and controller.current_team == "player")
	_expect("T018 player action flags reset", not controller.registry.get_unit("player_001").has_acted and not controller.registry.get_unit("player_002").has_acted)
	_expect("T027 zero-delay turn finishes synchronously", not controller.enemy_turn_running)
	controller.free()


func _test_result_integration() -> void:
	var victory_controller := BattleController.new()
	victory_controller.start_new_battle()
	for enemy in victory_controller.registry.living("enemy"):
		if enemy.id != "enemy_001":
			enemy.is_dead = true
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
	for player in defeat_controller.registry.living("player"):
		if player.id != "player_001":
			player.is_dead = true
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
	_expect("T021 restart resets feedback state", controller.last_action.is_empty() and controller.battle_log == ["第 1 回合 - 玩家回合"])
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
	_expect("T022 cancel attack after move returns movement", controller.selected_unit_id == "player_001" and controller.phase == "move" and not controller.movement_data.is_empty())
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


func _test_chapter_system() -> void:
	var catalog := GameDataLoader.load_chapter_catalog()
	_expect("T028 catalog contains six levels", catalog.get("chapters", []).size() == 6)
	_expect("T028 catalog IDs are stable", catalog.chapters[0].id == "stage_001" and catalog.chapters[1].id == "stage_002")
	var stage_one := BattleController.new()
	stage_one.start_new_battle("stage_001")
	_expect("T029 stage one uses 3 versus 6", stage_one.registry.living("player").size() == 3 and stage_one.registry.living("enemy").size() == 6)
	_expect("T029 stage one includes a new ally and elite", stage_one.registry.get_unit("player_006") != null and stage_one.registry.get_unit("enemy_005") != null)
	stage_one.free()
	var stage_two := BattleController.new()
	_expect("T030 stage two starts", stage_two.start_new_battle("stage_002"))
	_expect("T030 stage two is 12 by 12", stage_two.grid.width == 12 and stage_two.grid.height == 12)
	_expect("T030 stage two has 3 versus 7", stage_two.registry.living("player").size() == 3 and stage_two.registry.living("enemy").size() == 7)
	_expect("T030 stage two includes Ranger and Sentry", stage_two.registry.get_unit("player_003") != null and stage_two.registry.get_unit("enemy_005") != null)
	_expect("T030 stage two includes swamp and water", stage_two.grid.get_terrain_id(Vector2i(4, 5)) == "swamp" and stage_two.grid.get_terrain_id(Vector2i(7, 5)) == "water")
	stage_two.free()


func _test_remaining_movement() -> void:
	var controller := BattleController.new()
	controller.start_new_battle()
	var unit := controller.registry.get_unit("player_001")
	_expect("T031 movement points initialize", unit.remaining_move_points == 3 and unit.move_spent_this_turn == 0)
	controller.select_at(Vector2i(1, 8))
	_expect("T031 first direct move succeeds", controller.click_at(Vector2i(1, 7)))
	_expect("T031 first segment is deducted", unit.remaining_move_points == 2 and unit.move_spent_this_turn == 1)
	_expect("T031 selection remains in move mode", controller.selected_unit_id == unit.id and controller.phase == "move")
	_expect("T031 second direct move succeeds", controller.click_at(Vector2i(1, 6)))
	_expect("T031 movement accumulates", unit.remaining_move_points == 1 and unit.move_spent_this_turn == 2)
	controller.request_attack()
	_expect("T031 Move command returns from attack mode", controller.request_move() and controller.phase == "move")
	controller.wait_selected()
	_expect("T031 wait discards remaining movement", unit.remaining_move_points == 0 and unit.has_acted)
	unit.reset_turn()
	_expect("T031 turn reset restores movement", unit.remaining_move_points == 3 and unit.move_spent_this_turn == 0 and not unit.has_moved)
	controller.free()


func _test_swamp_rules() -> void:
	var data := GameDataLoader.load_game_data("stage_002")
	var swamp_grid := BattleGrid.new()
	swamp_grid.setup(data.map, data.terrain, data.edges)
	var from := Vector2i(3, 5)
	var swamp := Vector2i(4, 5)
	_expect("T032 swamp rejects one remaining point", swamp_grid.get_step_cost(from, swamp, 1) == -1)
	_expect("T032 swamp consumes exactly two", swamp_grid.get_step_cost(from, swamp, 2) == 2)
	_expect("T032 swamp consumes all five", swamp_grid.get_step_cost(from, swamp, 5) == 5)
	_expect("T032 water remains impassable", not swamp_grid.is_passable(Vector2i(7, 5)))
	var registry := BattleUnitRegistry.new()
	var mover := _unit("swamp_mover", "player", "melee", from, 10, 0, 2, 5, 1)
	registry.add_unit(mover)
	var movement := MovementCalculator.calculate(mover, swamp_grid, registry)
	_expect("T032 swamp is reachable with sufficient budget", swamp in movement.reachable and int(movement.costs[swamp]) == 5)
	mover.remaining_move_points = 1
	movement = MovementCalculator.calculate(mover, swamp_grid, registry)
	_expect("T032 swamp is unreachable with insufficient budget", swamp not in movement.reachable)


func _test_ranged_ai_high_ground() -> void:
	var data := GameDataLoader.load_game_data("stage_003")
	var hill_grid := BattleGrid.new()
	hill_grid.setup(data.map, data.terrain, data.edges)
	var registry := BattleUnitRegistry.new()
	var enemy := _unit("high_seeker", "enemy", "ranged", Vector2i(4, 0), 10, 0, 3, 3, 2)
	var player := _unit("high_target", "player", "melee", Vector2i(6, 0), 10, 0, 2, 3, 1)
	registry.add_unit(enemy)
	registry.add_unit(player)
	var events := EnemyAI.take_turn(enemy, hill_grid, registry)
	_expect("T033 ranged AI chooses nearby high ground", enemy.grid_pos == Vector2i(5, 1))
	_expect("T033 ranged AI attacks from high ground", events.size() == 2 and events[1].type == "attack" and player.current_hp < player.max_hp)
	_expect("T033 ranged action consumes remaining movement", enemy.remaining_move_points == 0 and enemy.has_acted)


func _test_unit_icon_formatter() -> void:
	_expect("T050 one-word icon uses first letter", UnitIconFormatter.initials("Archer") == "A" and UnitIconFormatter.initials("Marksman") == "M")
	_expect("T050 two-word icon uses both initials", UnitIconFormatter.initials("Verdant Guard") == "VG" and UnitIconFormatter.initials("Earth Warden") == "EW")
	_expect("T050 suffix man is omitted", UnitIconFormatter.initials("Forest Man") == "F")
	_expect("T050 suffix woman is omitted", UnitIconFormatter.initials("Forest Woman") == "F")
	_expect("T050 empty unit name has fallback icon", UnitIconFormatter.initials("   ") == "?")
	_expect("T057 soldier icon uses sword badge", UnitIconFormatter.class_badge("soldier") == "sword")
	_expect("T057 raider icon uses horse badge", UnitIconFormatter.class_badge("raider") == "horse")
	_expect("T057 archer icon uses bow badge", UnitIconFormatter.class_badge("archer") == "bow")
	_expect("T057 unknown class has no badge", UnitIconFormatter.class_badge("unknown") == "")


func _test_unit_name_localization() -> void:
	_expect("T066 Vanguard name is localized", UnitNameLocalizer.localized("Vanguard") == "先锋")
	_expect("T066 Archer name is localized", UnitNameLocalizer.localized("Archer") == "弓箭手")
	_expect("T066 Ranger name is localized", UnitNameLocalizer.localized("Ranger") == "游侠")
	_expect("T066 Verdant Guard name is localized", UnitNameLocalizer.localized("Verdant Guard") == "翠绿卫士")
	_expect("T066 Earth Warden name is localized", UnitNameLocalizer.localized("Earth Warden") == "大地守卫")
	_expect("T066 Raider name is localized", UnitNameLocalizer.localized("Raider") == "掠夺者")
	_expect("T066 Marksman name is localized", UnitNameLocalizer.localized("Marksman") == "神射手")
	_expect("T066 Sentry name is localized", UnitNameLocalizer.localized("Sentry") == "哨兵")
	_expect("T066 Flamecaster name is localized", UnitNameLocalizer.localized("Flamecaster") == "火焰术士")
	_expect("T067 Bulwark name is localized", UnitNameLocalizer.localized("Bulwark") == "重盾卫士")
	_expect("T067 Duelist name is localized", UnitNameLocalizer.localized("Duelist") == "决斗者")
	_expect("T067 Longbow name is localized", UnitNameLocalizer.localized("Longbow") == "长弓手")
	_expect("T067 Skirmisher name is localized", UnitNameLocalizer.localized("Skirmisher") == "游击兵")
	_expect("T067 Shield Guard name is localized", UnitNameLocalizer.localized("Shield Guard") == "盾牌卫兵")
	_expect("T067 Hunter name is localized", UnitNameLocalizer.localized("Hunter") == "猎手")
	_expect("T067 Ironclad name is localized", UnitNameLocalizer.localized("Ironclad") == "铁甲统领")
	_expect("T067 Executioner name is localized", UnitNameLocalizer.localized("Executioner") == "行刑官")
	_expect("T067 Siege Archer name is localized", UnitNameLocalizer.localized("Siege Archer") == "攻城弓手")
	_expect("T066 unknown unit name falls back", UnitNameLocalizer.localized("Future Unit") == "Future Unit")
	var raw_data := GameDataLoader.load_json("res://data/units/player_units.json")
	_expect("T066 source names and board initials stay English-based", raw_data.units[0].name == "Vanguard" and UnitIconFormatter.initials(str(raw_data.units[3].name)) == "VG")


func _test_v015_unit_roster_and_balance() -> void:
	var data := GameDataLoader.load_game_data("stage_001")
	var allies := UnitDefinitionCatalog.unique_by_name(data.players.units)
	var enemies := UnitDefinitionCatalog.unique_by_name(data.enemies.units)
	_expect("T068 roster has eight allied designs", allies.size() == 8)
	_expect("T068 roster has ten enemy designs", enemies.size() == 10)
	_expect("T068 three new allied designs exist", _definitions_contain(allies, "Bulwark") and _definitions_contain(allies, "Duelist") and _definitions_contain(allies, "Longbow"))
	_expect("T068 six new enemy designs exist", _definitions_contain(enemies, "Skirmisher") and _definitions_contain(enemies, "Shield Guard") and _definitions_contain(enemies, "Hunter") and _definitions_contain(enemies, "Ironclad") and _definitions_contain(enemies, "Executioner") and _definitions_contain(enemies, "Siege Archer"))
	var ranks_valid := true
	var normal_score := 0.0
	var normal_count := 0
	var elite_score := 0.0
	var elite_count := 0
	for definition in enemies:
		var rank := str(definition.get("rank", ""))
		ranks_valid = ranks_valid and rank in ["normal", "elite"]
		if rank == "normal":
			normal_score += _combat_score(definition)
			normal_count += 1
		else:
			elite_score += _combat_score(definition)
			elite_count += 1
	var allied_score := 0.0
	for definition in allies:
		allied_score += _combat_score(definition)
	var allied_average: float = allied_score / allies.size()
	var normal_ratio: float = normal_score / normal_count / allied_average
	var elite_ratio: float = elite_score / elite_count / allied_average
	_expect("T068 every enemy has a valid rank", ranks_valid and normal_count == 5 and elite_count == 5)
	_expect("T068 normal enemy strength is near two thirds", normal_ratio >= 0.58 and normal_ratio <= 0.75, str(normal_ratio))
	_expect("T068 elite enemy strength is near five thirds", elite_ratio >= 1.55 and elite_ratio <= 1.78, str(elite_ratio))
	var bulwark := _definition_by_name(allies, "Bulwark")
	var duelist := _definition_by_name(allies, "Duelist")
	var longbow := _definition_by_name(allies, "Longbow")
	_expect("T068 new allies have distinct extreme strengths", int(bulwark.shield) == 10 and int(bulwark.attack) == 2 and bool(duelist.true_damage) and int(duelist.shield) == 0 and int(longbow.attack_range) == 4 and int(longbow.move_range) == 2)
	var ironclad := _definition_by_name(enemies, "Ironclad")
	var executioner := _definition_by_name(enemies, "Executioner")
	var siege_archer := _definition_by_name(enemies, "Siege Archer")
	_expect("T068 new elites have tank striker and siege roles", int(ironclad.shield) == 16 and bool(executioner.true_damage) and int(siege_archer.attack_range) == 4)
	var runtime_enemy := BattleUnit.from_data(ironclad, Vector2i.ZERO)
	_expect("T068 enemy rank enters runtime snapshots", runtime_enemy.rank == "elite" and runtime_enemy.snapshot().rank == "elite")


func _test_unit_stat_overrides() -> void:
	var original := GameDataLoader.load_game_data("stage_001")
	var empty_result := UnitStatOverrides.apply_to_data(original, {"units": {}})
	_expect("T058 empty stat overrides preserve definitions", empty_result.players.units == original.players.units and empty_result.enemies.units == original.enemies.units)
	var overrides := {"units": {
		"Vanguard": {"max_hp": 22, "shield": 8, "attack": 7, "move_range": 5},
		"Raider": {"attack": 6}
	}}
	var errors := UnitStatOverrides.validate(overrides, UnitStatOverrides.known_names(original))
	_expect("T058 valid stat overrides pass validation", errors.is_empty(), "; ".join(errors))
	var changed := UnitStatOverrides.apply_to_data(original, overrides)
	var vanguard: Dictionary = changed.players.units[0]
	_expect("T058 all four mutable stats are applied", int(vanguard.max_hp) == 22 and int(vanguard.shield) == 8 and int(vanguard.attack) == 7 and int(vanguard.move_range) == 5)
	_expect("T058 fixed stats stay unchanged", vanguard.name == "Vanguard" and vanguard.team == "player" and vanguard.class_id == "soldier" and int(vanguard.attack_range) == 1)
	_expect("T058 source definitions remain unchanged", int(original.players.units[0].max_hp) == 20 and int(original.players.units[0].attack) == 6)
	var changed_raiders := 0
	for definition in changed.enemies.units:
		if str(definition.name) == "Raider" and int(definition.attack) == 6:
			changed_raiders += 1
	_expect("T058 name override updates every Raider instance", changed_raiders == 3)
	var direct_definitions: Array = original.players.units.duplicate(true)
	var direct_result := UnitStatOverrides.apply_to_definitions(direct_definitions, "Archer", {"max_hp": 17})
	_expect("T058 direct code interface reports changed definitions", direct_result.ok and int(direct_result.changed) == 1 and int(direct_definitions[1].max_hp) == 17)
	_expect("T059 unknown unit override is rejected", _errors_contain(UnitStatOverrides.validate({"units": {"Ghost": {"attack": 1}}}, UnitStatOverrides.known_names(original)), "unknown unit"))
	_expect("T059 fixed field override is rejected", _errors_contain(UnitStatOverrides.validate({"units": {"Vanguard": {"attack_range": 9}}}, UnitStatOverrides.known_names(original)), "cannot change attack_range"))
	_expect("T059 max HP zero is rejected", _errors_contain(UnitStatOverrides.validate({"units": {"Vanguard": {"max_hp": 0}}}, UnitStatOverrides.known_names(original)), "must be >= 1"))
	_expect("T059 negative mutable stat is rejected", _errors_contain(UnitStatOverrides.validate({"units": {"Vanguard": {"shield": -1}}}, UnitStatOverrides.known_names(original)), "must be >= 0"))
	_expect("T059 non-integer mutable stat is rejected", _errors_contain(UnitStatOverrides.validate({"units": {"Vanguard": {"attack": 2.5}}}, UnitStatOverrides.known_names(original)), "must be an integer"))
	_expect("T059 non-object units section is rejected safely", UnitStatOverrides.apply_to_data(original, {"units": []}) == original and _errors_contain(UnitStatOverrides.validate({"units": []}, UnitStatOverrides.known_names(original)), "must contain an object"))
	_expect("T059 non-object supplied root is rejected safely", _errors_contain(GameDataValidator.validate(GameDataLoader.load_game_data("stage_001", [])), "root must be an object"))
	var loaded := GameDataLoader.load_game_data("stage_001", overrides)
	_expect("T060 loader applies supplied stat interface", int(loaded.players.units[0].max_hp) == 22 and int(loaded.enemies.units[0].attack) == 6)
	_expect("T060 overridden game data still validates", GameDataValidator.validate(loaded).is_empty(), "; ".join(GameDataValidator.validate(loaded)))
	var controller := BattleController.new()
	var started := controller.start_new_battle("stage_001", overrides)
	_expect("T060 controller spawns with overridden stats", started and controller.registry.get_unit("player_001").max_hp == 22 and controller.registry.get_unit("player_001").current_hp == 22 and controller.registry.get_unit("enemy_001").attack == 6)
	controller.free()


func _test_stage_four_generation() -> void:
	var catalog := GameDataLoader.load_chapter_catalog()
	_expect("T061 fourth stage is appended to catalog", catalog.chapters[3].id == "stage_004" and catalog.chapters[3].difficulty == "Very Hard")
	var spec := GameDataLoader.load_json("res://data/maps/map_004.json")
	var generated_a := ProceduralMapGenerator.generate(spec)
	var generated_b := ProceduralMapGenerator.generate(spec)
	var generated_c := ProceduralMapGenerator.generate(spec, 104015)
	_expect("T061 fixed seed generation is deterministic", generated_a == generated_b)
	_expect("T061 seed is exposed for replay", int(generated_a.generation_seed) == 104014)
	_expect("T061 another seed changes the map", generated_a.tiles != generated_c.tiles or generated_a.edges != generated_c.edges)
	seed(4312)
	var expected_random := randi()
	seed(4312)
	ProceduralMapGenerator.generate(spec)
	_expect("T061 generator does not change global random state", randi() == expected_random)
	var data := GameDataLoader.load_game_data("stage_004")
	var validation_errors := GameDataValidator.validate(data)
	_expect("T062 stage four data validates", validation_errors.is_empty(), "; ".join(validation_errors))
	_expect("T062 stage four is 12 by 12", int(data.map.width) == 12 and int(data.map.height) == 12 and data.map.tiles.size() == 12)
	_expect("T062 stage four contains all terrain quotas", _terrain_count(data.map, "forest") >= 28 and _terrain_count(data.map, "hill") >= 18 and _terrain_count(data.map, "swamp") >= 12 and _terrain_count(data.map, "water") >= 10 and _terrain_count(data.map, "mountain") >= 8)
	_expect("T062 stage four contains complex boundaries", _edge_count(data.map, "river") >= 10 and _edge_count(data.map, "cliff") >= 10)
	var anchors: Array[Vector2i] = []
	for value in spec.generation.connectivity_anchors:
		anchors.append(Vector2i(int(value[0]), int(value[1])))
	_expect("T062 stage four anchors stay connected", ProceduralMapGenerator.anchors_connected(data.map, anchors))
	var protected_are_plain := true
	for value in spec.generation.protected_tiles:
		if str(data.map.tiles[int(value[1])][int(value[0])]) != "plain":
			protected_are_plain = false
	_expect("T062 protected deployment routes stay Plain", protected_are_plain)
	var controller := BattleController.new()
	var started := controller.start_new_battle("stage_004")
	_expect("T063 stage four starts", started)
	_expect("T063 stage four deploys 3 versus 8", controller.registry.living("player").size() == 3 and controller.registry.living("enemy").size() == 8)
	var first_tiles: Array = data.map.tiles.duplicate(true)
	controller.start_new_battle("stage_004")
	_expect("T063 stage four restart reproduces its map", controller.grid.tiles == first_tiles)
	controller.free()


func _test_six_stage_deployments() -> void:
	var catalog := GameDataLoader.load_chapter_catalog()
	_expect("T069 catalog ends at stage six", catalog.chapters.size() == 6 and catalog.chapters[5].id == "stage_006")
	var expected_sizes := [Vector2i(10, 10), Vector2i(12, 12), Vector2i(12, 12), Vector2i(12, 12), Vector2i(10, 10), Vector2i(14, 12)]
	var allied_names := {}
	var enemy_names := {}
	for index in range(6):
		var stage_id := "stage_%03d" % (index + 1)
		var data := GameDataLoader.load_game_data(stage_id)
		var errors := GameDataValidator.validate(data)
		_expect("T069 %s data validates" % stage_id, errors.is_empty(), "; ".join(errors))
		var controller := BattleController.new()
		var started := controller.start_new_battle(stage_id)
		var players := controller.registry.living("player") if started else []
		var enemies := controller.registry.living("enemy") if started else []
		_expect("T069 %s deploys 3 versus 6-9" % stage_id, started and players.size() == 3 and enemies.size() >= 6 and enemies.size() <= 9)
		var elite_count := 0
		for enemy in enemies:
			if enemy.rank == "elite":
				elite_count += 1
			enemy_names[enemy.display_name] = true
		for player in players:
			allied_names[player.display_name] = true
		_expect("T069 %s contains an elite" % stage_id, elite_count >= 1)
		_expect("T069 %s has planned dimensions" % stage_id, started and Vector2i(controller.grid.width, controller.grid.height) == expected_sizes[index])
		controller.free()
	_expect("T069 six stages cover every allied design", allied_names.size() == 8)
	_expect("T069 six stages cover every enemy design", enemy_names.size() == 10)


func _test_opportunity_state_and_validation() -> void:
	var definitions := GameDataLoader.load_json("res://data/opportunities/opportunity_defs.json")
	_expect("T070 four opportunity types load", definitions.opportunities.size() == 4)
	var map_data := {"opportunities": [
		{"id": "test_supply", "opportunity_id": "plain_supplies", "position": [1, 0]},
		{"id": "test_fruit", "opportunity_id": "forest_fruit", "position": [2, 0]},
		{"id": "test_iron", "opportunity_id": "hill_iron", "position": [3, 0]}
	]}
	var state := BattleOpportunityState.new()
	state.setup(definitions, map_data)
	_expect("T070 opportunity state starts full and hidden by query", state.remaining_count() == 3 and state.has_at(Vector2i(2, 0)))
	var unit := _unit("opportunity_player", "player", "melee", Vector2i.ZERO, 10, 2, 2, 4, 1)
	unit.current_hp = 5
	var events := state.apply_path(unit, [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])
	_expect("T070 path triggers every opportunity in order", events.size() == 3 and events[0].opportunity_id == "plain_supplies" and events[1].opportunity_id == "forest_fruit" and events[2].opportunity_id == "hill_iron")
	_expect("T070 HP opportunities heal with exact values", unit.current_hp == 8 and int(events[0].actual_amount) == 2 and int(events[1].actual_amount) == 1)
	_expect("T070 shield opportunity increases current shield", unit.current_shield == 3 and int(events[2].value_before) == 2 and int(events[2].value_after) == 3)
	_expect("T070 triggered opportunities disappear", state.remaining_count() == 0 and not state.has_at(Vector2i(1, 0)))
	_expect("T070 opportunities cannot trigger twice", state.apply_path(unit, [Vector2i.ZERO, Vector2i(1, 0)]).is_empty())
	var origin_state := BattleOpportunityState.new()
	origin_state.setup(definitions, {"opportunities": [{"id": "origin", "opportunity_id": "plain_supplies", "position": [0, 0]}]})
	_expect("T070 path origin is not consumed", origin_state.apply_path(unit, [Vector2i.ZERO, Vector2i(1, 0)]).is_empty() and origin_state.remaining_count() == 1)
	var full_state := BattleOpportunityState.new()
	full_state.setup(definitions, {"opportunities": [{"id": "full", "opportunity_id": "forest_fruit", "position": [1, 0]}]})
	unit.current_hp = unit.max_hp
	var full_events := full_state.apply_path(unit, [Vector2i.ZERO, Vector2i(1, 0)])
	_expect("T070 full HP still consumes healing opportunity", full_events.size() == 1 and int(full_events[0].actual_amount) == 0 and full_state.remaining_count() == 0)
	var stage_data := GameDataLoader.load_game_data("stage_005")
	var duplicate_data: Dictionary = stage_data.duplicate(true)
	duplicate_data.map.opportunities.append(duplicate_data.map.opportunities[0].duplicate(true))
	var duplicate_errors := GameDataValidator.validate(duplicate_data)
	_expect("T070 duplicate opportunity instance is rejected", _errors_contain(duplicate_errors, "duplicate opportunity instance id") and _errors_contain(duplicate_errors, "duplicate opportunity position"))
	var mismatch_data: Dictionary = stage_data.duplicate(true)
	mismatch_data.map.opportunities[0].position = [0, 0]
	_expect("T070 opportunity terrain mismatch is rejected", _errors_contain(GameDataValidator.validate(mismatch_data), "opportunity terrain mismatch"))
	var unknown_data: Dictionary = stage_data.duplicate(true)
	unknown_data.map.opportunities[0].opportunity_id = "unknown"
	_expect("T070 unknown opportunity is rejected", _errors_contain(GameDataValidator.validate(unknown_data), "unknown opportunity"))
	var amount_data: Dictionary = stage_data.duplicate(true)
	amount_data.opportunities.opportunities[0].amount = 0
	_expect("T070 non-positive opportunity amount is rejected", _errors_contain(GameDataValidator.validate(amount_data), "positive integer"))
	var controller := BattleController.new()
	controller.start_new_battle("stage_003")
	var initial_count := controller.opportunity_state.remaining_count()
	controller.select_at(Vector2i(1, 11))
	var moved := controller.click_at(Vector2i(2, 10))
	_expect("T071 controller records path opportunity", moved and controller.last_action.opportunities.size() == 1 and controller.last_action.opportunities[0].opportunity_name == "水果")
	_expect("T071 opportunity uses Chinese battle log", "机遇「水果」" in "\n".join(controller.battle_log))
	_expect("T071 controller consumes opportunity once", controller.opportunity_state.remaining_count() == initial_count - 1 and not controller.opportunity_state.has_at(Vector2i(2, 10)))
	controller.start_new_battle("stage_003")
	_expect("T071 restart restores opportunities", controller.opportunity_state.remaining_count() == initial_count and controller.opportunity_state.has_at(Vector2i(2, 10)))
	controller.free()


func _test_enemy_opportunity_integration() -> void:
	var terrain_data := GameDataLoader.load_json("res://data/terrain/terrain_defs.json")
	var edge_data := GameDataLoader.load_json("res://data/terrain/edge_defs.json")
	var small_grid := BattleGrid.new()
	small_grid.setup({"width": 4, "height": 1, "tiles": [["plain", "plain", "plain", "plain"]], "edges": []}, terrain_data, edge_data)
	var registry := BattleUnitRegistry.new()
	var enemy := _unit("opportunity_enemy", "enemy", "melee", Vector2i.ZERO, 10, 0, 2, 1, 1)
	enemy.current_hp = 5
	var target := _unit("opportunity_target", "player", "melee", Vector2i(3, 0), 10, 0, 2, 1, 1)
	registry.add_unit(enemy)
	registry.add_unit(target)
	var state := BattleOpportunityState.new()
	state.setup(GameDataLoader.load_json("res://data/opportunities/opportunity_defs.json"), {"opportunities": [{"id": "ai_supply", "opportunity_id": "plain_supplies", "position": [1, 0]}]})
	var events := EnemyAI.take_turn(enemy, small_grid, registry, state)
	var has_event := false
	for event in events:
		if event.type == "opportunity" and event.opportunity_id == "plain_supplies":
			has_event = true
	_expect("T072 enemy movement triggers path opportunity", enemy.grid_pos == Vector2i(1, 0) and has_event and enemy.current_hp == 7)
	_expect("T072 enemy opportunity disappears", state.remaining_count() == 0)


func _test_ai_obstacle_routing() -> void:
	var terrain_data := GameDataLoader.load_json("res://data/terrain/terrain_defs.json")
	var edge_data := GameDataLoader.load_json("res://data/terrain/edge_defs.json")
	var wall_map := {
		"width": 7,
		"height": 6,
		"tiles": [
			["plain", "plain", "plain", "mountain", "hill", "hill", "hill"],
			["plain", "plain", "plain", "mountain", "hill", "hill", "hill"],
			["plain", "plain", "plain", "mountain", "hill", "hill", "hill"],
			["plain", "plain", "plain", "mountain", "hill", "hill", "hill"],
			["plain", "plain", "plain", "plain", "hill", "hill", "hill"],
			["plain", "plain", "plain", "plain", "hill", "hill", "hill"]
		],
		"edges": []
	}
	var wall_grid := BattleGrid.new()
	wall_grid.setup(wall_map, terrain_data, edge_data)
	var registry := BattleUnitRegistry.new()
	var sentry := _unit("wall_sentry", "enemy", "ranged", Vector2i(2, 1), 16, 0, 3, 2, 3)
	var target := _unit("hill_target", "player", "melee", Vector2i(5, 1), 20, 0, 2, 3, 1)
	registry.add_unit(sentry)
	registry.add_unit(target)
	var starting_distance := BattleGrid.manhattan(sentry.grid_pos, target.grid_pos)
	var first_events := EnemyAI.take_turn(sentry, wall_grid, registry)
	_expect("T051 ranged AI begins a real route around wall", sentry.grid_pos == Vector2i(2, 3) and first_events[0].type == "move")
	_expect("T051 AI accepts temporary Manhattan increase", BattleGrid.manhattan(sentry.grid_pos, target.grid_pos) > starting_distance)
	_expect("T051 blocked low ground does not attack through height", target.current_hp == target.max_hp)

	var visited := {sentry.grid_pos: true}
	var repeated_position := false
	var attacked := false
	for turn in range(4):
		sentry.reset_turn()
		var events := EnemyAI.take_turn(sentry, wall_grid, registry)
		for event in events:
			if event.type == "attack":
				attacked = true
		if visited.has(sentry.grid_pos) and not attacked:
			repeated_position = true
		visited[sentry.grid_pos] = true
		if attacked:
			break
	_expect("T052 ranged AI does not oscillate on detour", not repeated_position)
	_expect("T052 ranged AI reaches a legal firing position", attacked and AttackRangeCalculator.can_attack(sentry, target, wall_grid))
	_expect("T052 ranged AI eventually damages target", target.current_hp < target.max_hp)

	var sealed_map: Dictionary = wall_map.duplicate(true)
	sealed_map.tiles[4][3] = "mountain"
	sealed_map.tiles[5][3] = "mountain"
	var sealed_grid := BattleGrid.new()
	sealed_grid.setup(sealed_map, terrain_data, edge_data)
	var sealed_registry := BattleUnitRegistry.new()
	var blocked := _unit("blocked_sentry", "enemy", "ranged", Vector2i(2, 1), 16, 0, 3, 2, 3)
	var sealed_target := _unit("sealed_target", "player", "melee", Vector2i(5, 1), 20, 0, 2, 3, 1)
	sealed_registry.add_unit(blocked)
	sealed_registry.add_unit(sealed_target)
	var blocked_events := EnemyAI.take_turn(blocked, sealed_grid, sealed_registry)
	_expect("T053 no-route AI stays at its best fallback point", blocked.grid_pos == Vector2i(2, 1))
	_expect("T053 no-route AI waits without false attack", blocked_events.size() == 1 and blocked_events[0].type == "wait" and sealed_target.current_hp == sealed_target.max_hp)


func _test_stage_three_sentry_route() -> void:
	var controller := BattleController.new()
	controller.start_new_battle("stage_003")
	var sentry := controller.registry.get_unit("enemy_005")
	var start := sentry.grid_pos
	var isolated_registry := BattleUnitRegistry.new()
	isolated_registry.add_unit(sentry)
	for player in controller.registry.living("player"):
		isolated_registry.add_unit(player)
	var attacked := false
	for turn in range(12):
		sentry.reset_turn()
		for event in EnemyAI.take_turn(sentry, controller.grid, isolated_registry):
			if event.type == "attack":
				attacked = true
		if attacked:
			break
	_expect("T056 stage-three Sentry leaves its starting pocket", sentry.grid_pos != start)
	_expect("T056 stage-three Sentry eventually attacks", attacked)
	controller.free()


func _test_menu_and_stop() -> void:
	var controller := BattleController.new()
	controller.start_new_battle("stage_002")
	controller.set_menu_open(true)
	_expect("T034 open menu blocks board selection", not controller.select_at(Vector2i(1, 10)))
	controller.set_menu_open(false)
	_expect("T034 closing menu restores input", controller.select_at(Vector2i(1, 10)))
	var generation := controller.battle_generation
	controller.start_new_battle(controller.current_chapter_id)
	_expect("T035 restart keeps current level", controller.current_chapter_id == "stage_002" and controller.grid.width == 12)
	_expect("T035 restart advances generation", controller.battle_generation == generation + 1)
	controller.stop_battle()
	_expect("T036 stop returns level-select state", not controller.initialized and controller.phase == "level_select" and controller.battle_generation == generation + 2)
	controller.free()


func _test_name_template_rules() -> void:
	var data := GameDataLoader.load_game_data("stage_003")
	var raider_ids: Array[String] = []
	for definition in data.enemies.units:
		if str(definition.name) == "Raider":
			raider_ids.append(str(definition.id))
	_expect("T037 same-name units may use different instance IDs", raider_ids.size() == 3 and raider_ids[0] != raider_ids[1])
	_expect("T037 canonical Raider definitions validate", GameDataValidator.validate(data).is_empty())

	var stat_conflict: Dictionary = data.duplicate(true)
	stat_conflict.enemies.units[1]["attack"] = int(stat_conflict.enemies.units[1].attack) + 1
	var stat_errors := GameDataValidator.validate(stat_conflict)
	_expect("T038 same-name stat conflict is rejected", _errors_contain(stat_errors, "conflicting field attack"), "; ".join(stat_errors))

	var ability_conflict: Dictionary = data.duplicate(true)
	ability_conflict.enemies.units[1]["special_attribute"] = "fire"
	ability_conflict.enemies.units[1]["ability_id"] = "burning_camp"
	var ability_errors := GameDataValidator.validate(ability_conflict)
	_expect("T038 same-name ability conflict is rejected", _errors_contain(ability_errors, "conflicting field special_attribute") and _errors_contain(ability_errors, "conflicting field ability_id"), "; ".join(ability_errors))
	var future_field_conflict: Dictionary = data.duplicate(true)
	future_field_conflict.enemies.units[1]["future_static_field"] = 1
	var future_field_errors := GameDataValidator.validate(future_field_conflict)
	_expect("T038 future same-name fields are also compared", _errors_contain(future_field_errors, "conflicting field future_static_field"), "; ".join(future_field_errors))


func _test_elemental_abilities() -> void:
	var wood := _unit("wood", "player", "melee", Vector2i.ZERO, 18, 0, 5, 4, 1, "wood", "renewal", "Renewal")
	var wood_event := SpecialAbilityResolver.apply_terrain_entry(wood, "forest")
	_expect("T039 Wood gains Shield from first Forest entry", wood.current_shield == 2 and wood_event.ability_id == "renewal")
	_expect("T039 Wood does not trigger twice in one turn", SpecialAbilityResolver.apply_terrain_entry(wood, "forest").is_empty() and wood.current_shield == 2)
	wood.reset_turn()
	SpecialAbilityResolver.apply_terrain_entry(wood, "forest")
	_expect("T039 Wood trigger resets next turn", wood.current_shield == 4)

	var earth := _unit("earth", "player", "melee", Vector2i.ZERO, 20, 6, 5, 4, 1, "earth", "source_of_all", "Source of All")
	var earth_event := SpecialAbilityResolver.apply_terrain_entry(earth, "hill")
	_expect("T040 Earth doubles current Shield on first Hill entry", earth.current_shield == 12 and earth_event.shield_before == 6 and earth_event.shield_after == 12)
	earth.reset_turn()
	_expect("T040 Earth trigger is once per battle", SpecialAbilityResolver.apply_terrain_entry(earth, "hill").is_empty() and earth.current_shield == 12)
	var exhausted_earth := _unit("earth_zero", "player", "melee", Vector2i.ZERO, 20, 0, 5, 4, 1, "earth", "source_of_all", "Source of All")
	var zero_event := SpecialAbilityResolver.apply_terrain_entry(exhausted_earth, "hill")
	exhausted_earth.current_shield = 3
	_expect("T040 zero-Shield Hill entry consumes Earth trigger", not zero_event.is_empty() and SpecialAbilityResolver.apply_terrain_entry(exhausted_earth, "hill").is_empty() and exhausted_earth.current_shield == 3)

	var stage_data := GameDataLoader.load_game_data("stage_003")
	var stage_grid := BattleGrid.new()
	stage_grid.setup(stage_data.map, stage_data.terrain, stage_data.edges)
	var fire := _unit("fire", "enemy", "ranged", Vector2i(10, 5), 14, 3, 4, 3, 2, "fire", "burning_camp", "Burning Camp")
	var forest_target := _unit("forest_target", "player", "melee", Vector2i(10, 6), 20, 3, 1, 3, 1)
	var plain_target := _unit("plain_target", "player", "melee", Vector2i(11, 5), 20, 0, 1, 3, 1)
	_expect("T041 Fire multiplier detects Forest target", SpecialAbilityResolver.attack_multiplier(fire, forest_target, stage_grid) == 2)
	_expect("T041 Fire multiplier stays normal on Plain", SpecialAbilityResolver.attack_multiplier(fire, plain_target, stage_grid) == 1)
	var doubled := DamageCalculator.apply(fire, forest_target, 2)
	_expect("T041 doubled damage still obeys shield no-overflow", doubled.damage_value == 8 and forest_target.current_shield == 0 and forest_target.current_hp == 20)
	DamageCalculator.apply(fire, forest_target, 2)
	_expect("T041 doubled damage reaches HP after Shield breaks", forest_target.current_hp == 12)

	var wood_controller := BattleController.new()
	wood_controller.start_new_battle("stage_003")
	wood_controller.select_at(Vector2i(1, 11))
	var moved_to_forest := wood_controller.click_at(Vector2i(2, 10))
	var verdant := wood_controller.registry.get_unit("player_004")
	_expect("T042 player movement integrates Wood ability", moved_to_forest and verdant.current_shield == 4 and wood_controller.last_action.ability.ability_id == "renewal")
	_expect("T042 Wood ability is named in battle log", "生生不息" in wood_controller.battle_log.back())
	wood_controller.free()

	var earth_controller := BattleController.new()
	earth_controller.start_new_battle("stage_003")
	earth_controller.select_at(Vector2i(4, 11))
	var moved_to_hill := earth_controller.click_at(Vector2i(4, 9))
	var warden := earth_controller.registry.get_unit("player_005")
	_expect("T043 player movement integrates Earth ability", moved_to_hill and warden.current_shield == 18 and earth_controller.last_action.ability.ability_id == "source_of_all")
	_expect("T043 Earth ability is named in battle log", "万物之源" in earth_controller.battle_log.back())
	earth_controller.free()

	var ai_registry := BattleUnitRegistry.new()
	var ai_fire := _unit("ai_fire", "enemy", "ranged", Vector2i(10, 5), 14, 0, 4, 3, 2, "fire", "burning_camp", "Burning Camp")
	var ai_target := _unit("ai_target", "player", "melee", Vector2i(10, 6), 20, 0, 1, 3, 1)
	ai_registry.add_unit(ai_fire)
	ai_registry.add_unit(ai_target)
	var ai_events := EnemyAI.take_turn(ai_fire, stage_grid, ai_registry)
	_expect("T044 enemy AI applies Fire multiplier", ai_events.size() == 1 and ai_events[0].type == "attack" and int(ai_events[0].result.damage_multiplier) == 2 and ai_target.current_hp == 12)


func _test_stage_three() -> void:
	var data := GameDataLoader.load_game_data("stage_003")
	var errors := GameDataValidator.validate(data)
	_expect("T045 stage three data validates", errors.is_empty(), "; ".join(errors))
	var controller := BattleController.new()
	_expect("T045 stage three starts", controller.start_new_battle("stage_003"))
	_expect("T045 stage three is 12 by 12", controller.grid.width == 12 and controller.grid.height == 12)
	_expect("T045 stage three has 3 versus 7", controller.registry.living("player").size() == 3 and controller.registry.living("enemy").size() == 7)
	_expect("T045 stage three deploys all elemental units", controller.registry.get_unit("player_004") != null and controller.registry.get_unit("player_005") != null and controller.registry.get_unit("enemy_006") != null)
	_expect("T046 stage three expands Forest coverage", _terrain_count(data.map, "forest") > _terrain_count(GameDataLoader.load_game_data("stage_002").map, "forest"))
	_expect("T046 stage three includes River and Cliff edges", _edge_count(data.map, "river") >= 6 and _edge_count(data.map, "cliff") >= 6)
	_expect("T047 Forest is height 0 and costs 2", controller.grid.get_height(Vector2i(2, 10)) == 0 and controller.grid.get_step_cost(Vector2i(2, 11), Vector2i(2, 10), 2) == 2)
	_expect("T047 Forest rejects entry with one point", controller.grid.get_step_cost(Vector2i(2, 11), Vector2i(2, 10), 1) == -1)
	_expect("T047 Hill is height 1 and costs 2", controller.grid.get_height(Vector2i(4, 9)) == 1 and controller.grid.get_step_cost(Vector2i(4, 10), Vector2i(4, 9), 2) == 2)
	_expect("T047 Hill rejects entry with one point", controller.grid.get_step_cost(Vector2i(4, 10), Vector2i(4, 9), 1) == -1)
	controller.free()


func _test_encyclopedia_catalog() -> void:
	var data := GameDataLoader.load_game_data("stage_001")
	var allies := UnitDefinitionCatalog.unique_by_name(data.players.units)
	var enemies := UnitDefinitionCatalog.unique_by_name(data.enemies.units)
	_expect("T048 encyclopedia lists eight allied definitions", allies.size() == 8)
	_expect("T048 encyclopedia deduplicates ten enemy definitions", enemies.size() == 10)
	_expect("T048 encyclopedia includes new elemental units", _definitions_contain(allies, "Verdant Guard") and _definitions_contain(allies, "Earth Warden") and _definitions_contain(enemies, "Flamecaster"))
	_expect("T048 ability catalog contains three entries", data.abilities.abilities.size() == 3)


func _test_encyclopedia_ui() -> void:
	var main_scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	var popup: PopupMenu = main_scene.menu_button.get_popup()
	_expect("T049 Menu exposes Encyclopedia command", popup.get_item_id(3) == 2 and popup.get_item_text(3) == "Encyclopedia")
	main_scene.start_level("stage_003")
	main_scene.controller.select_at(Vector2i(1, 11))
	var generation: int = main_scene.controller.battle_generation
	main_scene.show_encyclopedia()
	_expect("T049 Encyclopedia replaces battle view", main_scene.encyclopedia_view.visible and not main_scene.battle_view.visible)
	_expect("T049 Encyclopedia separates complete team catalogs", int(main_scene.encyclopedia_entry_counts.player) == 8 and int(main_scene.encyclopedia_entry_counts.enemy) == 10)
	var encyclopedia_text := _collect_control_text(main_scene.encyclopedia_view)
	_expect("T054 Encyclopedia navigation remains English", "Unit Encyclopedia" in encyclopedia_text and "Back" in encyclopedia_text and main_scene.encyclopedia_tabs.get_tab_title(0) == "Allies" and main_scene.encyclopedia_tabs.get_tab_title(1) == "Enemies")
	_expect("T054 unit names are Chinese", "翠绿卫士" in encyclopedia_text and "大地守卫" in encyclopedia_text and "火焰术士" in encyclopedia_text)
	_expect("T054 English unit names are absent from cards", "Verdant Guard" not in encyclopedia_text and "Earth Warden" not in encyclopedia_text and "Flamecaster" not in encyclopedia_text)
	_expect("T054 unit information is Chinese", "近战" in encyclopedia_text and "生命" in encyclopedia_text and "护盾" in encyclopedia_text and "特殊属性" in encyclopedia_text and "能力" in encyclopedia_text)
	_expect("T073 enemy ranks are Chinese in Encyclopedia", "级别 普通" in encyclopedia_text and "级别 精英" in encyclopedia_text)
	_expect("T054 old English unit labels are absent", "Special Attribute" not in encyclopedia_text and "True Damage" not in encyclopedia_text)
	_expect("T055 Encyclopedia uses name initials", _has_label_text(main_scene.encyclopedia_view, "VG") and _has_label_text(main_scene.encyclopedia_view, "EW") and _has_label_text(main_scene.encyclopedia_view, "F"))
	_expect("T055 ability descriptions are Chinese", "每回合第一次移动" in encyclopedia_text and "攻击位于森林" in encyclopedia_text and "每局第一次移动" in encyclopedia_text)
	main_scene.close_encyclopedia()
	_expect("T049 Back restores active battle", main_scene.battle_view.visible and not main_scene.encyclopedia_view.visible)
	_expect("T049 Encyclopedia round trip preserves battle state", main_scene.controller.battle_generation == generation and main_scene.controller.selected_unit_id == "player_004")
	main_scene.free()


func _test_battle_ui_localization() -> void:
	var main_scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.start_level("stage_001")
	_expect("T064 initial battle status is Chinese", main_scene.status_label.text == "第 1 回合 - 玩家回合" and main_scene.battle_log_label.text == "第 1 回合 - 玩家回合")
	main_scene._show_hovered_cell(Vector2i(0, 0))
	_expect("T064 terrain panel is Chinese", "地形" in main_scene.unit_stats_label.text and "平地" in main_scene.unit_stats_label.text and "移动消耗" in main_scene.unit_stats_label.text and "可通行" in main_scene.unit_stats_label.text)
	_expect("T064 terrain footer is Chinese", "平地" in main_scene.terrain_label.text and "高度" in main_scene.terrain_label.text and "Height" not in main_scene.terrain_label.text)
	main_scene._show_hovered_cell(Vector2i(1, 8))
	_expect("T064 hovered unit panel is Chinese", "阵营  玩家" in main_scene.unit_stats_label.text and "类型  近战" in main_scene.unit_stats_label.text and "护盾" in main_scene.unit_stats_label.text and "攻击" in main_scene.unit_stats_label.text and "坐标" in main_scene.unit_stats_label.text)
	main_scene._show_hovered_cell(Vector2i(8, 2))
	_expect("T073 enemy rank is Chinese in battle details", "级别  精英" in main_scene.unit_stats_label.text)
	main_scene.controller.select_at(Vector2i(1, 8))
	main_scene.controller.click_at(Vector2i(1, 7))
	_expect("T065 movement log is Chinese", "先锋 移动" in main_scene.controller.battle_log.back() and "消耗" in main_scene.controller.battle_log.back() and "剩余" in main_scene.controller.battle_log.back())
	main_scene.controller.registry.get_unit("enemy_001").grid_pos = Vector2i(1, 6)
	main_scene.controller.request_attack()
	main_scene.controller.attack_selected("enemy_001")
	_expect("T065 combat log is Chinese", "先锋 攻击 掠夺者" in main_scene.controller.battle_log.back() and "护盾" in main_scene.controller.battle_log.back())
	_expect("T065 battle log uses localized unit names", "Vanguard" not in main_scene.controller.battle_log.back() and "Raider" not in main_scene.controller.battle_log.back())
	main_scene._show_unit_or_summary(null)
	_expect("T064 empty unit summary is Chinese", main_scene.unit_name_label.text == "未选择单位" and "玩家存活" in main_scene.unit_stats_label.text and "敌方存活" in main_scene.unit_stats_label.text)
	main_scene.free()


func _test_enemy_generation_guard() -> void:
	var controller := BattleController.new()
	root.add_child(controller)
	controller.start_new_battle()
	controller.enemy_action_delay = 0.03
	controller.end_player_turn()
	var old_generation := controller.battle_generation
	controller.start_new_battle()
	await create_timer(0.12).timeout
	_expect("T027 old enemy task cannot advance new battle", controller.battle_generation == old_generation + 1 and controller.round_number == 1 and controller.current_team == "player")
	_expect("T027 restart restores original enemy position", controller.registry.get_unit("enemy_001").grid_pos == Vector2i(7, 1))
	controller.free()


func _unit(unit_id: String, team: String, unit_type: String, pos: Vector2i, hp: int, shield: int, attack: int, move: int, attack_range: int, special_attribute: String = "none", ability_id: String = "", ability_name: String = "") -> BattleUnit:
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
		"special_attribute": special_attribute,
		"ability_id": ability_id,
		"ability_name": ability_name,
		"sprite": ""
	}, pos)


func _terrain_count(map_data: Dictionary, terrain_id: String) -> int:
	var count := 0
	for row in map_data.get("tiles", []):
		for cell in row:
			if str(cell) == terrain_id:
				count += 1
	return count


func _edge_count(map_data: Dictionary, edge_type: String) -> int:
	var count := 0
	for edge in map_data.get("edges", []):
		if str(edge.get("edge_type", "")) == edge_type:
			count += 1
	return count


func _definitions_contain(definitions: Array, unit_name: String) -> bool:
	for definition in definitions:
		if str(definition.get("name", "")) == unit_name:
			return true
	return false


func _definition_by_name(definitions: Array, unit_name: String) -> Dictionary:
	for definition in definitions:
		if str(definition.get("name", "")) == unit_name:
			return definition
	return {}


func _combat_score(definition: Dictionary) -> float:
	var score := float(definition.get("max_hp", 0))
	score += float(definition.get("shield", 0)) * 2.0
	score += float(definition.get("attack", 0)) * 3.0
	score += float(definition.get("move_range", 0)) * 2.0
	score += float(maxi(int(definition.get("attack_range", 1)) - 1, 0)) * 2.0
	if bool(definition.get("true_damage", false)):
		score += 8.0
	if not str(definition.get("ability_id", "")).is_empty():
		score += 8.0
	return score


func _errors_contain(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _collect_control_text(node: Node) -> String:
	var values: Array[String] = []
	if node is Label or node is Button or node is RichTextLabel:
		values.append(str(node.text))
	for child in node.get_children():
		values.append(_collect_control_text(child))
	return "\n".join(values)


func _has_label_text(node: Node, value: String) -> bool:
	if node is Label and str(node.text) == value:
		return true
	for child in node.get_children():
		if _has_label_text(child, value):
			return true
	return false


func _expect(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s%s" % [label, " - " + detail if not detail.is_empty() else ""])
