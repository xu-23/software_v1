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
	var main_scene := current_scene
	main_scene.controller.select_at(Vector2i(1, 8))
	main_scene.board._set_hovered_pos(Vector2i(1, 6))
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var save_error := image.save_png("res://docs/v0.1.1_ui_smoke.png")
	if save_error != OK:
		printerr("UI CAPTURE FAILED: save error %d" % save_error)
		quit(1)
		return
	print("UI CAPTURE: %dx%d, non-empty=%s" % [image.get_width(), image.get_height(), not image.is_empty()])
	quit(0)
