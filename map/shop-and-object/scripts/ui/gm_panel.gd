extends VBoxContainer
var inventory: Inventory
var item_id := LineEdit.new()
var amount := SpinBox.new()
var day := HSlider.new()
var status := Label.new()
## 设置目标背包；target 可由外部游戏注入。
func setup(target: Inventory) -> void:
 inventory = target
## 构建 GM 控件；无参数。
func _ready() -> void:
 if inventory == null: inventory = Inventory.new()
 item_id.placeholder_text = "物品 ID"
 item_id.text = Config.data.test_item
 add_child(item_id)
 amount.min_value = 1
 amount.max_value = Config.data.gm_max_count
 amount.value = Config.data.test_count
 add_child(amount)
 button("添加物品", add_items)
 day.min_value = 1
 day.max_value = Config.data.days
 day.step = 1
 day.value = GameState.current_day
 day.value_changed.connect(set_day)
 add_child(day)
 button("重载物品数据库", ItemDatabase.reload)
 button("重载配方数据", CraftingSystem.reload)
 button("导出当前配置", export_config)
 add_child(status)
## 添加按钮；title 为标题，action 为回调。
func button(title: String, action: Callable) -> void:
 var control := Button.new()
 control.text = title
 control.pressed.connect(action)
 add_child(control)
## 向目标背包添加配置数量；无参数。
func add_items() -> void:
 status.text = "添加成功" if inventory.add_item(item_id.text, int(amount.value)) else "添加失败：ID、容量或重量不符合要求"
## value 是滑块选择的天数。
func set_day(value: float) -> void:
 GameState.current_day = int(value)
 GameState.state_changed.emit()
## 导出当前生效物品数值到 user://；无参数。
func export_config() -> void:
 var rows: Array = []
 for item in ItemDatabase.entries.values():
  var row: Dictionary = {}
  for key in ["id","name","description","icon_path","rarity","category","stackable","max_stack","weight","base_value","element_type","is_tradeable","is_bound"]: row[key] = item.get(key)
  rows.append(row)
 var file := FileAccess.open("user://config_backup.json", FileAccess.WRITE)
 if file == null:
  status.text = "导出失败"
  return
 file.store_string(JSON.stringify({"items": rows}, "  "))
 status.text = "已导出 user://config_backup.json"
