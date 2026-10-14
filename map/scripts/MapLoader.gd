class_name MapLoader
extends Node2D
## Fixed terrain rows and object coordinates are the only map sources.
signal map_loaded(map_id: String)
signal load_failed(message: String)
signal location_entered(location_id: String, kind: String, body: Node2D)
signal location_exited(location_id: String, kind: String, body: Node2D)

const MAP_DIRECTORY := "res://data/maps/"
var terrain_layer: TileMapLayer
var resource_points: Node2D
var special_locations: Node2D
var current_data: Dictionary = {}
var spawn_position := Vector2.ZERO
var _map_root: Node2D

func _ready() -> void:
	GameManager.continent_switched.connect(_on_continent_switched)
	load_map_from_json(GameManager.current_continent_id)

func _on_continent_switched(continent_id: int) -> void:
	call_deferred("load_map_from_json", continent_id)

func load_map_from_json(continent_id: int) -> bool:
	if continent_id < 0 or continent_id > 5:
		return _fail("Continent ID must be in 0..5")
	return load_json(MAP_DIRECTORY + "continent_%d.json" % continent_id)

func _convert_continent(data: Dictionary) -> Dictionary:
	if not data.get("terrain") is Array or data.terrain.is_empty():
		return {}
	var grid: Array = data.terrain
	if not grid[0] is Array or grid[0].is_empty():
		return {}
	var width: int = grid[0].size()
	var height: int = grid.size()
	if width > 256 or height > 256:
		return {}
	if not data.get("collision_points") is Array or not data.get("resource_spots") is Array:
		return {}
	var blocked: Dictionary = {}
	for cell in data.collision_points:
		if not _valid_cell(cell, width, height):
			return {}
		blocked[Vector2i(int(cell[0]), int(cell[1]))] = true
	var symbols := [".", "~", "^"]
	var solid_symbols := ["A", "B", "C"]
	var colors: Variant = data.get("colors", ["639455", "356b99", "91785c"])
	if not colors is Array or colors.size() != 3:
		return {}
	var types: Dictionary = {}
	for i in range(3):
		types[symbols[i]] = {"id": i, "solid": false, "color": colors[i]}
		types[solid_symbols[i]] = {"id": i + 3, "solid": true, "color": colors[i]}
	var rows: Array = []
	for y in range(height):
		if not grid[y] is Array or grid[y].size() != width:
			return {}
		var row := ""
		for x in range(width):
			var value: Variant = grid[y][x]
			if not _integer(value) or value < 0 or value > 2:
				return {}
			row += solid_symbols[int(value)] if blocked.has(Vector2i(x, y)) else symbols[int(value)]
		rows.append(row)
	var resources: Array = []
	for i in range(data.resource_spots.size()):
		var cell: Variant = data.resource_spots[i]
		if not _valid_cell(cell, width, height):
			return {}
		resources.append({"id": "resource_%d" % i, "kind": "herb", "name": "资源", "cell": cell, "amount": 1})
	return {"schema_version": 1, "id": str(data.get("id", "continent")),
		"name": str(data.get("name", "大陆")), "tile_size": data.get("tile_size", 10),
		"width": width, "height": height, "spawn": data.get("spawn", [1, 1]),
		"terrain_types": types, "terrain_rows": rows,
		"resources": resources, "special_locations": []}

func _valid_cell(cell: Variant, width: int, height: int) -> bool:
	return cell is Array and cell.size() == 2 and _integer(cell[0]) and _integer(cell[1]) \
		and cell[0] >= 0 and cell[1] >= 0 and cell[0] < width and cell[1] < height

func load_map(map_id: String) -> bool:
	if map_id.is_empty() or not map_id.is_valid_identifier():
		return _fail("Invalid map identifier: " + map_id)
	return load_json(MAP_DIRECTORY + map_id + ".json")

func load_json(path: String) -> bool:
	if not path.begins_with(MAP_DIRECTORY) or ".." in path or not path.ends_with(".json"):
		return _fail("Map path must be within " + MAP_DIRECTORY)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Cannot open map: " + path)
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _fail("JSON line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
	if not parser.data is Dictionary:
		return _fail("Map root must be an object")
	var data: Dictionary = parser.data
	if data.has("terrain"):
		data = _convert_continent(data)
		if data.is_empty():
			return _fail("Invalid continent terrain or coordinates")
	var error := _validate(data)
	if not error.is_empty():
		return _fail(error)
	# Validate before replacing the active map; failed loads preserve it.
	var next_root := Node2D.new()
	next_root.name = "LoadedMap"
	var next_layer := TileMapLayer.new()
	next_layer.name = "Terrain"
	next_layer.tile_set = _build_tileset(data)
	next_root.add_child(next_layer)
	var rows: Array = data.terrain_rows
	for y in range(int(data.height)):
		for x in range(int(data.width)):
			var terrain: Dictionary = data.terrain_types[rows[y][x]]
			next_layer.set_cell(Vector2i(x, y), 0, Vector2i(int(terrain.id), 0))
	var next_resources := Node2D.new()
	next_resources.name = "ResourcePoints"
	next_root.add_child(next_resources)
	for entry in data.resources:
		_add_marker(next_resources, entry, int(data.tile_size), false)
	var next_locations := Node2D.new()
	next_locations.name = "SpecialLocations"
	next_root.add_child(next_locations)
	for entry in data.special_locations:
		_add_marker(next_locations, entry, int(data.tile_size), true)
	if is_instance_valid(_map_root):
		terrain_layer.clear()
		remove_child(_map_root)
		_map_root.queue_free()
	add_child(next_root)
	_map_root = next_root
	terrain_layer = next_layer
	resource_points = next_resources
	special_locations = next_locations
	current_data = data.duplicate(true)
	spawn_position = _cell_center(data.spawn, int(data.tile_size))
	map_loaded.emit(str(data.id))
	return true

func _validate(data: Dictionary) -> String:
	for key in ["schema_version", "id", "name", "tile_size", "width", "height", "spawn", "terrain_types", "terrain_rows", "resources", "special_locations"]:
		if not data.has(key):
			return "Missing field: " + key
	if data.schema_version != 1 or not data.id is String or not data.name is String:
		return "Invalid schema version or map identity"
	for key in ["tile_size", "width", "height"]:
		if not _integer(data[key]) or data[key] < 1 or data[key] > 256:
			return "Invalid dimension: " + key
	if not data.terrain_types is Dictionary or data.terrain_types.is_empty() or not data.terrain_rows is Array or data.terrain_rows.size() != int(data.height):
		return "Invalid terrain types or row count"
	var ids: Array = []
	for symbol in data.terrain_types:
		var t = data.terrain_types[symbol]
		if symbol.length() != 1 or not t is Dictionary:
			return "Terrain symbols must contain one character"
		if not t.has("id") or not _integer(t.id) or t.id < 0 or t.id > 255 or t.id in ids:
			return "Terrain IDs must be unique integers in 0..255"
		if not t.has("solid") or not t.solid is bool or not t.has("color") or not t.color is String or not Color.html_is_valid(t.color):
			return "Invalid terrain collision or color"
		ids.append(t.id)
	for row in data.terrain_rows:
		if not row is String or row.length() != int(data.width):
			return "Terrain row width mismatch"
		for symbol in row:
			if not data.terrain_types.has(symbol):
				return "Unknown terrain symbol: " + symbol
	if not _walkable(data.spawn, data):
		return "Spawn must be on walkable terrain"
	var object_ids: Array = []
	for field in ["resources", "special_locations"]:
		if not data[field] is Array:
			return "Invalid object list: " + field
		for entry in data[field]:
			if not entry is Dictionary:
				return "Map objects must be dictionaries"
			for key in ["id", "kind", "name", "cell"]:
				if not entry.has(key):
					return "Missing object field: " + key
			if not entry.id is String or entry.id.is_empty() or entry.id in object_ids or not entry.name is String:
				return "Invalid or duplicate object ID"
			object_ids.append(entry.id)
			if not _walkable(entry.cell, data):
				return "Object must be on walkable terrain: " + str(entry.id)
			if field == "resources":
				if entry.kind not in ["ore", "herb", "wood"] or not entry.has("amount") or not _integer(entry.amount) or entry.amount < 1:
					return "Invalid resource kind or amount"
			else:
				if entry.kind not in ["artifact", "altar", "market"] or not entry.has("radius") or not _integer(entry.radius) or entry.radius < 1 or entry.radius > data.tile_size:
					return "Invalid special location kind or radius"
	return ""

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

func _walkable(cell: Variant, data: Dictionary) -> bool:
	if not cell is Array or cell.size() != 2 or not _integer(cell[0]) or not _integer(cell[1]):
		return false
	var x := int(cell[0])
	var y := int(cell[1])
	if x < 0 or y < 0 or x >= int(data.width) or y >= int(data.height):
		return false
	return not data.terrain_types[data.terrain_rows[y][x]].solid

func _build_tileset(data: Dictionary) -> TileSet:
	var size := int(data.tile_size)
	var max_id := 0
	for t in data.terrain_types.values():
		max_id = maxi(max_id, int(t.id))
	var image := Image.create((max_id + 1) * size, size, false, Image.FORMAT_RGBA8)
	for t in data.terrain_types.values():
		var rect := Rect2i(int(t.id) * size, 0, size, size)
		var color := Color.html(t.color)
		image.fill_rect(rect, color.darkened(0.16))
		image.fill_rect(Rect2i(rect.position + Vector2i.ONE, Vector2i(size - 2, size - 2)), color)
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(size, size)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	tiles.set_physics_layer_collision_mask(0, 2)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = Vector2i(size, size)
	tiles.add_source(atlas, 0)
	var half := size * 0.5
	for t in data.terrain_types.values():
		var coord := Vector2i(int(t.id), 0)
		atlas.create_tile(coord)
		if t.solid:
			var tile := atlas.get_tile_data(coord, 0)
			tile.set_collision_polygons_count(0, 1)
			tile.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
	return tiles

func _cell_center(cell: Array, size: int) -> Vector2:
	return (Vector2(float(cell[0]), float(cell[1])) + Vector2(0.5, 0.5)) * size

func _add_marker(parent: Node2D, entry: Dictionary, size: int, special: bool) -> void:
	var area := Area2D.new()
	area.name = str(entry.id)
	area.position = _cell_center(entry.cell, size)
	area.collision_layer = 4 if special else 8
	area.collision_mask = 2
	area.set_meta("map_data", entry.duplicate(true))
	area.add_to_group("special_locations" if special else "resource_points")
	area.add_to_group(str(entry.kind))
	var shape := CircleShape2D.new()
	shape.radius = float(entry.radius) if special else size * 0.22
	var collision := CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	var marker := Polygon2D.new()
	var radius := 10.0 if special else 6.0
	marker.polygon = PackedVector2Array([Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0)])
	marker.color = Color("ffd166") if special else Color("b8efcf")
	area.add_child(marker)
	var label := Label.new()
	label.text = str(entry.name)
	label.position = Vector2(-30, 12)
	label.add_theme_font_size_override("font_size", 12)
	area.add_child(label)
	if special:
		area.body_entered.connect(func(body: Node2D): location_entered.emit(str(entry.id), str(entry.kind), body))
		area.body_exited.connect(func(body: Node2D): location_exited.emit(str(entry.id), str(entry.kind), body))
	parent.add_child(area)

func _fail(message: String) -> bool:
	push_error(message)
	load_failed.emit(message)
	return false
