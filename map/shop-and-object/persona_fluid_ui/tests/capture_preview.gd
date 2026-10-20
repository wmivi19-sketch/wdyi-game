extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1100, 720)
	var demo = load("res://scenes/demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame
	demo.hud.update_vitals(72, 100, 16, 100, 41, 100, true)
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://tests/three-row-preview.png")
	print("Three-row preview saved: ", error_string(result))
	quit(0 if result == OK else 1)
