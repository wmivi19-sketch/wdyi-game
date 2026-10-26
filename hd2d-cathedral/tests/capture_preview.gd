extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for index in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://docs/main_preview.png")
	print("Preview saved: ", result)
	quit(result)
