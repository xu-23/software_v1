extends SceneTree


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var load_error := change_scene_to_file("res://scenes/main/Main.tscn")
	if load_error != OK:
		printerr("UI CAPTURE FAILED: cannot load main scene")
		quit(1)
		return
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	await process_frame
	var main_scene := current_scene
	if not _save("res://docs/v0.1.4_level_select.png"):
		quit(1)
		return

	main_scene.start_level("stage_004")
	main_scene.controller.select_at(Vector2i(1, 11))
	main_scene.board._set_hovered_pos(Vector2i(-1, -1))
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	if not _save("res://docs/v0.1.4_stage_004.png"):
		quit(1)
		return

	main_scene.show_encyclopedia()
	await process_frame
	await process_frame
	if not _save("res://docs/v0.1.4_encyclopedia_allies_zh.png"):
		quit(1)
		return
	main_scene.encyclopedia_tabs.current_tab = 1
	await process_frame
	await process_frame
	if not _save("res://docs/v0.1.4_encyclopedia_enemies_zh.png"):
		quit(1)
		return
	main_scene.close_encyclopedia()

	main_scene.start_level("stage_001")
	main_scene.controller.select_at(Vector2i(1, 8))
	main_scene.controller.click_at(Vector2i(1, 7))
	main_scene.controller.registry.get_unit("enemy_001").grid_pos = Vector2i(1, 6)
	main_scene.controller.request_attack()
	main_scene.controller.attack_selected("enemy_001")
	main_scene.board._set_hovered_pos(Vector2i(1, 6))
	await process_frame
	await process_frame
	await process_frame
	if not _save("res://docs/v0.1.4_unit_and_log_zh.png"):
		quit(1)
		return

	main_scene.start_level("stage_002")
	main_scene.board._set_hovered_pos(Vector2i(4, 5))
	await process_frame
	await process_frame
	await process_frame
	if not _save("res://docs/v0.1.4_terrain_zh.png"):
		quit(1)
		return
	print("UI CAPTURE: level select, stage 4, encyclopedia names, Chinese unit/log, and Chinese terrain saved")
	quit(0)


func _save(path: String) -> bool:
	var image := root.get_texture().get_image()
	var save_error := image.save_png(path)
	if save_error != OK:
		printerr("UI CAPTURE FAILED: save error %d for %s" % [save_error, path])
		return false
	print("UI CAPTURE: %s %dx%d, non-empty=%s" % [path, image.get_width(), image.get_height(), not image.is_empty()])
	return true
