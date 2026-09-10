class_name GameDataValidator
extends RefCounted


static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["terrain", "edges", "classes", "players", "enemies", "map", "chapter"]:
		if not data.has(key) or data[key].is_empty():
			errors.append("missing data section: %s" % key)
	if not errors.is_empty():
		return errors

	var terrain_ids := _ids(data.terrain.get("terrains", []), "terrain", errors)
	var edge_ids := _ids(data.edges.get("edges", []), "edge", errors)
	var class_ids := _ids(data.classes.get("classes", []), "class", errors)
	_validate_terrains(data.terrain.get("terrains", []), errors)
	_validate_edges(data.edges.get("edges", []), errors)
	_validate_units(data.players.get("units", []), "player", class_ids, errors)
	_validate_units(data.enemies.get("units", []), "enemy", class_ids, errors)
	_validate_map(data.map, terrain_ids, edge_ids, errors)
	_validate_chapter(data.chapter, data.map, data.players.get("units", []), data.enemies.get("units", []), terrain_ids, errors)
	return errors


static func _ids(items: Array, label: String, errors: Array[String]) -> Dictionary:
	var result := {}
	for item in items:
		var item_id: String = str(item.get("id", ""))
		if item_id.is_empty():
			errors.append("%s has empty id" % label)
		elif result.has(item_id):
			errors.append("duplicate %s id: %s" % [label, item_id])
		else:
			result[item_id] = true
	return result


static func _validate_terrains(items: Array, errors: Array[String]) -> void:
	for item in items:
		var item_id := str(item.get("id", "<unknown>"))
		if not item.has("passable") or not item.has("move_cost") or not item.has("height"):
			errors.append("terrain missing required field: %s" % item_id)
		if int(item.get("move_cost", -1)) < 0:
			errors.append("terrain move_cost must be >= 0: %s" % item_id)


static func _validate_edges(items: Array, errors: Array[String]) -> void:
	for item in items:
		var item_id := str(item.get("id", "<unknown>"))
		for field in ["passable", "extra_move_cost", "blocks_melee", "blocks_ranged"]:
			if not item.has(field):
				errors.append("edge %s missing field: %s" % [item_id, field])
		if int(item.get("extra_move_cost", -1)) < 0:
			errors.append("edge extra_move_cost must be >= 0: %s" % item_id)


static func _validate_units(items: Array, expected_team: String, class_ids: Dictionary, errors: Array[String]) -> void:
	var seen := {}
	for item in items:
		var unit_id := str(item.get("id", ""))
		if unit_id.is_empty() or seen.has(unit_id):
			errors.append("empty or duplicate unit id in %s units: %s" % [expected_team, unit_id])
		seen[unit_id] = true
		if item.get("team", "") != expected_team:
			errors.append("unit has invalid team: %s" % unit_id)
		var unit_type := str(item.get("unit_type", ""))
		if unit_type not in ["melee", "ranged"]:
			errors.append("unit has invalid unit_type: %s" % unit_id)
		if unit_type == "melee" and int(item.get("attack_range", 0)) != 1:
			errors.append("melee attack_range must be 1: %s" % unit_id)
		if int(item.get("attack_range", 0)) < 1:
			errors.append("attack_range must be >= 1: %s" % unit_id)
		if int(item.get("max_hp", 0)) <= 0:
			errors.append("max_hp must be > 0: %s" % unit_id)
		for field in ["shield", "attack", "move_range"]:
			if int(item.get(field, -1)) < 0:
				errors.append("%s must be >= 0: %s" % [field, unit_id])
		if not class_ids.has(str(item.get("class_id", ""))):
			errors.append("unit has unknown class_id: %s" % unit_id)


static func _validate_map(map_data: Dictionary, terrain_ids: Dictionary, edge_ids: Dictionary, errors: Array[String]) -> void:
	var width := int(map_data.get("width", 0))
	var height := int(map_data.get("height", 0))
	var tiles: Array = map_data.get("tiles", [])
	if width <= 0 or height <= 0:
		errors.append("map dimensions must be positive")
	if tiles.size() != height:
		errors.append("map tile row count does not match height")
	for y in range(tiles.size()):
		var row: Array = tiles[y]
		if row.size() != width:
			errors.append("map row %d does not match width" % y)
		for terrain_id in row:
			if not terrain_ids.has(str(terrain_id)):
				errors.append("map uses unknown terrain: %s" % terrain_id)
	var edge_names := {}
	for edge in map_data.get("edges", []):
		var edge_id := str(edge.get("id", ""))
		if edge_id.is_empty() or edge_names.has(edge_id):
			errors.append("empty or duplicate map edge id: %s" % edge_id)
		edge_names[edge_id] = true
		var a := _array_to_pos(edge.get("a", []))
		var b := _array_to_pos(edge.get("b", []))
		if not _inside(a, width, height) or not _inside(b, width, height):
			errors.append("edge endpoint outside map: %s" % edge_id)
		elif abs(a.x - b.x) + abs(a.y - b.y) != 1:
			errors.append("edge endpoints are not adjacent: %s" % edge_id)
		if not edge_ids.has(str(edge.get("edge_type", ""))):
			errors.append("unknown edge type on: %s" % edge_id)


static func _validate_chapter(chapter: Dictionary, map_data: Dictionary, players: Array, enemies: Array, _terrain_ids: Dictionary, errors: Array[String]) -> void:
	if str(chapter.get("map_id", "")) != str(map_data.get("id", "")):
		errors.append("chapter map_id does not match loaded map")
	var known_units := {}
	for unit in players + enemies:
		known_units[str(unit.get("id", ""))] = true
	var occupied := {}
	var width := int(map_data.get("width", 0))
	var height := int(map_data.get("height", 0))
	for group in [chapter.get("player_spawns", {}), chapter.get("enemy_spawns", {})]:
		for unit_id in group:
			var pos := _array_to_pos(group[unit_id])
			if not known_units.has(str(unit_id)):
				errors.append("spawn references unknown unit: %s" % unit_id)
			if not _inside(pos, width, height):
				errors.append("spawn outside map: %s" % unit_id)
			elif occupied.has(pos):
				errors.append("duplicate spawn position: %s" % pos)
			else:
				occupied[pos] = unit_id
			var tiles: Array = map_data.get("tiles", [])
			if _inside(pos, width, height) and (pos.y >= tiles.size() or pos.x >= (tiles[pos.y] as Array).size()):
				errors.append("spawn has no tile: %s" % unit_id)


static func _array_to_pos(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-9999, -9999)


static func _inside(pos: Vector2i, width: int, height: int) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height
