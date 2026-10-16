extends SceneTree
const Generator = preload("res://scripts/NamedTerrain.gd")

func _initialize() -> void:
	assert(Generator.clean_location_name("艾兰岛大陆") == "艾兰岛")
	assert(Generator.clean_location_name("大陆架") == "大陆架")
	assert(Generator.clean_location_name("大陆之心大陆") == "大陆之心")
	assert(Generator.clean_location_name("神赐山脉") == "神赐山脉")
	assert(Generator.terrain_type("北冥") == "ice")
	assert(Generator.terrain_type("神赐山脉") == "mountain")
	assert(Generator.terrain_type("未知区域") == "plains")
	var mask := PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.8, 0.2), Vector2(0.8, 0.8), Vector2(0.2, 0.8)])
	var first := Generator.generate("北冥大陆", 42, 64, mask)
	var repeat := Generator.generate("北冥", 42, 64, mask)
	assert(first.get_data() == repeat.get_data())
	assert(first.get_pixel(0, 0).a == 0.0)
	assert(first.get_pixel(32, 32).a == 1.0)
	assert(first.get_data() != Generator.generate("北冥", 43, 64, mask).get_data())
	assert(first.get_data() != Generator.generate("神赐山脉", 42, 64, mask).get_data())
	call_deferred("test_ui")

func test_ui() -> void:
	var panel: Control = load("res://scenes/ui/named_terrain.tscn").instantiate()
	root.add_child(panel)
	await process_frame
	assert(panel.preview.texture != null)
	panel.select_region(1)
	assert(panel.labels[1].text == "艾兰岛")
	panel.name_input.text = "新雪原大陆"
	panel.regenerate()
	assert(panel.labels[1].text == "新雪原")
	assert(panel.regions[1].terrain == "ice")
	panel.queue_free()
	print("PASS named terrain: suffix, semantics, determinism, mask, seed and UI labels")
	quit()
