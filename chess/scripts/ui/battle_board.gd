class_name BattleBoard
extends Control

signal hovered_cell_changed(pos: Vector2i)

const BOARD_SIZE := 10

var controller: BattleController
var hovered_pos := Vector2i(-1, -1)
var tile_size := 56.0
var board_origin := Vector2.ZERO

var fallback_font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	fallback_font = ThemeDB.fallback_font
	resized.connect(_update_geometry)
	mouse_exited.connect(_on_mouse_exited)
	_update_geometry()


func set_controller(value: BattleController) -> void:
	controller = value
	if not controller.state_changed.is_connected(_on_controller_changed):
		controller.state_changed.connect(_on_controller_changed)
	queue_redraw()


func _update_geometry() -> void:
	tile_size = floor(minf(size.x / BOARD_SIZE, size.y / BOARD_SIZE))
	board_origin = (size - Vector2(tile_size * BOARD_SIZE, tile_size * BOARD_SIZE)) * 0.5
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if controller == null or not controller.initialized:
		return
	if event is InputEventMouseMotion:
		_set_hovered_pos(_screen_to_grid(event.position))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var pos := _screen_to_grid(event.position)
			if controller.grid.in_bounds(pos):
				controller.click_at(pos)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			controller.cancel_current_action()
			accept_event()


func _draw() -> void:
	if controller == null or not controller.initialized:
		return
	_draw_tiles()
	_draw_highlights()
	_draw_action_paths()
	_draw_edges()
	_draw_units()
	_draw_hover()


func _draw_tiles() -> void:
	for y in range(controller.grid.height):
		for x in range(controller.grid.width):
			var pos := Vector2i(x, y)
			var rect := _cell_rect(pos)
			var terrain := controller.grid.get_terrain(pos)
			var color := Color(str(terrain.get("color", "#888888")))
			draw_rect(rect, color)
			draw_rect(rect, Color("#34383d"), false, 1.0)
			if terrain.id == "forest":
				_draw_forest(rect)
			elif terrain.id == "mountain":
				_draw_mountain(rect)
			var height_value := int(terrain.height)
			if height_value > 0:
				draw_string(fallback_font, rect.position + Vector2(5, 15), "H%d" % height_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.78))


func _draw_forest(rect: Rect2) -> void:
	var green := Color("#315b42")
	var radius := tile_size * 0.09
	for offset in [Vector2(0.30, 0.43), Vector2(0.52, 0.30), Vector2(0.69, 0.51)]:
		draw_circle(rect.position + rect.size * offset, radius, green)


func _draw_mountain(rect: Rect2) -> void:
	var points := PackedVector2Array([
		rect.position + Vector2(tile_size * 0.16, tile_size * 0.78),
		rect.position + Vector2(tile_size * 0.50, tile_size * 0.25),
		rect.position + Vector2(tile_size * 0.84, tile_size * 0.78)
	])
	draw_colored_polygon(points, Color("#44464a"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2]]), Color("#b5b2a9"), 2.0)


func _draw_highlights() -> void:
	var selected := controller.selected_unit()
	if selected != null:
		draw_rect(_cell_rect(selected.grid_pos).grow(-2), Color("#f4c95d"), false, 4.0)
	for pos in controller.movement_data.get("reachable", []):
		draw_rect(_cell_rect(pos).grow(-3), Color(0.20, 0.66, 0.84, 0.38))
	for pos in controller.attack_cells:
		draw_rect(_cell_rect(pos).grow(-3), Color(0.87, 0.23, 0.22, 0.34))


func _draw_action_paths() -> void:
	var preview := get_preview_path()
	if preview.size() > 1:
		_draw_path(preview, Color("#83dff2"), 4.0)
		draw_circle(_cell_rect(preview[-1]).get_center(), 6.0, Color("#e8fbff"))

	var action := controller.last_action
	if action.is_empty():
		return
	if action.get("type", "") == "move":
		var path: Array = action.get("path", [])
		if path.size() > 1:
			_draw_path(path, Color(0.96, 0.72, 0.28, 0.78), 3.0)
	elif action.get("type", "") == "attack":
		var from_pos: Vector2i = action.get("from", Vector2i(-1, -1))
		var to_pos: Vector2i = action.get("to", Vector2i(-1, -1))
		if controller.grid.in_bounds(from_pos) and controller.grid.in_bounds(to_pos):
			draw_line(_cell_rect(from_pos).get_center(), _cell_rect(to_pos).get_center(), Color(0.96, 0.35, 0.29, 0.88), 4.0)
			draw_rect(_cell_rect(to_pos).grow(-5), Color("#ff695c"), false, 4.0)


func _draw_path(path: Array, color: Color, width: float) -> void:
	for index in range(path.size() - 1):
		var from_pos: Vector2i = path[index]
		var to_pos: Vector2i = path[index + 1]
		draw_line(_cell_rect(from_pos).get_center(), _cell_rect(to_pos).get_center(), color, width)


func get_preview_path() -> Array[Vector2i]:
	if controller == null or controller.phase != "move":
		return []
	if hovered_pos not in controller.movement_data.get("reachable", []):
		return []
	return controller.get_selected_path(hovered_pos)


func _draw_edges() -> void:
	for key in controller.grid.edge_instances:
		var parts: PackedStringArray = str(key).split("|")
		var a_values: PackedStringArray = parts[0].split(",")
		var b_values: PackedStringArray = parts[1].split(",")
		var a := Vector2i(int(a_values[0]), int(a_values[1]))
		var b := Vector2i(int(b_values[0]), int(b_values[1]))
		var edge_type: String = controller.grid.edge_instances[key]
		var line := _edge_line(a, b)
		if edge_type == "river":
			draw_line(line[0], line[1], Color("#3fb9df"), 5.0)
			draw_line(line[0], line[1], Color("#bceaf5"), 1.0)
		elif edge_type == "cliff":
			draw_line(line[0], line[1], Color("#29252a"), 7.0)
			draw_line(line[0], line[1], Color("#e0a15b"), 2.0)


func _draw_units() -> void:
	for unit in controller.registry.living():
		var rect := _cell_rect(unit.grid_pos)
		var center := rect.get_center()
		var radius := tile_size * 0.31
		var team_color := Color("#247ba0") if unit.team == "player" else Color("#c94c4c")
		if unit.has_acted:
			team_color = team_color.darkened(0.34)
		if unit.current_shield > 0:
			draw_arc(center, radius + 4, 0, TAU, 36, Color("#68d5ef"), 4.0)
		draw_circle(center, radius, Color("#171b20"))
		draw_circle(center, radius - 2, team_color)
		var symbol := "M" if unit.unit_type == "melee" else "R"
		draw_string(fallback_font, center + Vector2(-radius, 6), symbol, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 17, Color.WHITE)
		var hp_ratio: float = float(unit.current_hp) / float(unit.max_hp)
		var bar_rect := Rect2(rect.position + Vector2(7, tile_size - 10), Vector2(tile_size - 14, 5))
		draw_rect(bar_rect, Color("#382f35"))
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * hp_ratio, bar_rect.size.y)), Color("#59c36a"))


func _draw_hover() -> void:
	if controller.grid.in_bounds(hovered_pos):
		draw_rect(_cell_rect(hovered_pos).grow(-1), Color(1, 1, 1, 0.66), false, 2.0)


func _cell_rect(pos: Vector2i) -> Rect2:
	return Rect2(board_origin + Vector2(pos.x, pos.y) * tile_size, Vector2.ONE * tile_size)


func _edge_line(a: Vector2i, b: Vector2i) -> PackedVector2Array:
	var rect_a := _cell_rect(a)
	if a.x == b.x:
		var y: float = rect_a.end.y if b.y > a.y else rect_a.position.y
		return PackedVector2Array([Vector2(rect_a.position.x, y), Vector2(rect_a.end.x, y)])
	var x: float = rect_a.end.x if b.x > a.x else rect_a.position.x
	return PackedVector2Array([Vector2(x, rect_a.position.y), Vector2(x, rect_a.end.y)])


func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local := screen_pos - board_origin
	return Vector2i(floori(local.x / tile_size), floori(local.y / tile_size))


func _set_hovered_pos(pos: Vector2i) -> void:
	if controller != null and not controller.grid.in_bounds(pos):
		pos = Vector2i(-1, -1)
	if pos == hovered_pos:
		return
	hovered_pos = pos
	hovered_cell_changed.emit(hovered_pos)
	queue_redraw()


func _on_mouse_exited() -> void:
	_set_hovered_pos(Vector2i(-1, -1))


func _on_controller_changed() -> void:
	hovered_cell_changed.emit(hovered_pos)
	queue_redraw()
