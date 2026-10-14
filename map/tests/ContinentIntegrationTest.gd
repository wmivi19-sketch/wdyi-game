extends Node
const Loader = preload("res://scripts/MapLoader.gd")

func _ready() -> void:
	var loader := Loader.new()
	add_child(loader)
	var old_layer: TileMapLayer
	for id in range(6):
		old_layer = loader.terrain_layer
		GameManager.switch_to_continent(id)
		await get_tree().process_frame
		await get_tree().process_frame
		assert(GameManager.current_continent_id == id)
		assert(loader.current_data.id == "continent_%d" % id)
		assert(loader.terrain_layer.get_used_cells().size() == 2500)
		assert(loader.resource_points.get_child_count() == 3)
		if is_instance_valid(old_layer):
			assert(old_layer.get_used_cells().is_empty())
		assert(loader.get_child_count() == 1)
		var source := FileAccess.open("res://data/maps/continent_%d.json" % id, FileAccess.READ)
		var data: Dictionary = JSON.parse_string(source.get_as_text())
		var atlas := loader.terrain_layer.tile_set.get_source(0) as TileSetAtlasSource
		for cell in data.collision_points:
			var coord := Vector2i(int(cell[0]), int(cell[1]))
			var tile := atlas.get_tile_data(loader.terrain_layer.get_cell_atlas_coords(coord), 0)
			assert(tile.get_collision_polygons_count(0) == 1)
		print("PASS continent_", id)
	GameManager.current_day = 1
	GameManager.current_period = GameManager.Period.MORNING
	var events: Array = []
	GameManager.time_updated.connect(func(day: int, period: int): events.append([day, period]))
	for i in range(3):
		GameManager.next_time_period()
	assert(events == [[1, 1], [1, 2], [2, 0]])
	assert(GameManager.current_day == 2)
	assert(GameManager.current_period == GameManager.Period.MORNING)
	print("PASS time progression; all integration checks passed")
	get_tree().quit()