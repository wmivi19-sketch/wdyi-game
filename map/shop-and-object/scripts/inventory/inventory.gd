class_name Inventory
extends Resource
signal inventory_changed
signal weight_changed(current: float, max: float)
var slots: int
var max_weight: float
var items: Array[InventorySlot] = []
var current_weight: float = 0.0
## 从通用配置初始化背包；无参数。
func _init() -> void:
 slots = int(Config.data["slots"])
 max_weight = float(Config.data["max_weight"])
 for index in slots:
  var slot := InventorySlot.new()
  slot.slot_index = index
  items.append(slot)
 ItemDatabase.database_reloaded.connect(_update_weight)
## 返回聚合数量快照；无参数。
func snapshot() -> Dictionary:
 var result: Dictionary = {}
 for slot in items:
  if not slot.is_empty(): result[slot.item_id] = int(result.get(slot.item_id, 0)) + slot.count
 return result
## 校验总重量、格子和堆叠；counts 为候选快照，不改变当前数据。
func fits(counts: Dictionary) -> bool:
 var needed := 0
 var weight := 0.0
 for id in counts:
  var item := ItemDatabase.get_item(id)
  var count := int(counts[id])
  if item == null or count < 0: return false
  var stack := item.max_stack if item.stackable else 1
  needed += ceili(float(count) / stack)
  weight += item.weight * count
 return needed <= slots and weight <= max_weight
## 提交已校验快照；notify 可延迟信号至多背包事务结束。
func commit(counts: Dictionary, notify: bool = true) -> bool:
 if not fits(counts): return false
 var staged: Array[InventorySlot] = []
 for index in slots:
  var slot := InventorySlot.new()
  slot.slot_index = index
  staged.append(slot)
 var index := 0
 for id in counts:
  var item := ItemDatabase.get_item(id)
  var remaining := int(counts[id])
  while remaining > 0:
   var amount := mini(remaining, item.max_stack if item.stackable else 1)
   staged[index].item_id = id
   staged[index].count = amount
   remaining -= amount
   index += 1
 items = staged
 if notify: publish()
 return true
## 发布已提交变更；无参数。
func publish() -> void:
 _update_weight()
 inventory_changed.emit()
## 添加正数 count 个 item_id；失败时无副作用。
func add_item(item_id: String, count: int) -> bool:
 if count <= 0: return false
 var next := snapshot()
 next[item_id] = int(next.get(item_id, 0)) + count
 if not fits(next): return false
 commit(next)
 return true
## 移除正数 count 个 item_id；失败时无副作用。
func remove_item(item_id: String, count: int) -> bool:
 if count <= 0 or not has_item(item_id, count): return false
 # 直接减去既有格子的数量，允许热重载后超堆叠/超重背包逐步恢复。
 var remaining := count
 for slot in items:
  if slot.item_id != item_id: continue
  var amount := mini(remaining, slot.count)
  slot.count -= amount
  remaining -= amount
  if slot.count == 0: slot.clear()
  if remaining == 0: break
 publish()
 return true
## 检查 item_id 是否至少有 count 个。
func has_item(item_id: String, count: int) -> bool:
 return count > 0 and get_item_count(item_id) >= count
## 汇总 item_id 的数量。
func get_item_count(item_id: String) -> int:
 return int(snapshot().get(item_id, 0))
## 重算热重载后的重量；无参数。
func _update_weight() -> void:
 current_weight = 0.0
 for slot in items:
  var item := ItemDatabase.get_item(slot.item_id)
  if item != null: current_weight += item.weight * slot.count
 weight_changed.emit(current_weight, max_weight)
