extends CanvasLayer

@onready var player = get_parent().get_node("TestPlayer")
var _status: Label
var _picker: FileDialog

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_"+side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var help := Label.new()
	help.text = "人物测试  ·  WASD / 方向键移动  ·  Shift 加速\n空格跳跃（可跳上祭坛）  ·  R 回到起点"
	column.add_child(help)
	var row := HBoxContainer.new()
	column.add_child(row)
	var choose := Button.new()
	choose.text = "更换人物贴图…"
	choose.focus_mode = Control.FOCUS_NONE
	choose.pressed.connect(_open_picker)
	row.add_child(choose)
	var restore := Button.new()
	restore.text = "恢复测试人物"
	restore.focus_mode = Control.FOCUS_NONE
	restore.pressed.connect(func():
		player.character_texture = load("res://assets/characters/test_adventurer.svg")
		_status.text = "已恢复默认人物")
	row.add_child(restore)
	_status = Label.new()
	_status.text = "支持透明 PNG / WebP；换图只影响美术，不改变碰撞。"
	column.add_child(_status)
	_picker = FileDialog.new()
	_picker.title = "选择测试人物贴图"
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_picker.filters = PackedStringArray(["*.png, *.webp, *.jpg, *.jpeg, *.svg ; 人物图片"])
	_picker.file_selected.connect(_load_art)
	_picker.canceled.connect(func(): player.input_blocked = false)
	add_child(_picker)

func _open_picker() -> void:
	player.input_blocked = true
	_picker.popup_centered(Vector2i(900, 600))

func _load_art(path: String) -> void:
	var result: Error = player.load_art_file(path)
	_status.text = "已载入："+path.get_file() if result == OK else "无法读取图片（%s），请换一张图片。" % error_string(result)
	player.input_blocked = false
