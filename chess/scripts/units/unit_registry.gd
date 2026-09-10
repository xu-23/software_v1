class_name BattleUnitRegistry
extends RefCounted

var units: Dictionary = {}


func add_unit(unit: BattleUnit) -> bool:
	if unit == null or unit.id.is_empty() or units.has(unit.id):
		push_error("[BattleUnitRegistry.add_unit] invalid or duplicate unit")
		return false
	if get_at(unit.grid_pos) != null:
		push_error("[BattleUnitRegistry.add_unit] occupied spawn: %s" % unit.grid_pos)
		return false
	units[unit.id] = unit
	return true


func get_unit(unit_id: String) -> BattleUnit:
	return units.get(unit_id) as BattleUnit


func get_at(pos: Vector2i) -> BattleUnit:
	for unit in units.values():
		if not unit.is_dead and unit.grid_pos == pos:
			return unit
	return null


func living(team: String = "") -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in units.values():
		if not unit.is_dead and (team.is_empty() or unit.team == team):
			result.append(unit)
	result.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.id < b.id)
	return result


func reset_team(team: String) -> void:
	for unit in living(team):
		unit.reset_turn()


func all_acted(team: String) -> bool:
	var team_units := living(team)
	if team_units.is_empty():
		return true
	for unit in team_units:
		if not unit.has_acted:
			return false
	return true


func occupied_positions() -> Dictionary:
	var result := {}
	for unit in living():
		result[unit.grid_pos] = unit
	return result
