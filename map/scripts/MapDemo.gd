extends Node2D

const Loader = preload("res://scripts/MapLoader.gd")
const MAP_IDS := ["emerald", "sun_sands", "frost_crown", "ancient_woods", "ember", "convergence"]
const MAP_NAMES := ["翠绿大陆", "烈日沙洲", "霜冠大陆", "古木大陆", "余烬大陆", "交汇大陆"]
var loader: Node2D
var player: CharacterBody2D
var status: Label

func _ready() -> void:
	loader = Loader.new()
	loader.position = Vector2(60, 110)
	call_deferred("_attach_loader")
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "六大陆地图 · WASD / 方向键移动 · 金色：特殊地点 · 绿色：资源"
	title.position = Vector2(60, 12)
	ui.add_child(title)
	var selector := OptionButton.new()
	selector.position = Vector2(60, 46)
	for map_name in MAP_NAMES:
		selector.add_item(map_name)
	selector.item_selected.connect(_select_map)
	ui.add_child(selector)
	status = Label.new()
	status.position = Vector2(260, 52)
	ui.add_child(status)
	player = preload("res://scenes/Player.tscn").instantiate()
	add_child(player)
	loader.location_entered.connect(func(id: String, kind: String, _body: Node2D): status.text = "进入特殊地点：%s (%s)" % [id, kind])
	loader.location_exited.connect(func(_id: String, _kind: String, _body: Node2D): status.text = "继续探索")
	GameManager.time_updated.connect(func(_day: int, _period: int): _update_status())

func _attach_loader() -> void:
	loader.map_loaded.connect(_on_map_loaded)
	loader.load_failed.connect(func(message: String): status.text = "加载失败：" + message)
	add_child(loader)

func _on_map_loaded(_id: String) -> void:
	player.teleport_to(loader.to_global(loader.spawn_position))
	_update_status()

func _update_status() -> void:
	status.text = "大陆 %d · 第 %d 天 · %s · 1–6 切换，空格推进时间" % [
		GameManager.current_continent_id, GameManager.current_day,
		GameManager.PERIOD_NAMES[GameManager.current_period]]

func _select_map(index: int) -> void:
	GameManager.switch_to_continent(index)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_6:
		GameManager.switch_to_continent(event.keycode - KEY_1)
	elif event.keycode == KEY_SPACE:
		GameManager.next_time_period()
