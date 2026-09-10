class_name GameDataLoader
extends RefCounted


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[GameDataLoader.load_json] file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[GameDataLoader.load_json] cannot open: %s" % path)
		return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error("[GameDataLoader.load_json] invalid JSON at line %d in %s: %s" % [json.get_error_line(), path, json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		push_error("[GameDataLoader.load_json] root must be an object: %s" % path)
		return {}
	return json.data


static func load_chapter_catalog() -> Dictionary:
	return load_json("res://data/chapters/chapter_catalog.json")


static func load_game_data(chapter_id: String = "stage_001", supplied_overrides: Variant = null) -> Dictionary:
	var catalog := load_chapter_catalog()
	var entry := {}
	for candidate in catalog.get("chapters", []):
		if str(candidate.get("id", "")) == chapter_id:
			entry = candidate
			break
	if entry.is_empty():
		push_error("[GameDataLoader.load_game_data] unknown chapter: %s" % chapter_id)
		return {}
	var map_spec := load_json(str(entry.map_path))
	var map_data := ProceduralMapGenerator.generate(map_spec) if map_spec.has("generation") else map_spec
	var data := {
		"terrain": load_json("res://data/terrain/terrain_defs.json"),
		"edges": load_json("res://data/terrain/edge_defs.json"),
		"abilities": load_json("res://data/abilities/ability_defs.json"),
		"classes": load_json("res://data/classes/class_defs.json"),
		"players": load_json("res://data/units/player_units.json"),
		"enemies": load_json("res://data/units/enemy_units.json"),
		"map": map_data,
		"chapter": load_json(str(entry.chapter_path)),
		"catalog_entry": entry
	}
	var override_data: Dictionary
	var override_errors: Array[String] = []
	if supplied_overrides == null:
		override_data = load_json("res://data/units/unit_stat_overrides.json")
	elif supplied_overrides is Dictionary:
		override_data = supplied_overrides
	else:
		override_data = {"units": {}}
		override_errors.append("unit stat overrides root must be an object")
	override_errors.append_array(UnitStatOverrides.validate(override_data, UnitStatOverrides.known_names(data)))
	data = UnitStatOverrides.apply_to_data(data, override_data)
	data["unit_stat_overrides"] = override_data
	data["unit_stat_override_errors"] = override_errors
	return data
