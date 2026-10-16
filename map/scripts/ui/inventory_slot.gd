extends Button
## 物品格子视图；只显示和发送选择，不拥有背包数据。
signal item_selected(item_id: String)
var item_id: String = ""
@onready var icon_view: TextureRect = $Icon
@onready var count_label: Label = $Count
## 按钮初始化；无参数。
func _ready() -> void:
 focus_mode = Control.FOCUS_NONE
 pressed.connect(func(): item_selected.emit(item_id))
## slot 是真实背包格子；inventory 用于兼容 setup 接口。
func setup(slot: InventorySlot, _inventory: Inventory) -> void:
 item_id = slot.item_id if not slot.is_empty() else ""
 var item := ItemDatabase.get_item(item_id)
 icon_view.texture = item.get_icon() if item != null else null
 count_label.text = str(slot.count) if item != null else ""
 tooltip_text = item.name if item != null else "空格子"
