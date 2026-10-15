extends RefCounted
class_name ProgressionInventory

# No signals inside transactions: commits cannot re-enter progression logic.
var _items: Dictionary = {}

func count_item(item_id: String) -> int:
	return int(_items.get(item_id, 0))

func add_item(item_id: String, count: int) -> bool:
	if item_id.is_empty() or count <= 0:
		return false
	_items[item_id] = count_item(item_id) + count
	return true

func try_consume(item_id: String, count: int) -> bool:
	if count <= 0 or count_item(item_id) < count:
		return false
	_items[item_id] = count_item(item_id) - count
	return true

func craft(recipe: ClassRecipe) -> bool:
	if recipe == null or recipe.output_mark_id.is_empty() or recipe.output_count <= 0:
		return false
	for item_id in recipe.materials:
		var count: int = int(recipe.materials[item_id])
		if count <= 0 or count_item(String(item_id)) < count:
			return false
	for item_id in recipe.materials:
		_items[item_id] = count_item(String(item_id)) - int(recipe.materials[item_id])
	return add_item(recipe.output_mark_id, recipe.output_count)
