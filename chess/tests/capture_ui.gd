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
	if not _save("res://docs/v0.1.5_level_select_top.png"):
		quit(1)
		return
	main_scene.level_scroll.scroll_vertical = 100000
	await process_frame
	await process_frame
	if not _save("res://docs/v0.1.5_level_select_bottom.png"):
		quit(1)
		return

	main_scene.start_level("stage_005")
	main_scene.controller.select_at(Vector2i(1, 9))
	main_scene.board._set_hovered_pos(Vector2i(-1, -1))
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	if not _save("res://docs/v0.1.5_stage_005.png"):
		quit(1)
		return

	main_scene.start_level("stage_006")
	main_scene.controller.select_at(Vector2i(6, 11))
	main_scene.board._set_hovered_pos(Vector2i(12, 1))
	await process_frame
	await process_frame
	await process_frame
	if not _save("res://docs/v0.1.5_stage_006.png"):
		quit(1)
		return

	main_scene.show_encyclopedia()
	await process_frame
	await process_frame
	if not _save("res://docs/v0.1.5_encyclopedia_allies.png"):
		quit(1)
		return
	main_scene.encyclopedia_tabs.current_tab = 1
	await process_frame
	await process_frame
	if not _save("res://docs/v0.1.5_encyclopedia_enemies.png"):
		quit(1)
		return
	main_scene.close_encyclopedia()

	main_scene.start_level("stage_003")
	main_scene.controller.select_at(Vector2i(1, 11))
	main_scene.controller.click_at(Vector2i(2, 10))
	main_scene.board._set_hovered_pos(Vector2i(2, 10))
	await process_frame
	await process_frame
	await process_frame
	if not _save("res://docs/v0.1.5_opportunity_log.png"):
		quit(1)
		return
	print("UI CAPTURE: six-level select, stages 5/6, expanded encyclopedia, rank, and opportunity log saved")
	quit(0)


func _save(path: String) -> bool:
	var image := root.get_texture().get_image()
	var save_error := image.save_png(path)
	if save_error != OK:
		printerr("UI CAPTURE FAILED: save error %d for %s" % [save_error, path])
		return false
	print("UI CAPTURE: %s %dx%d, non-empty=%s" % [path, image.get_width(), image.get_height(), not image.is_empty()])
	return true
