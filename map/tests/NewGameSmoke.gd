extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await create_timer(1.0).timeout
	var menu = current_scene
	print("SMOKE menu button: ", menu.buttons.new_game.get_global_rect(), " disabled=", menu.buttons.new_game.disabled)
	var point: Vector2 = menu.buttons.new_game.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await create_timer(2.0).timeout
	print("SMOKE current scene: ", current_scene.scene_file_path)
	if current_scene.scene_file_path != "res://scenes/MapDemo.tscn":
		quit(1)
		return
	print("SMOKE map: ", current_scene.loader.current_data.get("id"), " player: ", current_scene.player.global_position)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../.validation/new-game-screen.png")
	quit(0)
