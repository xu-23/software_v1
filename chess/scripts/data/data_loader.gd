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


static func load_game_data() -> Dictionary:
	return {
		"terrain": load_json("res://data/terrain/terrain_defs.json"),
		"edges": load_json("res://data/terrain/edge_defs.json"),
		"classes": load_json("res://data/classes/class_defs.json"),
		"players": load_json("res://data/units/player_units.json"),
		"enemies": load_json("res://data/units/enemy_units.json"),
		"map": load_json("res://data/maps/map_001.json"),
		"chapter": load_json("res://data/chapters/chapter_001.json")
	}
