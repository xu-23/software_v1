class_name BattleGrid
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var width: int
var height: int
var tiles: Array
var terrain_defs: Dictionary = {}
var edge_defs: Dictionary = {}
var edge_instances: Dictionary = {}


func setup(map_data: Dictionary, terrain_data: Dictionary, edge_data: Dictionary) -> void:
	width = int(map_data.width)
	height = int(map_data.height)
	tiles = map_data.tiles
	for definition in terrain_data.get("terrains", []):
		terrain_defs[str(definition.id)] = definition
	for definition in edge_data.get("edges", []):
		edge_defs[str(definition.id)] = definition
	for edge in map_data.get("edges", []):
		var a := Vector2i(int(edge.a[0]), int(edge.a[1]))
		var b := Vector2i(int(edge.b[0]), int(edge.b[1]))
		edge_instances[_edge_key(a, b)] = str(edge.edge_type)


func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height


func get_terrain_id(pos: Vector2i) -> String:
	if not in_bounds(pos):
		push_error("[BattleGrid.get_terrain_id] invalid grid position: %s" % pos)
		return ""
	return str(tiles[pos.y][pos.x])


func get_terrain(pos: Vector2i) -> Dictionary:
	var terrain_id := get_terrain_id(pos)
	if not terrain_defs.has(terrain_id):
		push_error("[BattleGrid.get_terrain] unknown terrain: %s" % terrain_id)
		return {}
	return terrain_defs[terrain_id]


func get_height(pos: Vector2i) -> int:
	return int(get_terrain(pos).get("height", 0))


func is_passable(pos: Vector2i) -> bool:
	return in_bounds(pos) and bool(get_terrain(pos).get("passable", false))


func get_edge_type(a: Vector2i, b: Vector2i) -> String:
	if not in_bounds(a) or not in_bounds(b) or manhattan(a, b) != 1:
		push_error("[BattleGrid.get_edge_type] positions must be adjacent and in bounds: %s -> %s" % [a, b])
		return ""
	return str(edge_instances.get(_edge_key(a, b), "normal"))


func get_edge(a: Vector2i, b: Vector2i) -> Dictionary:
	var edge_type := get_edge_type(a, b)
	if not edge_defs.has(edge_type):
		push_error("[BattleGrid.get_edge] unknown edge type: %s" % edge_type)
		return {}
	return edge_defs[edge_type]


func get_step_cost(a: Vector2i, b: Vector2i) -> int:
	if not is_passable(b):
		return -1
	var edge := get_edge(a, b)
	if edge.is_empty() or not bool(edge.get("passable", false)):
		return -1
	var terrain := get_terrain(b)
	var uphill := maxi(get_height(b) - get_height(a), 0)
	return int(terrain.get("move_cost", 0)) + uphill + int(edge.get("extra_move_cost", 0))


func neighbors(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var next := pos + direction
		if in_bounds(next):
			result.append(next)
	return result


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.y < b.y or (a.y == b.y and a.x <= b.x):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]
