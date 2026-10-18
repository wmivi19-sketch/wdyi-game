extends Node
var failures: int = 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	GameManager.set_physics_process(false)
	GameManager.start_new_game()
	var observed := {"resource": 0, "health": 0, "death": 0}
	var on_resource := func(id, kind, value, _maximum):
		if id == 0 and kind == &"hp" and value == 0.0:
			observed.resource += 1
			check(not GameManager.get_player(0)["alive"], "resource listener sees committed death")
	var on_health := func(id, value, _maximum):
		if id == 0 and value == 0:
			observed.health += 1
	var on_death := func(id):
		if id == 0:
			observed.death += 1
			check(GameManager.get_player(0)["health"] == 0, "death listener sees zero health")
	GameManager.resource_changed.connect(on_resource)
	GameManager.health_changed.connect(on_health)
	GameManager.player_died.connect(on_death)
	GameManager.damage_player(0, 1000)
	check(observed.resource == 1 and observed.health == 1 and observed.death == 1, "one event of each type per lethal hit")
	GameManager.resource_changed.disconnect(on_resource)
	GameManager.health_changed.disconnect(on_health)
	GameManager.player_died.disconnect(on_death)
	GameManager.start_new_game()
	GameManager.set_profession(0, GameManager.Profession.WARRIOR)
	var actor := GameManager.get_combatant(0)
	var body := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	body.add_child(shape)
	add_child(body)
	GameManager.register_player_body(0, body)
	var wall := StaticBody2D.new()
	wall.position = Vector2(160, 180)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(10, 300)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(body.test_move(body.global_transform, Vector2(100, 0)), "fixture detects wall")
	GameManager.set_move_input(0, Vector2.RIGHT)
	for frame in range(30):
		await get_tree().physics_frame
		GameManager.tick_combat(1.0 / 60.0)
	check(body.position.x > 120.0 and body.position.x <= 137.1, "walking stops at wall")
	check(actor.global_position == body.global_position, "proxy matches collision result")
	check(GameManager.get_player(0)["position"] == body.global_position, "snapshot matches collision result")
	check(GameManager.try_cast_skill(0, &"E"), "dash begins")
	for frame in range(12):
		await get_tree().physics_frame
		GameManager.tick_combat(1.0 / 60.0)
	check(body.position.x <= 137.1, "dash stops at wall")
	GameManager.set_move_input(0, Vector2.DOWN)
	for frame in range(5):
		await get_tree().physics_frame
		GameManager.tick_combat(1.0 / 60.0)
	check(body.position.y > 180.0, "movement along wall remains possible")
	var stun := ARPGStatusEffect.new()
	stun.stun = true
	stun.duration = 1.0
	actor.add_effect(stun)
	var before := body.position
	await get_tree().physics_frame
	GameManager.tick_combat(1.0 / 60.0)
	check(body.position == before and body.velocity == Vector2.ZERO, "stun halts external body")
	GameManager.damage_player(0, 1000)
	body.velocity = Vector2.RIGHT * 100.0
	GameManager.tick_combat(1.0 / 60.0)
	check(body.velocity == Vector2.ZERO, "death clears external velocity")
	GameManager.start_new_game()
	check(body.position == GameManager.get_player(0)["spawn_position"], "restart places registered body")
	for index in range(42):
		GameManager.advance_period()
	check(body.position == GameManager.END_SPAWNS[0], "teleport still bypasses movement deliberately")
	# 已释放实体不能使下一帧访问失效对象，应退回内部实体。
	body.free()
	GameManager.set_move_input(0, Vector2.DOWN)
	await get_tree().physics_frame
	GameManager.tick_combat(1.0 / 60.0)
	check(GameManager.get_combatant(0).global_position.y > GameManager.END_SPAWNS[0].y, "freed body falls back to internal movement")
	wall.free()
	if failures == 0:
		print("PASS: single death notifications, external walking/dash collisions, stun, restart and teleport")
	get_tree().quit(0 if failures == 0 else 1)
