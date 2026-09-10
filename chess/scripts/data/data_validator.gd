class_name GameDataValidator
extends RefCounted


static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["terrain", "edges", "abilities", "classes", "players", "enemies", "map", "chapter"]:
		if not data.has(key) or data[key].is_empty():
			errors.append("missing data section: %s" % key)
	if not errors.is_empty():
		return errors
	for override_error in data.get("unit_stat_override_errors", []):
		errors.append(str(override_error))

	var terrain_ids := _ids(data.terrain.get("terrains", []), "terrain", errors)
	var terrain_defs := _by_id(data.terrain.get("terrains", []))
	var edge_ids := _ids(data.edges.get("edges", []), "edge", errors)
	var ability_ids := _ids(data.abilities.get("abilities", []), "ability", errors)
	var ability_defs := _by_id(data.abilities.get("abilities", []))
	var class_ids := _ids(data.classes.get("classes", []), "class", errors)
	_validate_terrains(data.terrain.get("terrains", []), errors)
	_validate_edges(data.edges.get("edges", []), errors)
	_validate_abilities(data.abilities.get("abilities", []), errors)
	_validate_units(data.players.get("units", []), "player", class_ids, ability_ids, ability_defs, errors)
	_validate_units(data.enemies.get("units", []), "enemy", class_ids, ability_ids, ability_defs, errors)
	_validate_unit_names(data.players.get("units", []) + data.enemies.get("units", []), errors)
	_validate_map(data.map, terrain_ids, edge_ids, errors)
	_validate_chapter(data.chapter, data.map, data.players.get("units", []), data.enemies.get("units", []), terrain_defs, errors)
	return errors


static func validate_catalog(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var chapters: Array = catalog.get("chapters", [])
	if chapters.is_empty():
		errors.append("chapter catalog must contain at least one chapter")
		return errors
	_ids(chapters, "chapter catalog", errors)
	for entry in chapters:
		var chapter_id := str(entry.get("id", "<unknown>"))
		for field in ["name", "difficulty", "map_path", "chapter_path"]:
			if str(entry.get(field, "")).is_empty():
				errors.append("catalog entry %s missing field: %s" % [chapter_id, field])
		for path_field in ["map_path", "chapter_path"]:
			var path := str(entry.get(path_field, ""))
			if not path.is_empty() and (not path.begins_with("res://") or not FileAccess.file_exists(path)):
				errors.append("catalog entry %s has invalid %s: %s" % [chapter_id, path_field, path])
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


static func _by_id(items: Array) -> Dictionary:
	var result := {}
	for item in items:
		result[str(item.get("id", ""))] = item
	return result


static func _validate_terrains(items: Array, errors: Array[String]) -> void:
	for item in items:
		var item_id := str(item.get("id", "<unknown>"))
		if not item.has("passable") or not item.has("move_cost") or not item.has("height"):
			errors.append("terrain missing required field: %s" % item_id)
		if int(item.get("move_cost", -1)) < 0:
			errors.append("terrain move_cost must be >= 0: %s" % item_id)
		var move_rule := str(item.get("move_rule", "normal"))
		if move_rule not in ["normal", "consume_all"]:
			errors.append("terrain has invalid move_rule: %s" % item_id)
		if move_rule == "consume_all" and int(item.get("minimum_entry_points", 0)) < 1:
			errors.append("consume_all terrain needs minimum_entry_points: %s" % item_id)


static func _validate_edges(items: Array, errors: Array[String]) -> void:
	for item in items:
		var item_id := str(item.get("id", "<unknown>"))
		for field in ["passable", "extra_move_cost", "blocks_melee", "blocks_ranged"]:
			if not item.has(field):
				errors.append("edge %s missing field: %s" % [item_id, field])
		if int(item.get("extra_move_cost", -1)) < 0:
			errors.append("edge extra_move_cost must be >= 0: %s" % item_id)


static func _validate_abilities(items: Array, errors: Array[String]) -> void:
	for item in items:
		var ability_id := str(item.get("id", "<unknown>"))
		for field in ["name", "special_attribute", "trigger", "description"]:
			if str(item.get(field, "")).is_empty():
				errors.append("ability %s missing field: %s" % [ability_id, field])
		if str(item.get("special_attribute", "")) not in ["wood", "fire", "earth"]:
			errors.append("ability has invalid special_attribute: %s" % ability_id)


static func _validate_units(items: Array, expected_team: String, class_ids: Dictionary, ability_ids: Dictionary, ability_defs: Dictionary, errors: Array[String]) -> void:
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
		var special_attribute := str(item.get("special_attribute", "none"))
		var ability_id := str(item.get("ability_id", ""))
		if special_attribute not in ["none", "wood", "fire", "earth"]:
			errors.append("unit has invalid special_attribute: %s" % unit_id)
		if special_attribute == "none" and not ability_id.is_empty():
			errors.append("unit without special attribute cannot have ability: %s" % unit_id)
		elif special_attribute != "none":
			if not ability_ids.has(ability_id):
				errors.append("unit has unknown ability_id: %s" % unit_id)
			elif str(ability_defs[ability_id].get("special_attribute", "")) != special_attribute:
				errors.append("unit ability attribute mismatch: %s" % unit_id)


static func _validate_unit_names(items: Array, errors: Array[String]) -> void:
	var definitions_by_name := {}
	for item in items:
		var unit_name := str(item.get("name", ""))
		var unit_id := str(item.get("id", "<unknown>"))
		if unit_name.is_empty():
			errors.append("unit has empty name: %s" % unit_id)
			continue
		if not definitions_by_name.has(unit_name):
			definitions_by_name[unit_name] = item
			continue
		var canonical: Dictionary = definitions_by_name[unit_name]
		var static_fields: Array = canonical.keys()
		for field in item.keys():
			if field not in static_fields:
				static_fields.append(field)
		static_fields.erase("id")
		for field in static_fields:
			if canonical.get(field) != item.get(field):
				errors.append("unit name %s has conflicting field %s on %s" % [unit_name, field, unit_id])


static func _validate_map(map_data: Dictionary, terrain_ids: Dictionary, edge_ids: Dictionary, errors: Array[String]) -> void:
	for generation_error in map_data.get("generation_errors", []):
		errors.append(str(generation_error))
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


static func _validate_chapter(chapter: Dictionary, map_data: Dictionary, players: Array, enemies: Array, terrain_defs: Dictionary, errors: Array[String]) -> void:
	if str(chapter.get("map_id", "")) != str(map_data.get("id", "")):
		errors.append("chapter map_id does not match loaded map")
	var known_units := {}
	var player_ids := _by_id(players)
	var enemy_ids := _by_id(enemies)
	for unit in players + enemies:
		known_units[str(unit.get("id", ""))] = true
	var occupied := {}
	var width := int(map_data.get("width", 0))
	var height := int(map_data.get("height", 0))
	var spawn_groups := [chapter.get("player_spawns", {}), chapter.get("enemy_spawns", {})]
	for group_index in range(spawn_groups.size()):
		var group: Dictionary = spawn_groups[group_index]
		for unit_id in group:
			var pos := _array_to_pos(group[unit_id])
			if not known_units.has(str(unit_id)):
				errors.append("spawn references unknown unit: %s" % unit_id)
			elif group_index == 0 and not player_ids.has(str(unit_id)):
				errors.append("player spawn references non-player unit: %s" % unit_id)
			elif group_index == 1 and not enemy_ids.has(str(unit_id)):
				errors.append("enemy spawn references non-enemy unit: %s" % unit_id)
			if not _inside(pos, width, height):
				errors.append("spawn outside map: %s" % unit_id)
			elif occupied.has(pos):
				errors.append("duplicate spawn position: %s" % pos)
			else:
				occupied[pos] = unit_id
			var tiles: Array = map_data.get("tiles", [])
			if _inside(pos, width, height):
				if pos.y >= tiles.size() or pos.x >= (tiles[pos.y] as Array).size():
					errors.append("spawn has no tile: %s" % unit_id)
				else:
					var terrain_id := str(tiles[pos.y][pos.x])
					if not terrain_defs.has(terrain_id) or not bool(terrain_defs[terrain_id].get("passable", false)):
						errors.append("spawn is on impassable terrain: %s" % unit_id)


static func _array_to_pos(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-9999, -9999)


static func _inside(pos: Vector2i, width: int, height: int) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height
