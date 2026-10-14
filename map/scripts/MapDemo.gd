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
	add_child(loader)
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
	player = CharacterBody2D.new()
	player.collision_layer = 2
	player.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12
	shape.shape = circle
	player.add_child(shape)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)])
	visual.color = Color.WHITE
	player.add_child(visual)
	add_child(player)
	loader.location_entered.connect(func(id: String, kind: String, _body: Node2D): status.text = "进入特殊地点：%s (%s)" % [id, kind])
	loader.location_exited.connect(func(_id: String, _kind: String, _body: Node2D): status.text = "继续探索")
	_select_map(0)

func _select_map(index: int) -> void:
	if loader.load_map(MAP_IDS[index]):
		player.position = loader.position + loader.spawn_position
		status.text = "当前大陆：" + MAP_NAMES[index]

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	player.velocity = direction.normalized() * 180.0
	player.move_and_slide()
