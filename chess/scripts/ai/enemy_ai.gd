class_name EnemyAI
extends RefCounted

const UNREACHABLE := 1000000


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
		var destination := _choose_destination(enemy, movement, players, grid, registry)
		if destination != enemy.grid_pos:
			var start := enemy.grid_pos
			var path := MovementCalculator.build_path(start, destination, movement.get("parents", {}))
			var move_cost := int(movement.get("costs", {}).get(destination, 0))
			enemy.grid_pos = destination
			enemy.has_moved = true
			enemy.remaining_move_points = maxi(enemy.remaining_move_points - move_cost, 0)
			enemy.move_spent_this_turn += move_cost
			events.append({"type": "move", "unit_id": enemy.id, "from": start, "to": destination, "path": path, "cost": move_cost, "remaining": enemy.remaining_move_points})
			var ability_event := SpecialAbilityResolver.apply_terrain_entry(enemy, grid.get_terrain_id(destination))
			if not ability_event.is_empty():
				events.append(ability_event)
		target = _choose_attack_target(enemy, players, grid)

	if target != null:
		var multiplier := SpecialAbilityResolver.attack_multiplier(enemy, target, grid)
		var result := DamageCalculator.apply(enemy, target, multiplier)
		enemy.has_acted = true
		enemy.remaining_move_points = 0
		events.append({"type": "attack", "result": result})
	else:
		enemy.has_acted = true
		enemy.remaining_move_points = 0
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


static func _choose_destination(enemy: BattleUnit, movement: Dictionary, players: Array[BattleUnit], grid: BattleGrid, registry: BattleUnitRegistry) -> Vector2i:
	var candidates: Array[Vector2i] = [enemy.grid_pos]
	candidates.append_array(movement.get("reachable", []))
	var costs: Dictionary = movement.get("costs", {})
	var strategic_distances := {}
	for candidate in candidates:
		strategic_distances[candidate] = _strategic_distance_to_attack(enemy, candidate, players, grid, registry)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var attack_a := _can_attack_from_any(enemy, a, players, grid)
		var attack_b := _can_attack_from_any(enemy, b, players, grid)
		if attack_a != attack_b:
			return attack_a
		var strategic_a := int(strategic_distances[a])
		var strategic_b := int(strategic_distances[b])
		var route_a := strategic_a < UNREACHABLE
		var route_b := strategic_b < UNREACHABLE
		if route_a != route_b:
			return route_a
		if route_a and strategic_a != strategic_b:
			return strategic_a < strategic_b
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


static func _strategic_distance_to_attack(enemy: BattleUnit, start: Vector2i, players: Array[BattleUnit], grid: BattleGrid, registry: BattleUnitRegistry) -> int:
	var costs := {start: 0}
	var open: Array[Vector2i] = [start]
	var closed := {}
	while not open.is_empty():
		var current := _take_lowest(open, costs)
		if closed.has(current):
			continue
		closed[current] = true
		var occupant := registry.get_at(current)
		if (current == start or occupant == null) and _can_attack_from_any(enemy, current, players, grid):
			return int(costs[current])
		for next in grid.neighbors(current):
			var step_cost := _strategic_step_cost(enemy, current, next, grid)
			if step_cost < 0:
				continue
			var next_occupant := registry.get_at(next)
			if next_occupant != null and next_occupant.team != enemy.team:
				continue
			var total := int(costs[current]) + step_cost
			if not costs.has(next) or total < int(costs[next]):
				costs[next] = total
				open.append(next)
	return UNREACHABLE


static func _strategic_step_cost(enemy: BattleUnit, from: Vector2i, to: Vector2i, grid: BattleGrid) -> int:
	if not grid.is_passable(to):
		return -1
	var edge := grid.get_edge(from, to)
	if edge.is_empty() or not bool(edge.get("passable", false)):
		return -1
	var terrain := grid.get_terrain(to)
	var minimum := int(terrain.get("minimum_entry_points", terrain.get("move_cost", 1)))
	var terrain_cost := int(terrain.get("move_cost", 1))
	if str(terrain.get("move_rule", "normal")) == "consume_all":
		terrain_cost = minimum
	var step_cost := maxi(terrain_cost + int(edge.get("extra_move_cost", 0)), 1)
	if minimum > enemy.move_range or step_cost > enemy.move_range:
		return -1
	return step_cost


static func _take_lowest(open: Array[Vector2i], costs: Dictionary) -> Vector2i:
	var best_index := 0
	for index in range(1, open.size()):
		var candidate := open[index]
		var best := open[best_index]
		if int(costs[candidate]) < int(costs[best]):
			best_index = index
		elif int(costs[candidate]) == int(costs[best]) and (candidate.y < best.y or (candidate.y == best.y and candidate.x < best.x)):
			best_index = index
	return open.pop_at(best_index)


static func _can_attack_from_any(enemy: BattleUnit, pos: Vector2i, players: Array[BattleUnit], grid: BattleGrid) -> bool:
	for player in players:
		if AttackRangeCalculator.can_attack_from(enemy, pos, player, grid):
			return true
	return false


static func _nearest_distance(pos: Vector2i, players: Array[BattleUnit]) -> int:
	var best := 1000000
	for player in players:
		best = mini(best, BattleGrid.manhattan(pos, player.grid_pos))
	return best
