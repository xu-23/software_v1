class_name UnitStatOverrides
extends RefCounted

const ALLOWED_FIELDS := ["max_hp", "shield", "attack", "move_range"]


static func apply_to_data(data: Dictionary, override_data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	var units_value: Variant = override_data.get("units", {})
	if not units_value is Dictionary:
		return result
	var units: Dictionary = units_value
	for unit_name in units:
		var values_value: Variant = units[unit_name]
		if not values_value is Dictionary:
			continue
		var values: Dictionary = values_value
		apply_to_definitions(result.get("players", {}).get("units", []), str(unit_name), values)
		apply_to_definitions(result.get("enemies", {}).get("units", []), str(unit_name), values)
	return result


static func apply_to_definitions(definitions: Array, unit_name: String, values: Dictionary) -> Dictionary:
	var errors: Array[String] = _validate_values(unit_name, values)
	var matching: Array[Dictionary] = []
	for definition in definitions:
		if str(definition.get("name", "")) == unit_name:
			matching.append(definition)
	if matching.is_empty():
		errors.append("unit stat override references unknown unit: %s" % unit_name)
	if not errors.is_empty():
		return {"ok": false, "changed": 0, "errors": errors}
	for definition in matching:
		for field in values:
			definition[field] = int(values[field])
	return {"ok": true, "changed": matching.size(), "errors": []}


static func validate(override_data: Dictionary, known_names: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not override_data.has("units") or not override_data.units is Dictionary:
		errors.append("unit stat overrides must contain an object named units")
		return errors
	for unit_name in override_data.units:
		var name_text := str(unit_name)
		if not known_names.has(name_text):
			errors.append("unit stat override references unknown unit: %s" % name_text)
		var values: Variant = override_data.units[unit_name]
		if not values is Dictionary:
			errors.append("unit stat override for %s must be an object" % name_text)
			continue
		errors.append_array(_validate_values(name_text, values))
	return errors


static func known_names(data: Dictionary) -> Dictionary:
	var result := {}
	for side in ["players", "enemies"]:
		for definition in data.get(side, {}).get("units", []):
			result[str(definition.get("name", ""))] = true
	return result


static func _validate_values(unit_name: String, values: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field in values:
		var field_name := str(field)
		if field_name not in ALLOWED_FIELDS:
			errors.append("unit stat override cannot change %s on %s" % [field_name, unit_name])
			continue
		var value: Variant = values[field]
		if not _is_integer(value):
			errors.append("unit stat override %s on %s must be an integer" % [field_name, unit_name])
			continue
		var minimum := 1 if field_name == "max_hp" else 0
		if int(value) < minimum:
			errors.append("unit stat override %s on %s must be >= %d" % [field_name, unit_name, minimum])
	return errors


static func _is_integer(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(value, floor(value))
	return false
