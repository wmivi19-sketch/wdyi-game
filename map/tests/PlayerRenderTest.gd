extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var demo = load("res://scenes/MapDemo.tscn").instantiate()
	root.add_child(demo)
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var player = demo.player
	var screen: Vector2 = player.get_global_transform_with_canvas().origin
	var pixel := image.get_pixel(int(screen.x), int(screen.y))
	image.save_png("res://.validation/player-visible.png")
	assert(player.get_node("BaseBody").texture.resource_path.ends_with("warrior.png"), "Player must use imported warrior")
	print("PASS rendered player visible at ", screen)
	quit()
