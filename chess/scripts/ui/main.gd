extends Control

const MENU_RESTART := 0
const MENU_LEVELS := 1
const MENU_ENCYCLOPEDIA := 2
const UNIT_TYPE_TEXT := {"melee": "近战", "ranged": "远程"}
const CLASS_TEXT := {"soldier": "战士", "archer": "弓手", "raider": "掠夺者"}
const ATTRIBUTE_TEXT := {"none": "无", "wood": "木", "fire": "火", "earth": "土"}
const TEAM_TEXT := {"player": "玩家", "enemy": "敌方"}
const RANK_TEXT := {"normal": "普通", "elite": "精英"}
const TERRAIN_TEXT := {"plain": "平地", "forest": "森林", "hill": "丘陵", "swamp": "沼泽", "water": "水域", "mountain": "山地"}
const RESULT_TEXT := {"victory": "胜利", "defeat": "失败"}

var controller: BattleController
var board: BattleBoard
var turn_label: Label
var level_select_view: Control
var level_scroll: ScrollContainer
var battle_view: Control
var encyclopedia_view: Control
var encyclopedia_tabs: TabContainer
var encyclopedia_entry_counts := {"player": 0, "enemy": 0}
var status_label: Label
var unit_name_label: Label
var unit_stats_label: RichTextLabel
var terrain_label: Label
var battle_log_label: RichTextLabel
var result_label: Label
var move_button: Button
var attack_button: Button
var wait_button: Button
var end_turn_button: Button
var menu_button: MenuButton
var hovered_pos := Vector2i(-1, -1)


func _ready() -> void:
	_build_theme()
	controller = BattleController.new()
	controller.state_changed.connect(_refresh)
	add_child(controller)
	_build_interface()
	board.set_controller(controller)
	board.hovered_cell_changed.connect(_on_hovered_cell_changed)
	show_level_select()


func _unhandled_key_input(event: InputEvent) -> void:
	if not battle_view.visible or not controller.initialized:
		return
	if event.is_action_pressed("ui_cancel"):
		controller.cancel_current_action()
	elif event.is_action_pressed("ui_accept"):
		controller.wait_selected()


func start_level(chapter_id: String) -> bool:
	if not controller.start_new_battle(chapter_id):
		return false
	hovered_pos = Vector2i(-1, -1)
	level_select_view.visible = false
	encyclopedia_view.visible = false
	battle_view.visible = true
	_refresh()
	return true


func show_level_select() -> void:
	controller.stop_battle()
	hovered_pos = Vector2i(-1, -1)
	battle_view.visible = false
	encyclopedia_view.visible = false
	level_select_view.visible = true
	turn_label.text = "SELECT LEVEL"


func _build_interface() -> void:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 18
	page.offset_top = 18
	page.offset_right = -18
	page.offset_bottom = -18
	page.grow_horizontal = Control.GROW_DIRECTION_END
	page.grow_vertical = Control.GROW_DIRECTION_END
	page.add_theme_constant_override("separation", 12)
	add_child(page)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 42
	page.add_child(header)
	var title := Label.new()
	title.name = "GameTitle"
	title.text = "CHESS IN WAR"
	title.add_theme_font_size_override("font_size", 24)
	title.custom_minimum_size.x = 220
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(title)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 18)
	turn_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(turn_label)

	var content_root := Control.new()
	content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(content_root)
	_build_level_select(content_root)
	_build_battle_view(content_root)
	_build_encyclopedia_view(content_root)


func _build_level_select(parent: Control) -> void:
	level_select_view = VBoxContainer.new()
	level_select_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_select_view.add_theme_constant_override("separation", 10)
	parent.add_child(level_select_view)

	var heading := Label.new()
	heading.text = "Choose a battlefield"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	level_select_view.add_child(heading)

	var catalog := GameDataLoader.load_chapter_catalog()
	var catalog_errors := GameDataValidator.validate_catalog(catalog)
	if not catalog_errors.is_empty():
		var error_label := Label.new()
		error_label.text = "Chapter catalog unavailable"
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_select_view.add_child(error_label)
		return

	level_scroll = ScrollContainer.new()
	level_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	level_select_view.add_child(level_scroll)
	var stage_grid := GridContainer.new()
	stage_grid.columns = 2
	stage_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_grid.add_theme_constant_override("h_separation", 18)
	stage_grid.add_theme_constant_override("v_separation", 10)
	level_scroll.add_child(stage_grid)
	for entry in catalog.chapters:
		stage_grid.add_child(_build_level_card(entry))


func _build_level_card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(500, 236)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	card.add_child(body)

	var index_label := Label.new()
	index_label.text = "STAGE %02d" % int(str(entry.id).get_slice("_", 1))
	index_label.add_theme_font_size_override("font_size", 12)
	index_label.add_theme_color_override("font_color", Color("#83dff2"))
	body.add_child(index_label)
	var name_label := Label.new()
	name_label.text = str(entry.name)
	name_label.add_theme_font_size_override("font_size", 22)
	body.add_child(name_label)
	var difficulty_label := Label.new()
	difficulty_label.text = "%s  |  %dx%d" % [entry.difficulty, int(entry.map_size[0]), int(entry.map_size[1])]
	difficulty_label.add_theme_color_override("font_color", Color("#d7c47c"))
	body.add_child(difficulty_label)
	body.add_child(HSeparator.new())
	var forces := Label.new()
	forces.text = "Forces        %d vs %d\nTerrain       %s" % [int(entry.player_count), int(entry.enemy_count), ", ".join(entry.terrains)]
	forces.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	forces.custom_minimum_size.y = 40
	body.add_child(forces)
	var summary := Label.new()
	summary.text = str(entry.summary)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.add_theme_color_override("font_color", Color("#bec8c7"))
	body.add_child(summary)
	var select_button := Button.new()
	select_button.text = "Deploy"
	select_button.custom_minimum_size.y = 36
	select_button.pressed.connect(func() -> void: start_level(str(entry.id)))
	body.add_child(select_button)
	return card


func _build_battle_view(parent: Control) -> void:
	battle_view = HBoxContainer.new()
	battle_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_view.add_theme_constant_override("separation", 16)
	parent.add_child(battle_view)

	board = BattleBoard.new()
	board.custom_minimum_size = Vector2(620, 620)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_view.add_child(board)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = 350
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_view.add_child(sidebar)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	sidebar.add_child(panel)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 28)
	result_label.custom_minimum_size.y = 32
	panel.add_child(result_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 38
	status_label.add_theme_color_override("font_color", Color("#d7c47c"))
	panel.add_child(status_label)
	panel.add_child(HSeparator.new())

	unit_name_label = Label.new()
	unit_name_label.text = "未选择单位"
	unit_name_label.add_theme_font_size_override("font_size", 21)
	panel.add_child(unit_name_label)
	unit_stats_label = RichTextLabel.new()
	unit_stats_label.custom_minimum_size.y = 138
	unit_stats_label.fit_content = false
	unit_stats_label.scroll_active = false
	unit_stats_label.add_theme_font_size_override("normal_font_size", 14)
	panel.add_child(unit_stats_label)
	terrain_label = Label.new()
	terrain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terrain_label.custom_minimum_size.y = 38
	terrain_label.add_theme_color_override("font_color", Color("#9eb6b0"))
	panel.add_child(terrain_label)
	panel.add_child(HSeparator.new())

	var log_title := Label.new()
	log_title.text = "战斗日志"
	log_title.add_theme_font_size_override("font_size", 12)
	log_title.add_theme_color_override("font_color", Color("#9eb6b0"))
	panel.add_child(log_title)
	battle_log_label = RichTextLabel.new()
	battle_log_label.custom_minimum_size.y = 82
	battle_log_label.fit_content = false
	battle_log_label.scroll_active = false
	battle_log_label.add_theme_font_size_override("normal_font_size", 11)
	battle_log_label.add_theme_color_override("default_color", Color("#bec8c7"))
	panel.add_child(battle_log_label)
	panel.add_spacer(false)

	var command_grid := GridContainer.new()
	command_grid.columns = 2
	command_grid.add_theme_constant_override("h_separation", 6)
	command_grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(command_grid)
	move_button = _command_button("Move", func() -> void: controller.request_move())
	command_grid.add_child(move_button)
	attack_button = _command_button("Attack", func() -> void: controller.request_attack())
	command_grid.add_child(attack_button)
	wait_button = _command_button("Wait", func() -> void: controller.wait_selected())
	command_grid.add_child(wait_button)
	end_turn_button = _command_button("End Turn", func() -> void: controller.end_player_turn())
	command_grid.add_child(end_turn_button)
	menu_button = MenuButton.new()
	menu_button.text = "Menu"
	menu_button.custom_minimum_size = Vector2(150, 38)
	menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_grid.add_child(menu_button)
	var popup := menu_button.get_popup()
	popup.min_size = Vector2i(160, 0)
	popup.add_item("Restart", MENU_RESTART)
	popup.add_item("Levels", MENU_LEVELS)
	popup.add_separator()
	popup.add_item("Encyclopedia", MENU_ENCYCLOPEDIA)
	popup.id_pressed.connect(_on_menu_item_pressed)
	popup.about_to_popup.connect(_on_menu_opened)
	popup.popup_hide.connect(_on_menu_closed)


func _build_encyclopedia_view(parent: Control) -> void:
	encyclopedia_view = VBoxContainer.new()
	encyclopedia_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encyclopedia_view.add_theme_constant_override("separation", 10)
	parent.add_child(encyclopedia_view)

	var encyclopedia_header := HBoxContainer.new()
	encyclopedia_view.add_child(encyclopedia_header)
	var heading := Label.new()
	heading.text = "Unit Encyclopedia"
	heading.add_theme_font_size_override("font_size", 26)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encyclopedia_header.add_child(heading)
	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(110, 38)
	back_button.pressed.connect(close_encyclopedia)
	encyclopedia_header.add_child(back_button)

	var data := GameDataLoader.load_game_data("stage_001")
	var abilities_by_id := {}
	for ability in data.get("abilities", {}).get("abilities", []):
		abilities_by_id[str(ability.id)] = ability
	encyclopedia_tabs = TabContainer.new()
	encyclopedia_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	encyclopedia_view.add_child(encyclopedia_tabs)
	_add_encyclopedia_tab(encyclopedia_tabs, "Allies", "player", data.get("players", {}).get("units", []), abilities_by_id)
	_add_encyclopedia_tab(encyclopedia_tabs, "Enemies", "enemy", data.get("enemies", {}).get("units", []), abilities_by_id)


func _add_encyclopedia_tab(tabs: TabContainer, tab_name: String, team: String, definitions: Array, abilities_by_id: Dictionary) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var grid_container := GridContainer.new()
	grid_container.columns = 2
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.add_theme_constant_override("h_separation", 12)
	grid_container.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid_container)
	var unique_definitions := UnitDefinitionCatalog.unique_by_name(definitions)
	encyclopedia_entry_counts[team] = unique_definitions.size()
	for definition in unique_definitions:
		grid_container.add_child(_build_encyclopedia_card(definition, abilities_by_id))


func _build_encyclopedia_card(definition: Dictionary, abilities_by_id: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(500, 210)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var portrait := Label.new()
	portrait.text = UnitIconFormatter.initials(str(definition.name))
	portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.custom_minimum_size = Vector2(62, 62)
	portrait.add_theme_font_size_override("font_size", 18 if portrait.text.length() > 1 else 22)
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color("#247ba0") if str(definition.team) == "player" else Color("#c94c4c")
	portrait_style.border_color = Color("#68d5ef")
	portrait_style.set_border_width_all(3)
	portrait_style.set_corner_radius_all(31)
	portrait.add_theme_stylebox_override("normal", portrait_style)
	row.add_child(portrait)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	row.add_child(details)
	var name_label := Label.new()
	name_label.text = UnitNameLocalizer.localized(str(definition.name))
	name_label.add_theme_font_size_override("font_size", 20)
	details.add_child(name_label)
	var type_label := Label.new()
	var type_parts := [_translated_value(UNIT_TYPE_TEXT, str(definition.unit_type)), _translated_value(CLASS_TEXT, str(definition.class_id))]
	if str(definition.team) == "enemy":
		type_parts.append("级别 %s" % _translated_value(RANK_TEXT, str(definition.get("rank", ""))))
	type_label.text = "  |  ".join(type_parts)
	type_label.add_theme_color_override("font_color", Color("#9eb6b0"))
	details.add_child(type_label)
	var stats := Label.new()
	stats.text = "生命 %d   护盾 %d   攻击 %d\n移动 %d   射程 %d   真实伤害 %s" % [int(definition.max_hp), int(definition.shield), int(definition.attack), int(definition.move_range), int(definition.attack_range), "是" if bool(definition.true_damage) else "否"]
	details.add_child(stats)
	var attribute := str(definition.get("special_attribute", "none"))
	var ability_id := str(definition.get("ability_id", ""))
	var ability: Dictionary = abilities_by_id.get(ability_id, {})
	var special := Label.new()
	special.text = "特殊属性  %s\n能力  %s" % [_translated_value(ATTRIBUTE_TEXT, attribute), "无" if ability.is_empty() else str(ability.name)]
	special.add_theme_color_override("font_color", Color("#d7c47c"))
	details.add_child(special)
	if not ability.is_empty():
		var description := Label.new()
		description.text = str(ability.description)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color", Color("#bec8c7"))
		details.add_child(description)
	return card


func _translated_value(values: Dictionary, value: String) -> String:
	return str(values.get(value, value))


func _command_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 38
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _on_menu_item_pressed(id: int) -> void:
	if id == MENU_RESTART:
		start_level(controller.current_chapter_id)
	elif id == MENU_LEVELS:
		show_level_select()
	elif id == MENU_ENCYCLOPEDIA:
		show_encyclopedia()


func show_encyclopedia() -> void:
	if not controller.initialized:
		return
	battle_view.visible = false
	level_select_view.visible = false
	encyclopedia_view.visible = true
	turn_label.text = "ENCYCLOPEDIA"


func close_encyclopedia() -> void:
	encyclopedia_view.visible = false
	battle_view.visible = true
	_refresh()


func _on_menu_opened() -> void:
	menu_button.text = ""
	controller.set_menu_open(true)


func _on_menu_closed() -> void:
	menu_button.text = "Menu"
	controller.set_menu_open(false)


func _refresh() -> void:
	if controller == null or not controller.initialized or not battle_view.visible:
		return
	turn_label.text = "%s  |  ROUND %02d  |  %s" % [controller.current_chapter_name.to_upper(), controller.round_number, controller.current_team.to_upper()]
	status_label.text = controller.last_message
	result_label.text = _translated_value(RESULT_TEXT, controller.result)
	result_label.visible = not controller.result.is_empty()
	battle_log_label.text = "\n".join(controller.battle_log)
	var unit := controller.selected_unit()
	if controller.grid.in_bounds(hovered_pos):
		_show_hovered_cell(hovered_pos)
	else:
		_show_unit_or_summary(unit)
	var can_act := unit != null and not unit.has_acted and controller.current_team == "player" and controller.result.is_empty() and not controller.menu_open
	move_button.disabled = not can_act or unit.remaining_move_points <= 0
	attack_button.disabled = not can_act
	wait_button.disabled = not can_act
	end_turn_button.disabled = controller.current_team != "player" or not controller.result.is_empty() or controller.menu_open
	board.queue_redraw()


func _show_unit_or_summary(unit: BattleUnit) -> void:
	if unit == null:
		unit_name_label.text = "未选择单位"
		unit_stats_label.text = "玩家存活  %d\n敌方存活  %d" % [controller.registry.living("player").size(), controller.registry.living("enemy").size()]
		terrain_label.text = ""
	else:
		unit_name_label.text = UnitNameLocalizer.localized(unit.display_name)
		var attribute_text := _translated_value(ATTRIBUTE_TEXT, unit.special_attribute)
		var ability_text := "无" if unit.ability_name.is_empty() else unit.ability_name
		var rank_line := "\n级别      %s" % _translated_value(RANK_TEXT, unit.rank) if unit.team == "enemy" else ""
		unit_stats_label.text = "类型  %-8s  HP      %d / %d\n护盾  %-8d  攻击    %d\n移动  %d / %-5d  已消耗  %d\n射程  %-8d  坐标    (%d, %d)\n特殊属性  %s\n能力      %s%s" % [_translated_value(UNIT_TYPE_TEXT, unit.unit_type), unit.current_hp, unit.max_hp, unit.current_shield, unit.attack, unit.remaining_move_points, unit.move_range, unit.move_spent_this_turn, unit.attack_range, unit.grid_pos.x, unit.grid_pos.y, attribute_text, ability_text, rank_line]
		var terrain := controller.grid.get_terrain(unit.grid_pos)
		terrain_label.text = "%s  |  高度 %d" % [_terrain_name(terrain), int(terrain.height)]


func _show_hovered_cell(pos: Vector2i) -> void:
	var terrain := controller.grid.get_terrain(pos)
	var unit := controller.registry.get_at(pos)
	var passability := "可通行" if terrain.get("passable", false) else "不可通行"
	var move_text := "-"
	if terrain.get("passable", false):
		move_text = "全部剩余（至少2）" if str(terrain.get("move_rule", "normal")) == "consume_all" else str(int(terrain.move_cost))
	if unit == null:
		unit_name_label.text = "格子 (%d, %d)" % [pos.x, pos.y]
		unit_stats_label.text = "地形      %s\n高度      %d\n移动消耗  %s\n状态      %s" % [_terrain_name(terrain), int(terrain.height), move_text, passability]
	else:
		unit_name_label.text = UnitNameLocalizer.localized(unit.display_name)
		var rank_line := "\n级别  %s" % _translated_value(RANK_TEXT, unit.rank) if unit.team == "enemy" else ""
		unit_stats_label.text = "阵营  %s%s\n类型  %s\nHP    %d / %d\n护盾  %d\n攻击  %d\n移动  %d / %d\n射程  %d\n坐标  (%d, %d)" % [_translated_value(TEAM_TEXT, unit.team), rank_line, _translated_value(UNIT_TYPE_TEXT, unit.unit_type), unit.current_hp, unit.max_hp, unit.current_shield, unit.attack, unit.remaining_move_points, unit.move_range, unit.attack_range, unit.grid_pos.x, unit.grid_pos.y]
	var details := "%s  |  高度 %d" % [_terrain_name(terrain), int(terrain.height)]
	var selected := controller.selected_unit()
	if selected != null and controller.movement_data.get("costs", {}).has(pos) and pos != selected.grid_pos:
		var path_cost := int(controller.movement_data.costs[pos])
		details += "  |  路径消耗 %d  |  剩余 %d" % [path_cost, maxi(selected.remaining_move_points - path_cost, 0)]
	terrain_label.text = details


func _terrain_name(terrain: Dictionary) -> String:
	return _translated_value(TERRAIN_TEXT, str(terrain.get("id", terrain.get("name", ""))))


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
