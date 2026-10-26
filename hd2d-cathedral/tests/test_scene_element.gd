extends SceneTree

var failures: int = 0
var checks: int = 0
const TEMPLATE = preload("res://scenes/scene_element.tscn")

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	# 不对称透明留白可以检出镜像后 pivot 和碰撞偏离的问题。
	var image := Image.create(16, 20, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(2, 3, 8, 12), Color.WHITE)
	var tex := ImageTexture.create_from_image(image)
	var element = TEMPLATE.instantiate()
	element.texture = tex
	element.pixel_size = 0.1
	element.outline_simplification = 0.5
	root.add_child(element)
	await process_frame
	check(element.pivot == 7, "Default pivot must be bottom center")
	check(element._visible_rect == Rect2(2, 3, 8, 12), "Alpha bounds must exclude transparent padding")
	for pivot_index in range(9):
		for mirror in range(4):
			element.pivot = pivot_index
			element.flip_h = bool(mirror & 1)
			element.flip_v = bool(mirror & 2)
			element.size_scale = Vector2(1.7, 0.6)
			await process_frame
			var x_fraction := float(pivot_index % 3) / 2.0
			var y_fraction := floorf(float(pivot_index) / 3.0) / 2.0
			var expected_min := Vector2(-8.0 * x_fraction * 0.17, -12.0 * (1.0 - y_fraction) * 0.06)
			var expected_max := Vector2(8.0 * (1.0 - x_fraction) * 0.17, 12.0 * y_fraction * 0.06)
			var actual_min := Vector2(INF, INF)
			var actual_max := Vector2(-INF, -INF)
			for collider in element.get_node("Body").get_children(true):
				for point in collider.polygon:
					actual_min = actual_min.min(point)
					actual_max = actual_max.max(point)
				check(is_equal_approx(collider.depth, 0.51), "Depth must scale with width")
			check(actual_min.is_equal_approx(expected_min), "Collision minimum incorrect for pivot %s mirror %s" % [pivot_index, mirror])
			check(actual_max.is_equal_approx(expected_max), "Collision maximum incorrect for pivot %s mirror %s" % [pivot_index, mirror])
			# 独立模拟 Sprite3D 贴图中不透明区域的中心，验证图形与物理一致。
			var source_center := Vector2(6, 9)
			if element.flip_h:
				source_center.x = 16 - source_center.x
			if element.flip_v:
				source_center.y = 20 - source_center.y
			var visual: Sprite3D = element.get_node("Visual")
			var center := Vector2(visual.position.x, visual.position.y) + Vector2((source_center.x - 8) * 0.17, (10 - source_center.y) * 0.06)
			check(center.is_equal_approx((actual_min + actual_max) / 2), "Visual/collision must coincide")
	check(element.get_node("Body").scale == Vector3.ONE, "Physics body must not be nonuniformly scaled")
	element.pivot = 7
	element.flip_h = false
	element.flip_v = false
	element.size_scale = Vector2.ONE
	element.pivot_offset_pixels = Vector2(2, 1)
	await process_frame
	check(element.get_pivot_pixels().is_equal_approx(Vector2(8, 16)), "Custom pivot pixel offset")
	element.trim_transparent_border = false
	element.pivot_offset_pixels = Vector2.ZERO
	await process_frame
	check(element.get_pivot_pixels().is_equal_approx(Vector2(8, 20)), "Untrimmed pivot uses full image size")
	element.collision_mode = 2
	await process_frame
	check(element.get_node("Body").get_child_count(true) == 0, "Disabled collision must remove shapes")
	element.collision_mode = 1
	await process_frame
	check(element.get_node("Body").get_child_count(true) == 1, "Bounds collision must make one shape")
	element.texture = null
	await process_frame
	check(not element.get_node("Visual").visible, "Cleared texture must hide visual")
	check(element.get_node("Body").get_child_count(true) == 0, "Cleared texture must remove collisions")
	image.fill(Color.TRANSPARENT)
	element.texture = ImageTexture.create_from_image(image)
	await process_frame
	check(element.get_node("Body").get_child_count(true) == 0, "Transparent image must not collide")
	var second = TEMPLATE.instantiate()
	second.texture = tex
	root.add_child(second)
	await process_frame
	check(second.get_node("Body").get_child_count(true) > 0, "Instances must be independent")
	element.queue_free()
	second.queue_free()
	var main: Node3D = load("res://tests/fixtures/element_physics.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame
	var column = main.get_node("Elements/ExampleColumn")
	check(column.get_node("Body").get_child_count(true) > 0, "Real asset collision generation")
	var ground_query := PhysicsRayQueryParameters3D.create(Vector3(0, 2, 0), Vector3(0, -2, 0))
	var hit := main.get_world_3d().direct_space_state.intersect_ray(ground_query)
	check(not hit.is_empty() and hit.collider == main.get_node("Ground"), "Ground must support 3D physics")
	var column_query := PhysicsRayQueryParameters3D.create(Vector3(-3.35, 3, 3), Vector3(-3.35, 3, -3))
	hit = main.get_world_3d().direct_space_state.intersect_ray(column_query)
	check(not hit.is_empty() and hit.collider == column.get_node("Body"), "Column silhouette must block physics ray")
	check(main.get_node("WorldEnvironment").environment.sky != null, "Sky configured")
	main.queue_free()
	await process_frame
	print("SCENE ELEMENT TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
