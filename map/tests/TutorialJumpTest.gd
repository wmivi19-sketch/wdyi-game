extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("_run")
	create_timer(15.0).timeout.connect(func(): quit(1))

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func space(physical_only: bool = false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_SPACE
	if not physical_only:
		event.keycode = KEY_SPACE
	Input.parse_input_event(event)

func _run() -> void:
	change_scene_to_file(root.get_node("GameSession").TUTORIAL_SCENE)
	for frame in range(15):
		await process_frame
	var game = current_scene
	var player = game.player
	player.set_physics_process(false)
	var ground: Vector2 = player.position
	space()
	await process_frame
	check(player.jumping, "Space starts tutorial jump")
	player._physics_process(player.JUMP_DURATION / 2.0)
	check(is_equal_approx(player.jump_height, player.JUMP_HEIGHT), "Jump reaches peak")
	game._process(0.0)
	check(is_equal_approx(game.avatar.elevation,
		player.JUMP_HEIGHT), "Visible avatar combines stair and jump height")
	check(player.position == ground, "Jump preserves ground collision position")
	space()
	await process_frame
	check(player.jump_elapsed > 0.0, "Repeated press cannot reset airborne jump")
	player._physics_process(player.JUMP_DURATION)
	check(not player.jumping and player.jump_height == 0.0, "Jump lands")
	space(true)
	await process_frame
	check(player.jumping, "Physical space starts tutorial jump")
	game.load_level(1, [32, 28])
	check(not player.jumping and player.jump_height == 0.0, "Floor transition resets jump")
	if failures == 0:
		print("PASS tutorial space input, arc, collision anchor, repeat prevention and floor transition")
	quit(0 if failures == 0 else 1)
