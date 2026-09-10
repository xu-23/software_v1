class_name AttackRangeCalculator
extends RefCounted


static func effective_range(attacker: BattleUnit, target_pos: Vector2i, grid: BattleGrid) -> int:
	if not grid.in_bounds(target_pos):
		return 0
	return attacker.attack_range


static func can_attack(attacker: BattleUnit, target: BattleUnit, grid: BattleGrid) -> bool:
	if attacker == null:
		return false
	return can_attack_from(attacker, attacker.grid_pos, target, grid)


static func can_attack_from(attacker: BattleUnit, from_pos: Vector2i, target: BattleUnit, grid: BattleGrid) -> bool:
	if attacker == null or target == null or attacker.is_dead or target.is_dead:
		return false
	if attacker.team == target.team:
		return false
	if not grid.in_bounds(from_pos) or not grid.in_bounds(target.grid_pos):
		return false
	var distance := BattleGrid.manhattan(from_pos, target.grid_pos)
	if distance < 1:
		return false
	if attacker.unit_type == "melee":
		if distance != 1:
			return false
		return not bool(grid.get_edge(from_pos, target.grid_pos).get("blocks_melee", false))
	return distance <= attacker.attack_range and grid.get_height(from_pos) >= grid.get_height(target.grid_pos)


static func range_cells(attacker: BattleUnit, grid: BattleGrid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(grid.height):
		for x in range(grid.width):
			var pos := Vector2i(x, y)
			var distance := BattleGrid.manhattan(attacker.grid_pos, pos)
			if distance < 1:
				continue
			if attacker.unit_type == "melee":
				if distance == 1 and not bool(grid.get_edge(attacker.grid_pos, pos).get("blocks_melee", false)):
					result.append(pos)
			elif distance <= attacker.attack_range and grid.get_height(attacker.grid_pos) >= grid.get_height(pos):
				result.append(pos)
	return result
