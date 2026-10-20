extends SceneTree

func _initialize() -> void:
	call_deferred("_run")
	create_timer(15.0).timeout.connect(func(): quit(1))

func press_space(physical_only: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	if not physical_only:
		event.keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)

func _run() -> void:
	var world = load("res://scenes/MapDemo.tscn").instantiate()
	root.add_child(world)
	for frame in range(15):
		await process_frame
	var player = world.player
	var button := Button.new()
	button.text = "Focused control"
	world.character_info_ui.add_child(button)
	button.grab_focus()
	var period: int = root.get_node("GameManager").current_period
	press_space()
	await process_frame
	if not player.jumping:
		push_error("FAIL: space must jump while an unrelated button has focus")
		quit(1)
		return
	await create_timer(0.15).timeout
	assert(player.get_node("BaseBody").position.y < -5.0, "Actual physics raises sprite")
	assert(root.get_node("GameManager").current_period == period)
	player._reset_jump()
	press_space(true)
	await process_frame
	assert(player.jumping, "Physical space key also jumps")
	player._reset_jump()
	world.character_info_ui.character_info_panel.show()
	press_space()
	await process_frame
	assert(not player.jumping, "Panel blocks gameplay jump")
	world.queue_free()
	await process_frame
	print("PASS actual space input with GUI focus, physical key, visible arc and panel blocking")
	quit(0)
