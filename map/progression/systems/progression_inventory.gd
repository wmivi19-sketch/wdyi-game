extends RefCounted
class_name ProgressionInventory

# No signals inside transactions: commits cannot re-enter progression logic.
var _items: Dictionary = {}
## 可选共享背包；纯职业单元测试仍可使用原始独立模式。
var shared: Resource
## 将职业库存接到地图角色背包；target 为唯一权威背包。
func bind_inventory(target: Resource) -> void:
	shared = target


func count_item(item_id: String) -> int:
	return shared.get_item_count(item_id) if shared != null else int(_items.get(item_id, 0))

func add_item(item_id: String, count: int) -> bool:
	if shared != null: return shared.add_item(item_id, count)
	if item_id.is_empty() or count <= 0:
		return false
	_items[item_id] = count_item(item_id) + count
	return true

func try_consume(item_id: String, count: int) -> bool:
	if shared != null:
		if count <= 0 or not shared.has_item(item_id, count): return false
		var next: Dictionary = shared.snapshot()
		next[item_id] -= count
		if not shared.commit(next, false): return false
		# 仪式先完成职业状态提交，再对 UI 发布背包信号，防止回调重入。
		shared.call_deferred("publish")
		return true
	if count <= 0 or count_item(item_id) < count:
		return false
	_items[item_id] = count_item(item_id) - count
	return true

func craft(recipe: ClassRecipe) -> bool:
	if shared != null:
		if recipe == null or recipe.output_count <= 0 or recipe.output_mark_id.is_empty(): return false
		var next: Dictionary = shared.snapshot()
		for id in recipe.materials:
			var required := int(recipe.materials[id])
			if required <= 0 or int(next.get(id, 0)) < required: return false
			next[id] -= required
		next[recipe.output_mark_id] = int(next.get(recipe.output_mark_id, 0)) + recipe.output_count
		return shared.commit(next)
	if recipe == null or recipe.output_mark_id.is_empty() or recipe.output_count <= 0:
		return false
	for item_id in recipe.materials:
		var count: int = int(recipe.materials[item_id])
		if count <= 0 or count_item(String(item_id)) < count:
			return false
	for item_id in recipe.materials:
		_items[item_id] = count_item(String(item_id)) - int(recipe.materials[item_id])
	return add_item(recipe.output_mark_id, recipe.output_count)
