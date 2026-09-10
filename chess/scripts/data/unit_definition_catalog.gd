class_name UnitDefinitionCatalog
extends RefCounted


static func unique_by_name(items: Array) -> Array[Dictionary]:
	var by_name := {}
	for item in items:
		var unit_name := str(item.get("name", ""))
		if not unit_name.is_empty() and not by_name.has(unit_name):
			by_name[unit_name] = item
	var result: Array[Dictionary] = []
	for unit_name in by_name:
		result.append(by_name[unit_name])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name) < str(b.name))
	return result
