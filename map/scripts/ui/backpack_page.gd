class_name BackpackPage
extends ScrollContainer
## 背包页只呈现注入的数据；隐藏时仅标脏。
@onready var grid_container: GridContainer = $Layout/GridContainer
@onready var weight_bar: ProgressBar = $Layout/WeightBar
@onready var weight_label: Label = $Layout/WeightLabel
@onready var detail_label: Label = $Layout/ItemDetailPanel/Detail
@onready var actions: VBoxContainer = $Layout/Actions
var inventory: Inventory
var selected_item: String = ""
var dirty: bool = true
var settings: Dictionary = {}
## target 为玩家共享背包；ui_settings 为显示配置。
func setup(target: Inventory, ui_settings: Dictionary) -> void:
 inventory = target
 settings = ui_settings
 inventory.inventory_changed.connect(mark_dirty)
 inventory.weight_changed.connect(weight_changed)
 ItemDatabase.database_reloaded.connect(mark_dirty)
 resized.connect(update_columns)
 mark_dirty()
## 库存变化只在可见页刷新；无参数。
func mark_dirty() -> void:
 dirty = true
 if is_visible_in_tree(): refresh()
## 只接收重量信号；current/maximum 是重量参数。
func weight_changed(_current: float, _maximum: float) -> void:
 mark_dirty()
## 更新格子与详情；无参数。
func refresh() -> void:
 if inventory == null or not is_visible_in_tree(): return
 dirty = false
 while grid_container.get_child_count() > inventory.items.size():
  var last := grid_container.get_child(-1)
  grid_container.remove_child(last)
  last.queue_free()
 while grid_container.get_child_count() < inventory.items.size():
  var slot = preload("res://scenes/ui/inventory_slot.tscn").instantiate()
  grid_container.add_child(slot)
  slot.item_selected.connect(show_item_detail)
 for index in inventory.items.size():
  var slot = grid_container.get_child(index)
  slot.custom_minimum_size = Vector2.ONE * float(settings.slot_size)
  slot.setup(inventory.items[index], inventory)
 update_columns()
 weight_bar.max_value = maxf(inventory.max_weight, 0.001)
 weight_bar.value = inventory.current_weight
 weight_label.text = "承重 %.2f / %.2f" % [inventory.current_weight, inventory.max_weight]
 weight_bar.modulate = Color(1, 0.3, 0.3) if inventory.current_weight >= inventory.max_weight * float(settings.weight_warning_ratio) else Color.WHITE
 show_item_detail(selected_item)
## 根据可用宽度改变列数，窄屏不会横向溢出；无参数。
func update_columns() -> void:
 if settings.is_empty() or not is_node_ready(): return
 grid_container.columns = maxi(1, int((size.x - 24.0) / (float(settings.slot_size) + 4.0)))
## id 是选中物品，空字符串清空详情。
func show_item_detail(id: String) -> void:
 selected_item = id
 var item := ItemDatabase.get_item(id)
 if item == null or not inventory.has_item(id, 1):
  detail_label.text = "选择一个物品查看详情"
  selected_item = ""
  return
 detail_label.text = "%s · %s\n%s\n单件重量 %.2f · 价值 %d · %s" % [item.name, settings.rarity_names[clampi(item.rarity, 0, settings.rarity_names.size() - 1)], item.description, item.weight, item.base_value, "绑定" if item.is_bound else ("可交易" if item.is_tradeable else "不可交易")]
