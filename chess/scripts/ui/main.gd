extends Control

var controller: BattleController
var board: BattleBoard
var turn_label: Label
var status_label: Label
var unit_name_label: Label
var unit_stats_label: RichTextLabel
var terrain_label: Label
var battle_log_label: RichTextLabel
var result_label: Label
var attack_button: Button
var wait_button: Button
var end_turn_button: Button
var hovered_pos := Vector2i(-1, -1)


func _ready() -> void:
	_build_theme()
	_build_interface()
	controller = BattleController.new()
	controller.state_changed.connect(_refresh)
	add_child(controller)
	board.set_controller(controller)
	board.hovered_cell_changed.connect(_on_hovered_cell_changed)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		controller.cancel_current_action()
	elif event.is_action_pressed("ui_accept"):
		controller.wait_selected()


func _build_interface() -> void:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	page.add_theme_constant_override("separation", 12)
	add_child(page)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 42
	page.add_child(header)
	var title := Label.new()
	title.text = "CHESS IN WAR"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 18)
	header.add_child(turn_label)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	page.add_child(content)

	board = BattleBoard.new()
	board.custom_minimum_size = Vector2(620, 620)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(board)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = 350
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(sidebar)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	sidebar.add_child(panel)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 30)
	result_label.custom_minimum_size.y = 34
	panel.add_child(result_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 38
	status_label.add_theme_color_override("font_color", Color("#d7c47c"))
	panel.add_child(status_label)
	panel.add_child(HSeparator.new())

	unit_name_label = Label.new()
	unit_name_label.text = "No unit selected"
	unit_name_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(unit_name_label)
	unit_stats_label = RichTextLabel.new()
	unit_stats_label.custom_minimum_size.y = 126
	unit_stats_label.fit_content = false
	unit_stats_label.scroll_active = false
	unit_stats_label.add_theme_font_size_override("normal_font_size", 14)
	panel.add_child(unit_stats_label)
	terrain_label = Label.new()
	terrain_label.add_theme_color_override("font_color", Color("#9eb6b0"))
	panel.add_child(terrain_label)
	panel.add_child(HSeparator.new())
	var log_title := Label.new()
	log_title.text = "BATTLE LOG"
	log_title.add_theme_font_size_override("font_size", 12)
	log_title.add_theme_color_override("font_color", Color("#9eb6b0"))
	panel.add_child(log_title)
	battle_log_label = RichTextLabel.new()
	battle_log_label.custom_minimum_size.y = 100
	battle_log_label.fit_content = false
	battle_log_label.scroll_active = false
	battle_log_label.add_theme_font_size_override("normal_font_size", 11)
	battle_log_label.add_theme_color_override("default_color", Color("#bec8c7"))
	panel.add_child(battle_log_label)
	panel.add_spacer(false)

	attack_button = Button.new()
	attack_button.text = "Attack"
	attack_button.custom_minimum_size.y = 38
	attack_button.pressed.connect(func() -> void: controller.request_attack())
	panel.add_child(attack_button)
	wait_button = Button.new()
	wait_button.text = "Wait"
	wait_button.custom_minimum_size.y = 38
	wait_button.pressed.connect(func() -> void: controller.wait_selected())
	panel.add_child(wait_button)
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.custom_minimum_size.y = 38
	end_turn_button.pressed.connect(func() -> void: controller.end_player_turn())
	panel.add_child(end_turn_button)
	var restart_button := Button.new()
	restart_button.text = "Restart Battle"
	restart_button.custom_minimum_size.y = 38
	restart_button.pressed.connect(func() -> void: controller.start_new_battle())
	panel.add_child(restart_button)


func _refresh() -> void:
	if controller == null or not controller.initialized:
		return
	turn_label.text = "ROUND %02d  |  %s" % [controller.round_number, controller.current_team.to_upper()]
	status_label.text = controller.last_message
	result_label.text = controller.result.to_upper()
	result_label.visible = not controller.result.is_empty()
	battle_log_label.text = "\n".join(controller.battle_log)
	var unit := controller.selected_unit()
	if controller.grid.in_bounds(hovered_pos):
		_show_hovered_cell(hovered_pos)
	else:
		_show_unit_or_summary(unit)
	var can_act := unit != null and not unit.has_acted and controller.current_team == "player" and controller.result.is_empty()
	attack_button.disabled = not can_act
	wait_button.disabled = not can_act
	end_turn_button.disabled = controller.current_team != "player" or not controller.result.is_empty()
	board.queue_redraw()


func _show_unit_or_summary(unit: BattleUnit) -> void:
	if unit == null:
		unit_name_label.text = "No unit selected"
		unit_stats_label.text = "PLAYER  %d alive\nENEMY   %d alive" % [controller.registry.living("player").size(), controller.registry.living("enemy").size()]
		terrain_label.text = ""
	else:
		unit_name_label.text = unit.display_name
		unit_stats_label.text = "Type       %s\nHP         %d / %d\nShield     %d\nAttack     %d\nMove       %d\nRange      %d\nPosition   (%d, %d)" % [unit.unit_type.capitalize(), unit.current_hp, unit.max_hp, unit.current_shield, unit.attack, unit.move_range, unit.attack_range, unit.grid_pos.x, unit.grid_pos.y]
		var terrain := controller.grid.get_terrain(unit.grid_pos)
		terrain_label.text = "%s  |  Height %d" % [terrain.name, int(terrain.height)]


func _show_hovered_cell(pos: Vector2i) -> void:
	var terrain := controller.grid.get_terrain(pos)
	var unit := controller.registry.get_at(pos)
	var passability := "Passable" if terrain.get("passable", false) else "Blocked"
	if unit == null:
		unit_name_label.text = "Cell (%d, %d)" % [pos.x, pos.y]
		unit_stats_label.text = "Terrain    %s\nHeight     %d\nMove cost  %s\nState      %s" % [terrain.name, int(terrain.height), str(int(terrain.move_cost)) if terrain.get("passable", false) else "-", passability]
	else:
		unit_name_label.text = unit.display_name
		unit_stats_label.text = "Team       %s\nType       %s\nHP         %d / %d\nShield     %d\nAttack     %d\nMove       %d\nRange      %d\nPosition   (%d, %d)" % [unit.team.capitalize(), unit.unit_type.capitalize(), unit.current_hp, unit.max_hp, unit.current_shield, unit.attack, unit.move_range, unit.attack_range, unit.grid_pos.x, unit.grid_pos.y]
	var details := "%s  |  Height %d" % [terrain.name, int(terrain.height)]
	if controller.movement_data.get("costs", {}).has(pos) and pos != controller.selected_unit().grid_pos:
		details += "  |  Path cost %d" % int(controller.movement_data.costs[pos])
	terrain_label.text = details


func _on_hovered_cell_changed(pos: Vector2i) -> void:
	hovered_pos = pos
	_refresh()


func _build_theme() -> void:
	var app_theme := Theme.new()
	app_theme.default_font_size = 15
	app_theme.set_color("font_color", "Label", Color("#edf0ec"))
	app_theme.set_color("font_color", "Button", Color("#edf0ec"))
	app_theme.set_color("font_hover_color", "Button", Color.WHITE)
	app_theme.set_constant("outline_size", "Label", 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#1d2428")
	panel_style.border_color = Color("#3c484c")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	app_theme.set_stylebox("panel", "PanelContainer", panel_style)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("#2d383c")
		if state == "hover":
			button_style.bg_color = Color("#3c5556")
		elif state == "pressed":
			button_style.bg_color = Color("#1f696c")
		elif state == "disabled":
			button_style.bg_color = Color("#242a2d")
		button_style.border_color = Color("#536164")
		button_style.set_border_width_all(1)
		button_style.set_corner_radius_all(4)
		app_theme.set_stylebox(state, "Button", button_style)
	theme = app_theme
