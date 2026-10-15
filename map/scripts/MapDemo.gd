extends Node2D

const Loader = preload("res://scripts/MapLoader.gd")
const MAP_IDS := ["emerald", "sun_sands", "frost_crown", "ancient_woods", "ember", "convergence"]
const MAP_NAMES := ["翠绿大陆", "烈日沙洲", "霜冠大陆", "古木大陆", "余烬大陆", "交汇大陆"]
var loader: Node2D
var player: CharacterBody2D
var status: Label
var progression_world: Node
var character_info_ui: CanvasLayer
var nearby_locations: Dictionary = {}

func _ready() -> void:
	loader = Loader.new()
	loader.position = Vector2(60, 110)
	call_deferred("_attach_loader")
	character_info_ui = preload("res://scenes/CharacterInfoUI.tscn").instantiate()
	var ui: CanvasLayer = character_info_ui
	add_child(ui)
	var title := Label.new()
	title.text = "六大陆地图 · WASD移动 · Tab人物信息 · E交互 · Q神力 · 金色地点 / 绿色资源"
	title.position = Vector2(60, 12)
	ui.add_child(title)
	var selector := OptionButton.new()
	selector.focus_mode = Control.FOCUS_NONE
	selector.position = Vector2(60, 46)
	for map_name in MAP_NAMES:
		selector.add_item(map_name)
	selector.item_selected.connect(_select_map)
	GameManager.continent_switched.connect(func(id: int): selector.select(id))
	ui.add_child(selector)
	status = Label.new()
	status.position = Vector2(260, 52)
	ui.add_child(status)
	player = preload("res://scenes/Player.tscn").instantiate()
	add_child(player)
	# Keep the player clear of the sidebar only while it is open.
	character_info_ui.panel_toggled.connect(func(is_visible: bool):
		player.camera.offset = Vector2(180, 0) if is_visible else Vector2.ZERO)
	progression_world = preload("res://progression/world.gd").new()
	add_child(progression_world)
	progression_world.setup(loader, player)
	var progression_panel: VBoxContainer = ui.get_node("CharacterInfoPanel/ProgressionPanel")
	progression_panel.setup(progression_world)
	loader.location_entered.connect(_on_location_entered)
	loader.location_exited.connect(_on_location_exited)
	GameManager.time_updated.connect(func(_day: int, _period: int): _update_status())

func _attach_loader() -> void:
	loader.map_loaded.connect(_on_map_loaded)
	loader.load_failed.connect(func(message: String): status.text = "加载失败：" + message)
	add_child(loader)

func _on_map_loaded(_id: String) -> void:
	nearby_locations.clear()
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
	elif event.keycode == KEY_SPACE:
		GameManager.next_time_period()
	elif event.keycode == KEY_E:
		progression_world.interact()
	elif event.keycode == KEY_Q:
		progression_world.cast_sun_burst()
