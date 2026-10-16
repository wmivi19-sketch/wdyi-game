extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var player = load("res://scenes/Player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var manager = player.get_node("AppearanceManager")
	var body: Sprite2D = player.get_node("BaseBody")
	assert(player.z_index > 0, "Player must draw above terrain")
	assert(body.texture.resource_path == "res://assets/characters/player/sprites/warrior.png" and body.visible)
	assert(is_equal_approx(body.scale.x, body.scale.y), "Single image must preserve aspect ratio")
	manager.replace_image("res://assets/characters/player/sprites/missing.png")
	assert(body.texture.get_size() == Vector2(16, 16), "Missing image must use placeholder")
	player.update_skin("default")
	assert(not player.get_node("Outfit").visible)
	for job in ["warrior", "mage", "ranger", "unknown"]:
		player.complete_job_ritual(job)
		assert(body.texture != null and body.visible and body.hframes == 1)
	for direction in ["down", "left", "right", "up"]:
		assert(player.get_node("AnimationPlayer").has_animation("walk_" + direction))
	# A real imported texture exercises replacement and four-row frame playback.
	manager.jobs["test"] = {"BaseBody": {"path": "res://assets/skins/test_sheet.svg", "hframes": 4, "vframes": 4}}
	player.update_skin("test")
	assert(body.hframes == 4 and body.vframes == 4)
	manager.set_motion(Vector2.UP)
	player.get_node("AnimationPlayer").advance(0.13)
	assert(body.frame >= 12 and body.frame <= 15)
	manager.set_motion(Vector2.ZERO)
	assert(body.frame == 12)
	assert(player.get_node("Camera2D").enabled)
	# Actual physics movement into a wall must stop rather than pass through.
	var wall := StaticBody2D.new()
	wall.position = Vector2(40, 0)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 100)
	collision.shape = rectangle
	wall.add_child(collision)
	root.add_child(wall)
	await physics_frame
	for i in range(60):
		player.velocity = Vector2(80, 0)
		player.move_and_slide()
		await physics_frame
	assert(player.position.x > 0 and player.position.x <= 26.1)
	player.update_skin("default")
	assert(body.hframes == 1 and body.texture.resource_path.ends_with("warrior.png"))
	player.queue_free()
	wall.queue_free()
	await process_frame
	print("PASS placeholder, missing skins, replacement, four directions, camera and wall collision")
	quit(0)
