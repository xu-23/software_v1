class_name MovementCalculator
extends RefCounted


static func calculate(unit: BattleUnit, grid: BattleGrid, registry: BattleUnitRegistry) -> Dictionary:
	var costs := {unit.grid_pos: 0}
	var parents := {}
	var open: Array[Vector2i] = [unit.grid_pos]
	var closed := {}
	while not open.is_empty():
		var current := _take_lowest(open, costs)
		if closed.has(current):
			continue
		closed[current] = true
		for next in grid.neighbors(current):
			var step_cost := grid.get_step_cost(current, next)
			if step_cost < 0:
				continue
			var occupant := registry.get_at(next)
			if occupant != null and occupant.team != unit.team:
				continue
			var total: int = int(costs[current]) + step_cost
			if total > unit.move_range:
				continue
			if not costs.has(next) or total < int(costs[next]):
				costs[next] = total
				parents[next] = current
				open.append(next)
	var reachable: Array[Vector2i] = []
	for pos in costs:
		if pos != unit.grid_pos and registry.get_at(pos) == null:
			reachable.append(pos)
	reachable.sort_custom(_sort_pos)
	return {"costs": costs, "parents": parents, "reachable": reachable}


static func build_path(start: Vector2i, target: Vector2i, parents: Dictionary) -> Array[Vector2i]:
	if start == target:
		return [start]
	if not parents.has(target):
		return []
	var path: Array[Vector2i] = [target]
	var current := target
	while current != start:
		current = parents[current]
		path.push_front(current)
	return path


static func _take_lowest(open: Array[Vector2i], costs: Dictionary) -> Vector2i:
	var best_index := 0
	for index in range(1, open.size()):
		var candidate := open[index]
		var best := open[best_index]
		if int(costs[candidate]) < int(costs[best]) or (int(costs[candidate]) == int(costs[best]) and _sort_pos(candidate, best)):
			best_index = index
	return open.pop_at(best_index)


static func _sort_pos(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
