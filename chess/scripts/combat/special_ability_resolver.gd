class_name SpecialAbilityResolver
extends RefCounted


static func apply_terrain_entry(unit: BattleUnit, terrain_id: String) -> Dictionary:
	if unit == null or unit.is_dead:
		return {}
	if unit.ability_id == "renewal" and terrain_id == "forest":
		if unit.turn_triggered_abilities.has(unit.ability_id):
			return {}
		unit.turn_triggered_abilities[unit.ability_id] = true
		var shield_before := unit.current_shield
		unit.current_shield += 2
		return _shield_event(unit, shield_before)
	if unit.ability_id == "source_of_all" and terrain_id == "hill":
		if unit.battle_triggered_abilities.has(unit.ability_id):
			return {}
		unit.battle_triggered_abilities[unit.ability_id] = true
		var shield_before := unit.current_shield
		if unit.current_shield > 0:
			unit.current_shield *= 2
		return _shield_event(unit, shield_before)
	return {}


static func attack_multiplier(attacker: BattleUnit, target: BattleUnit, grid: BattleGrid) -> int:
	if attacker == null or target == null or grid == null:
		return 1
	if attacker.ability_id == "burning_camp" and grid.get_terrain_id(target.grid_pos) == "forest":
		return 2
	return 1


static func _shield_event(unit: BattleUnit, shield_before: int) -> Dictionary:
	return {
		"type": "ability",
		"unit_id": unit.id,
		"ability_id": unit.ability_id,
		"ability_name": unit.ability_name,
		"shield_before": shield_before,
		"shield_after": unit.current_shield
	}
