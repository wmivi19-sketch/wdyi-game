class_name ProfessionSlot
extends HBoxContainer
signal profession_selected(id: String)
var profession_id: String = ""
var slot_index: int
@onready var icon_texture: TextureRect = $Icon
@onready var name_label: Label = $NameLabel
@onready var level_label: Label = $LevelLabel
@onready var empty_label: Label = $EmptyLabel
## 初始化详情按钮；无参数。
func _ready() -> void:
 $Details.pressed.connect(func(): profession_selected.emit(profession_id))
 $Details.focus_mode = Control.FOCUS_NONE
## prof_id 是职业 ID；index 为槽索引。
func setup(prof_id: String, index: int) -> void:
 var data := ProfessionDatabase.get_profession(prof_id)
 if data.is_empty():
  setup_empty(index)
  return
 profession_id = prof_id
 slot_index = index
 icon_texture.texture = AssetManager.generate_placeholder(index)
 name_label.text = data.name
 level_label.text = "已掌握"
 empty_label.hide()
 $Details.disabled = false
## index 为空槽位索引，游戏尚无等级系统，不显示虚构等级。
func setup_empty(index: int) -> void:
 profession_id = ""
 slot_index = index
 icon_texture.texture = null
 name_label.text = ""
 level_label.text = ""
 empty_label.text = "空槽位 %d" % (index + 1)
 empty_label.show()
 $Details.disabled = true
