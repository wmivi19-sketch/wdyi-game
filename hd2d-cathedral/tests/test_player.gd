extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
func _run() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var player = scene.get_node("TestPlayer")
	await frames(20)
	check(player.is_on_floor(), "Player must stand on floor")
	var start: Vector3 = player.position
	key(KEY_W, true)
	await frames(30)
	key(KEY_W, false)
	check(player.position.z < start.z-1.0, "W must move along the aisle")
	player.input_blocked = true
	start = player.position
	key(KEY_D, true)
	await frames(15)
	key(KEY_D, false)
	check(absf(player.position.x-start.x) < 0.01, "Picker must block movement")
	player.input_blocked = false
	var jump := InputEventAction.new()
	jump.action = "ui_accept"
	jump.pressed = true
	Input.parse_input_event(jump)
	await frames(10)
	jump.pressed = false
	Input.parse_input_event(jump)
	check(player.position.y > 0.4, "Jump must lift the player")
	player.reset_position()
	await frames(3)
	check(absf(player.position.z-11) < 0.01, "Reset restores spawn")
	var shape = player.get_node("CollisionShape3D").shape
	check(player.load_art_file(ProjectSettings.globalize_path("res://assets/building/A05_前景左石柱-v2.png")) == OK, "Runtime PNG loading")
	check(player.get_node("CollisionShape3D").shape == shape, "Art swap must preserve collision")
	check(player.get_node("ArtPivot/Sprite3D").visible, "Swapped art visible")
	player.position = Vector3(0, 0.05, 2.5)
	await frames(10)
	key(KEY_W, true)
	jump.pressed = true
	Input.parse_input_event(jump)
	await frames(45)
	jump.pressed = false
	Input.parse_input_event(jump)
	key(KEY_W, false)
	await frames(70)
	check(player.is_on_floor() and player.position.y > 2.2, "Player can jump onto sanctuary platform")
	player.reset_position()
	await frames(10)
	# A real wall verifies movement stops rather than passing through bodies.
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 4, 6)
	collider.shape = box
	wall.add_child(collider)
	wall.position = Vector3(1.3, 2, 11)
	scene.add_child(wall)
	key(KEY_D, true)
	await frames(60)
	key(KEY_D, false)
	check(player.position.x < 0.9, "Player must not cross wall")
	check(player.position.x > 0.2, "Player reaches wall")
	scene.queue_free()
	await process_frame
	print("PLAYER TESTS: 11 checks, %d failures" % failures)
	quit(1 if failures else 0)
