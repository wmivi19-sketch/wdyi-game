extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1672, 941)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	await physics_frame
	var camera: Camera3D = scene.get_node("Camera3D")
	# Project canvas_items scaling retains the configured 1920x1080 viewport.
	var viewport_scale := camera.get_viewport().get_visible_rect().size / Vector2(1672, 941)
	var elements := scene.get_node("Elements")
	check(elements.get_node("Pews").get_child_count() == 14, "Seven pew rows on each side")
	check(elements.get_node("Columns").get_child_count() == 6, "Three pillar pairs")
	var count := 0
	for group in elements.get_children():
		for item in group.get_children():
			count += 1
			check(item.texture != null, "Missing texture: " + item.name)
			check(item.get_node("Visual").visible, "Invisible element: " + item.name)
			var expected: Rect2 = item.get_meta("reference_rect")
			var screen_position := camera.unproject_position(item.global_position)
			check(screen_position.distance_to(Vector2(expected.get_center().x, expected.end.y) * viewport_scale) < 1.0,
				"Placement no longer matches reference composition: " + item.name)
			if item.collision_mode != 2:
				check(item.get_node("Body").get_child_count(true) > 0, "Missing collider: " + item.name)
	check(count == 90, "All ninety independent assets present")
	var world := scene.get_world_3d().direct_space_state
	for y in [550.0, 650.0, 750.0, 850.0]:
		var pixel := Vector2(836, y) * viewport_scale
		var origin := camera.project_ray_origin(pixel)
		var hit := world.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(pixel)*150, 1))
		check(not hit.is_empty() and hit.collider == scene.get_node("Ground"), "Central aisle must be clear and have floor collision")
	var platform_hit := world.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(8, 10, -3), Vector3(8, -2, -3)))
	check(not platform_hit.is_empty() and platform_hit.collider == scene.get_node("SanctuaryPlatform"), "Raised sanctuary must have collision")
	check(scene.get_node("WorldEnvironment").environment.sky != null, "Sky environment retained")
	check(scene.get_node("Atmosphere").get_child_count() == 9, "Four light shafts and five window projections")
	scene.queue_free()
	await process_frame
	print("CATHEDRAL TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
