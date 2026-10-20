extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = load("res://scenes/Player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var body: Sprite2D = player.get_node("BaseBody")
	var origin: Vector2 = player.position
	assert(player.try_jump())
	assert(not player.try_jump(), "No repeated jump while airborne")
	player._update_jump(player.jump_duration / 2.0)
	assert(is_equal_approx(body.position.y, -player.jump_height))
	assert(player.position == origin, "Jump keeps collision body on the ground plane")
	player.update_skin("mage")
	player._update_jump(0.0)
	assert(body.position.y < 0.0, "Skin changes preserve airborne pose")
	player._update_jump(player.jump_duration / 2.0)
	assert(not player.jumping and is_zero_approx(body.position.y))
	assert(body.scale.y < 1.0, "Landing keeps its animation when a tick reaches touchdown")
	player._update_jump(0.2)
	assert(body.scale == Vector2.ONE, "Landing restores normal scale")
	assert(player.try_jump())
	player.teleport_to(Vector2(20, 30))
	assert(not player.jumping and body.position == Vector2.ZERO)
	player.hp = 0.0
	assert(not player.try_jump(), "Dead characters cannot jump")
	player.hp = 100.0
	var ui := Node.new()
	ui.name = "GameUI"
	root.add_child(ui)
	var panel := Control.new()
	panel.name = "PlayerPanel"
	ui.add_child(panel)
	assert(not player.try_jump(), "Open panel blocks jumping")
	panel.hide()
	assert(player.try_jump())
	player.queue_free()
	ui.queue_free()
	await process_frame
	print("PASS jump arc, landing, repeat prevention, skin, teleport, death and UI")
	quit(0)
