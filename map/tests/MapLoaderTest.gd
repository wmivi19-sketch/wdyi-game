extends SceneTree

const Loader = preload("res://scripts/MapLoader.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var loader := Loader.new()
	root.add_child(loader)
	for map_id in ["emerald", "sun_sands", "frost_crown", "ancient_woods", "ember", "convergence"]:
		assert(loader.load_map(map_id), "Map load failed: " + map_id)
		assert(loader.terrain_layer.get_used_cells().size() == 240)
		assert(loader.resource_points.get_child_count() == 3)
		assert(loader.special_locations.get_child_count() == 3)
		for area in loader.special_locations.get_children():
			assert(area is Area2D and area.get_child(0) is CollisionShape2D)
		var tiles := loader.terrain_layer.tile_set
		var atlas := tiles.get_source(0) as TileSetAtlasSource
		for terrain in loader.current_data.terrain_types.values():
			var tile := atlas.get_tile_data(Vector2i(int(terrain.id), 0), 0)
			assert(tile.get_collision_polygons_count(0) == (1 if terrain.solid else 0))
		print("PASS ", map_id)
		await process_frame
	loader.queue_free()
	await process_frame
	print("All six deterministic maps passed.")
	quit(0)
