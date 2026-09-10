class_name EnemyAI
extends RefCounted


static func take_turn(enemy: BattleUnit, grid: BattleGrid, registry: BattleUnitRegistry) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if enemy == null or enemy.is_dead:
		return events
	var players := registry.living("player")
	if players.is_empty():
		return events

	var target := _choose_attack_target(enemy, players, grid)
	if target == null:
		var movement := MovementCalculator.calculate(enemy, grid, registry)
		var destination := _choose_destination(enemy, movement, players)
		if destination != enemy.grid_pos:
			var start := enemy.grid_pos
			var path := MovementCalculator.build_path(start, destination, movement.get("parents", {}))
			enemy.grid_pos = destination
			enemy.has_moved = true
			events.append({"type": "move", "unit_id": enemy.id, "from": start, "to": destination, "path": path})
		target = _choose_attack_target(enemy, players, grid)

	if target != null:
		var result := DamageCalculator.apply(enemy, target)
		enemy.has_acted = true
		events.append({"type": "attack", "result": result})
	else:
		enemy.has_acted = true
		events.append({"type": "wait", "unit_id": enemy.id})
	return events


static func _choose_attack_target(attacker: BattleUnit, candidates: Array[BattleUnit], grid: BattleGrid) -> BattleUnit:
	var valid: Array[BattleUnit] = []
	for target in candidates:
		if AttackRangeCalculator.can_attack(attacker, target, grid):
			valid.append(target)
	if valid.is_empty():
		return null
	valid.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.current_hp != b.current_hp:
			return a.current_hp < b.current_hp
		if a.current_shield != b.current_shield:
			return a.current_shield < b.current_shield
		var distance_a := BattleGrid.manhattan(attacker.grid_pos, a.grid_pos)
		var distance_b := BattleGrid.manhattan(attacker.grid_pos, b.grid_pos)
		if distance_a != distance_b:
			return distance_a < distance_b
		return a.id < b.id
	)
	return valid[0]


static func _choose_destination(enemy: BattleUnit, movement: Dictionary, players: Array[BattleUnit]) -> Vector2i:
	var candidates: Array[Vector2i] = [enemy.grid_pos]
	candidates.append_array(movement.get("reachable", []))
	var costs: Dictionary = movement.get("costs", {})
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var distance_a := _nearest_distance(a, players)
		var distance_b := _nearest_distance(b, players)
		if distance_a != distance_b:
			return distance_a < distance_b
		var cost_a := int(costs.get(a, 0))
		var cost_b := int(costs.get(b, 0))
		if cost_a != cost_b:
			return cost_a < cost_b
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return candidates[0]


static func _nearest_distance(pos: Vector2i, players: Array[BattleUnit]) -> int:
	var best := 1000000
	for player in players:
		best = mini(best, BattleGrid.manhattan(pos, player.grid_pos))
	return best
