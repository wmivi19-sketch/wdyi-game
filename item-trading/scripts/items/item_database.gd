extends Node
signal database_reloaded
var entries: Dictionary = {}
## 启动时加载数据；无参数。
func _ready() -> void:
 reload()
## 验证所有文件后一次替换，错误不会破坏上一版本；无参数。
func reload() -> void:
 var next: Dictionary = {}
 for path in Config.files("res://resources/items"):
  var document := Config.read_json(path)
  if not document.get("items") is Array: return
  for row in document.items:
   if not row is Dictionary or not row.has_all(["id", "name", "weight", "max_stack", "rarity"]):
    push_warning("物品字段不完整：" + path)
    return
   if next.has(row.id) or float(row.weight) < 0 or int(row.max_stack) <= 0:
    push_warning("物品数值或 ID 非法：" + path)
    return
   var item := Item.new()
   for key in row:
    if key in ["id","name","description","icon_path","rarity","category","stackable","max_stack","weight","base_value","element_type","is_tradeable","is_bound"]: item.set(key, row[key])
   next[item.id] = item
 entries = next
 AssetManager.clear_cache()
 database_reloaded.emit()
## id 为物品 ID；未知 ID 返回 null。
func get_item(id: String) -> Item:
 return entries.get(id)
## category 为分类；返回所有匹配物品。
func get_items_by_category(category: String) -> Array:
 return entries.values().filter(func(item): return item.category == category)
## rarity 为稀有度；返回所有匹配物品。
func get_items_by_rarity(rarity: int) -> Array:
 return entries.values().filter(func(item): return item.rarity == rarity)
