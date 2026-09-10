class_name ProceduralMapGenerator
extends RefCounted

const CARDINALS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


static func generate(spec: Dictionary, seed_override: int = -1) -> Dictionary:
	var generation: Dictionary = spec.get("generation", {})
	if generation.is_empty():
		return spec.duplicate(true)
	var width := int(spec.get("width", 0))
	var height := int(spec.get("height", 0))
	var seed_value := seed_override if seed_override >= 0 else int(generation.get("seed", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var protected := _positions_to_set(generation.get("protected_tiles", []))
	var anchors := _positions(generation.get("connectivity_anchors", []))
	var tiles: Array = []
	for y in range(height):
		var row: Array[String] = []
		for _x in range(width):
			row.append("plain")
		tiles.append(row)
	var candidates: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not protected.has(pos):
				candidates.append(pos)
	_shuffle(candidates, rng)
	var errors: Array[String] = []
	for terrain_id in ["forest", "hill", "swamp", "water", "mountain"]:
		var required := int(generation.get("terrain_counts", {}).get(terrain_id, 0))
		var placed := _place_terrain(tiles, candidates, terrain_id, required, anchors)
		if placed < required:
			errors.append("generated map placed %d/%d %s tiles" % [placed, required, terrain_id])
	var edge_candidates := _edge_candidates(tiles)
	_shuffle(edge_candidates, rng)
	var edges: Array[Dictionary] = []
	var river_count := int(generation.get("edge_counts", {}).get("river", 0))
	var rivers_placed := _place_edges(edges, edge_candidates, "river", river_count, tiles, anchors, false)
	if rivers_placed < river_count:
		errors.append("generated map placed %d/%d river edges" % [rivers_placed, river_count])
	var cliff_count := int(generation.get("edge_counts", {}).get("cliff", 0))
	var cliffs_placed := _place_edges(edges, edge_candidates, "cliff", cliff_count, tiles, anchors, true)
	if cliffs_placed < cliff_count:
		errors.append("generated map placed %d/%d cliff edges" % [cliffs_placed, cliff_count])
	return {
		"id": str(spec.get("id", "generated_map")),
		"name": str(spec.get("name", "Generated Map")),
		"width": width,
		"height": height,
		"tiles": tiles,
		"edges": edges,
		"generation_seed": seed_value,
		"generation_requirements": generation.duplicate(true),
		"generation_errors": errors
	}


static func anchors_connected(map_data: Dictionary, anchors: Array[Vector2i]) -> bool:
	return _anchors_connected(map_data.get("tiles", []), anchors, _cliff_keys(map_data.get("edges", [])))


static func _place_terrain(tiles: Array, candidates: Array[Vector2i], terrain_id: String, required: int, anchors: Array[Vector2i]) -> int:
	var placed := 0
	var impassable := terrain_id in ["water", "mountain"]
	for pos in candidates:
		if placed >= required:
			break
		if str(tiles[pos.y][pos.x]) != "plain":
			continue
		tiles[pos.y][pos.x] = terrain_id
		if impassable and not _anchors_connected(tiles, anchors, {}):
			tiles[pos.y][pos.x] = "plain"
			continue
		placed += 1
	return placed


static func _place_edges(edges: Array[Dictionary], candidates: Array, edge_type: String, required: int, tiles: Array, anchors: Array[Vector2i], protect_connectivity: bool) -> int:
	var placed := 0
	var used := {}
	for edge in edges:
		used[_edge_key(_array_to_pos(edge.a), _array_to_pos(edge.b))] = true
	for pair in candidates:
		if placed >= required:
			break
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		var key := _edge_key(a, b)
		if used.has(key):
			continue
		var candidate := {"id": "edge_%s_%03d" % [edge_type, placed + 1], "a": [a.x, a.y], "b": [b.x, b.y], "edge_type": edge_type}
		edges.append(candidate)
		if protect_connectivity and not _anchors_connected(tiles, anchors, _cliff_keys(edges)):
			edges.pop_back()
			continue
		used[key] = true
		placed += 1
	return placed


static func _edge_candidates(tiles: Array) -> Array:
	var result: Array = []
	var height := tiles.size()
	var width := (tiles[0] as Array).size() if height > 0 else 0
	for y in range(height):
		for x in range(width):
			var a := Vector2i(x, y)
			if not _is_passable(tiles, a):
				continue
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var b: Vector2i = a + direction
				if _inside(b, width, height) and _is_passable(tiles, b):
					result.append([a, b])
	return result


static func _anchors_connected(tiles: Array, anchors: Array[Vector2i], blocked_edges: Dictionary) -> bool:
	if anchors.is_empty():
		return true
	var height := tiles.size()
	var width := (tiles[0] as Array).size() if height > 0 else 0
	for anchor in anchors:
		if not _inside(anchor, width, height) or not _is_passable(tiles, anchor):
			return false
	var visited := {anchors[0]: true}
	var queue: Array[Vector2i] = [anchors[0]]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in CARDINALS:
			var next: Vector2i = current + direction
			if not _inside(next, width, height) or visited.has(next) or not _is_passable(tiles, next):
				continue
			if blocked_edges.has(_edge_key(current, next)):
				continue
			visited[next] = true
			queue.append(next)
	for anchor in anchors:
		if not visited.has(anchor):
			return false
	return true


static func _cliff_keys(edges: Array) -> Dictionary:
	var result := {}
	for edge in edges:
		if str(edge.get("edge_type", "")) == "cliff":
			result[_edge_key(_array_to_pos(edge.get("a", [])), _array_to_pos(edge.get("b", [])))] = true
	return result


static func _positions(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value in values:
		result.append(_array_to_pos(value))
	return result


static func _positions_to_set(values: Array) -> Dictionary:
	var result := {}
	for pos in _positions(values):
		result[pos] = true
	return result


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = value


static func _is_passable(tiles: Array, pos: Vector2i) -> bool:
	return str(tiles[pos.y][pos.x]) not in ["water", "mountain"]


static func _inside(pos: Vector2i, width: int, height: int) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height


static func _array_to_pos(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


static func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.y < b.y or (a.y == b.y and a.x <= b.x):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]
