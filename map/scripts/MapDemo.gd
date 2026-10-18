extends Node2D

const Loader = preload("res://scripts/MapLoader.gd")
const MAP_IDS := ["emerald", "sun_sands", "frost_crown", "ancient_woods", "ember", "convergence"]
const MAP_NAMES := ["方丈     南冥", "瓦尔卡斯", "索马瑞    神赐山脉", "沃恩科", "北冥    艾兰瑟", "维洛斯           斩魔池"]
var loader: Node2D
var player: CharacterBody2D
var status: Label
var progression_world: Node
var character_info_ui: CanvasLayer
var map_system: MapSystem
var nearby_locations: Dictionary = {}

func _ready() -> void:
	loader = Loader.new()
	loader.position = Vector2(60, 110)
	# Initialize the spawn before the save-restoration listener runs.
	loader.map_loaded.connect(_on_map_loaded)
	call_deferred("_attach_loader")
	character_info_ui = preload("res://scenes/CharacterInfoUI.tscn").instantiate()
	var ui: CanvasLayer = character_info_ui
	add_child(ui)
	var title := Label.new()
	title.text = "六大陆地图 · WASD移动 · Tab/B玩家面板 · Y大陆图 / M区域图 · E交互 · Q神力 · 金色地点 / 绿色资源"
	title.position = Vector2(60, 12)
	ui.add_child(title)
	var selector := OptionButton.new()
	selector.focus_mode = Control.FOCUS_NONE
	selector.position = Vector2(60, 46)
	for map_name in MAP_NAMES:
		selector.add_item(map_name)
	# Loading a save sets the continent before this scene is created.
	selector.select(GameManager.current_continent_id)
	selector.item_selected.connect(_select_map)
	GameManager.continent_switched.connect(func(id: int): selector.select(id))
	ui.add_child(selector)
	status = Label.new()
	status.position = Vector2(260, 52)
	ui.add_child(status)
	player = preload("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player.camera.follow_node(player)
	# Keep the player clear of the sidebar only while it is open.
	character_info_ui.panel_toggled.connect(func(is_visible: bool):
		player.camera.offset = Vector2(180, 0) if is_visible else Vector2.ZERO)
	progression_world = preload("res://progression/world.gd").new()
	add_child(progression_world)
	progression_world.setup(loader, player)
	loader.location_entered.connect(_on_location_entered)
	loader.location_exited.connect(_on_location_exited)
	GameManager.time_updated.connect(func(_day: int, _period: int): _update_status())

	var item_ui := preload("res://shop-and-object/scripts/integration/world_items.gd").new()
	item_ui.name = "WorldItems"
	add_child(item_ui)

	var map_ui := CanvasLayer.new()
	map_ui.name = "MapUI"
	map_ui.layer = 20
	add_child(map_ui)
	map_system = preload("res://scenes/ui/map_system.tscn").instantiate()
	map_ui.add_child(map_system)
	map_system.setup(self)
	GameSession.attach_world(self)

func _attach_loader() -> void:
	loader.load_failed.connect(func(message: String): status.text = "加载失败：" + message)
	add_child(loader)

func _on_map_loaded(_id: String) -> void:
	nearby_locations.clear()
	# Use the loaded terrain extent, including loader translation/scale/rotation.
	var data: Dictionary = loader.current_data
	var extent := Vector2(float(data.width), float(data.height)) * float(data.tile_size)
	var rect := Rect2(loader.to_global(Vector2.ZERO), Vector2.ZERO)
	for corner in [extent, Vector2(extent.x, 0), Vector2(0, extent.y)]:
		rect = rect.expand(loader.to_global(corner))
	player.camera.set_mode("gameplay", {"begin": rect.position, "end": rect.end})
	player.teleport_to(loader.to_global(loader.spawn_position))
	_update_status()

func _on_location_entered(id: String, kind: String, body: Node2D) -> void:
	if body != player:
		return
	nearby_locations[id] = kind
	_update_status()

func _on_location_exited(id: String, _kind: String, body: Node2D) -> void:
	if body != player:
		return
	nearby_locations.erase(id)
	_update_status()

func _update_status() -> void:
	status.text = "大陆 %d · 第 %d 天 · %s · 1–6 切换，空格推进时间" % [
		GameManager.current_continent_id, GameManager.current_day,
		GameManager.PERIOD_NAMES[GameManager.current_period]]
	if not nearby_locations.is_empty():
		var names: Array[String] = []
		for id in nearby_locations:
			names.append(String(id))
		status.text += "\n附近地点：" + "、".join(names)

func _select_map(index: int) -> void:
	GameManager.switch_to_continent(index)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_6:
		GameManager.switch_to_continent(event.keycode - KEY_1)
	elif event.keycode == KEY_F5:
		GameSession.quick_save_feedback()
	elif event.keycode == KEY_F10:
		GameSession.return_to_menu()
	elif event.keycode == KEY_SPACE:
		GameManager.next_time_period()
	elif event.keycode == KEY_E:
		progression_world.interact()
	elif event.keycode == KEY_Q:
		progression_world.cast_sun_burst()
