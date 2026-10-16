class_name InventorySlot
extends Resource
@export var slot_index: int
@export var item_id: String = ""
@export var count: int = 0
## 判断格子是否为空；无参数。
func is_empty() -> bool:
 return item_id.is_empty() or count <= 0
## 清空格子；无参数。
func clear() -> void:
 item_id = ""
 count = 0
