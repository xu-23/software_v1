class_name BattleOpportunityState
extends RefCounted

var definitions: Dictionary = {}
var available_by_position: Dictionary = {}


func setup(definition_data: Dictionary, map_data: Dictionary) -> void:
	definitions.clear()
	available_by_position.clear()
	for definition in definition_data.get("opportunities", []):
		definitions[str(definition.get("id", ""))] = definition
	for instance in map_data.get("opportunities", []):
		var values: Array = instance.get("position", [])
		if values.size() != 2:
			continue
		available_by_position[Vector2i(int(values[0]), int(values[1]))] = instance.duplicate(true)


func apply_path(unit: BattleUnit, path: Array) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if unit == null or unit.is_dead:
		return events
	for index in range(1, path.size()):
		var pos: Vector2i = path[index]
		if not available_by_position.has(pos):
			continue
		var instance: Dictionary = available_by_position[pos]
		available_by_position.erase(pos)
		var definition: Dictionary = definitions.get(str(instance.get("opportunity_id", "")), {})
		if definition.is_empty():
			continue
		var effect := str(definition.get("effect", ""))
		var amount := int(definition.get("amount", 0))
		var before := unit.current_hp if effect == "hp" else unit.current_shield
		if effect == "hp":
			unit.current_hp = mini(unit.current_hp + amount, unit.max_hp)
		elif effect == "shield":
			unit.current_shield += amount
		var after := unit.current_hp if effect == "hp" else unit.current_shield
		events.append({
			"type": "opportunity",
			"instance_id": str(instance.get("id", "")),
			"opportunity_id": str(definition.get("id", "")),
			"opportunity_name": str(definition.get("name", "")),
			"unit_id": unit.id,
			"position": pos,
			"effect": effect,
			"requested_amount": amount,
			"actual_amount": after - before,
			"value_before": before,
			"value_after": after
		})
	return events


func has_at(pos: Vector2i) -> bool:
	return available_by_position.has(pos)


func remaining_count() -> int:
	return available_by_position.size()
