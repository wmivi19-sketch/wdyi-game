extends Control
## Standalone TextureRect workflow, also available from the existing atlas UI.
const Generator = preload("res://scripts/NamedTerrain.gd")
var regions: Array = []
var world_seed: int = 42
var polygon := PackedVector2Array()
var selector: OptionButton
var preview: TextureRect
var status: Label
var seed_input: SpinBox
var name_input: LineEdit
var map_canvas: Control
var labels: Array[Label] = []

# Let text fields consume GUI input first, then stop game hotkeys reaching the world.
func _unhandled_key_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var file := FileAccess.open("res://resources/maps/named_regions.json", FileAccess.READ)
	if file == null:
		push_error("无法读取 named_regions.json")
		return
	var config: Variant = JSON.parse_string(file.get_as_text())
	if not config is Dictionary or not config.get("regions") is Array:
		push_error("地名配置无效")
		return
	regions = config.regions.duplicate(true)
	world_seed = int(config.get("world_seed", 42))
	for point in config.get("preview_polygon", []):
		polygon.append(Vector2(float(point[0]), float(point[1])))
	var bg := ColorRect.new()
	bg.color = Color("#30291f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	selector = OptionButton.new()
	for entry in regions:
		selector.add_item(Generator.clean_location_name(str(entry.name)))
	toolbar.add_child(selector)
	name_input = LineEdit.new()
	name_input.custom_minimum_size.x = 170
	name_input.placeholder_text = "地名（可输入新名称）"
	toolbar.add_child(name_input)
	seed_input = SpinBox.new()
	seed_input.min_value = 0
	seed_input.max_value = 2147483647
	seed_input.value = world_seed
	seed_input.prefix = "种子 "
	toolbar.add_child(seed_input)
	var generate_button := Button.new()
	generate_button.text = "生成地貌 / 更新标签"
	generate_button.pressed.connect(regenerate)
	toolbar.add_child(generate_button)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(queue_free)
	toolbar.add_child(close_button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	var map_frame := AspectRatioContainer.new()
	map_frame.ratio = 1.5
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(map_frame)
	map_canvas = Control.new()
	map_frame.add_child(map_canvas)
	var atlas := TextureRect.new()
	atlas.texture = load("res://assets/maps/world/world_atlas.png") as Texture2D
	atlas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	atlas.stretch_mode = TextureRect.STRETCH_SCALE
	atlas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_canvas.add_child(atlas)
	for entry in regions:
		var label := Label.new()
		label.text = Generator.clean_location_name(str(entry.name))
		label.add_theme_color_override("font_color", Color("#f1dfb7"))
		label.add_theme_color_override("font_outline_color", Color("#4a3728"))
		label.add_theme_constant_override("outline_size", 4)
		map_canvas.add_child(label)
		labels.append(label)
	map_canvas.resized.connect(layout_labels)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(240, 240)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(preview)
	selector.item_selected.connect(select_region)
	if not regions.is_empty():
		select_region(0)
	call_deferred("layout_labels")

func layout_labels() -> void:
	for index in range(labels.size()):
		var point: Array = regions[index].position
		labels[index].position = Vector2(float(point[0]) / 1536.0, float(point[1]) / 1024.0) * map_canvas.size - labels[index].size / 2.0

func select_region(index: int) -> void:
	selector.select(index)
	name_input.text = str(regions[index].name)
	regenerate()

func regenerate() -> void:
	var index := selector.selected
	if index < 0 or name_input.text.strip_edges().is_empty():
		return
	var raw := name_input.text.strip_edges()
	var clean := Generator.clean_location_name(raw)
	# A renamed region resolves its new semantics rather than retaining its old type.
	var explicit_type := str(regions[index].get("terrain", "")) if raw == str(regions[index].name) else ""
	var kind := Generator.terrain_type(raw, explicit_type)
	var mask := polygon
	if regions[index].has("polygon"):
		mask = PackedVector2Array()
		for point in regions[index].polygon:
			mask.append(Vector2(float(point[0]), float(point[1])))
	preview.texture = ImageTexture.create_from_image(Generator.generate(raw, int(seed_input.value), 256, mask, kind))
	labels[index].text = clean
	selector.set_item_text(index, clean)
	regions[index].name = clean
	regions[index].terrain = kind
	status.text = "%s → %s · 地貌：%s · 右侧为独立地貌预览；边界为示例多边形，未修改游戏碰撞。" % [raw, clean, kind]
	layout_labels()
