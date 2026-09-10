class_name AttackRangeCalculator
extends RefCounted


static func effective_range(attacker: BattleUnit, target_pos: Vector2i, grid: BattleGrid) -> int:
	if attacker.unit_type == "melee":
		return 1
	var height_difference := grid.get_height(attacker.grid_pos) - grid.get_height(target_pos)
	if height_difference > 0:
		return attacker.attack_range + 1
	if height_difference < 0:
		return maxi(attacker.attack_range - 1, 1)
	return attacker.attack_range


static func can_attack(attacker: BattleUnit, target: BattleUnit, grid: BattleGrid) -> bool:
	if attacker == null or target == null or attacker.is_dead or target.is_dead:
		return false
	if attacker.team == target.team:
		return false
	var distance := BattleGrid.manhattan(attacker.grid_pos, target.grid_pos)
	if distance < 1:
		return false
	if attacker.unit_type == "melee":
		if distance != 1:
			return false
		return not bool(grid.get_edge(attacker.grid_pos, target.grid_pos).get("blocks_melee", false))
	return distance <= effective_range(attacker, target.grid_pos, grid)


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
			elif distance <= effective_range(attacker, pos, grid):
				result.append(pos)
	return result
