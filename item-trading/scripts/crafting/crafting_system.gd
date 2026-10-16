extends Node
signal craft_started(recipe_id: String)
signal craft_completed(success: bool, result_id: String)
var recipes: Dictionary = {}
var busy: Dictionary = {}
var rng := RandomNumberGenerator.new()
## 初始化配方及随机数；无参数。
func _ready() -> void:
 rng.randomize()
 reload()
## 原子刷新配方；无参数。
func reload() -> void:
 var next: Dictionary = {}
 for path in Config.files("res://resources/recipes"):
  var data := Config.read_json(path)
  if not data.get("recipes") is Array: return
  for row in data.recipes:
   if not row is Dictionary or not row.has_all(["id","inputs","output_item_id","output_count","success_rate","craft_time"]): return
   if next.has(row.id) or row.success_rate < 0 or row.success_rate > 1 or row.output_count <= 0 or row.craft_time < 0: return
   if ItemDatabase.get_item(row.output_item_id) == null: return
   var recipe := Recipe.new()
   for key in row:
    if key == "inputs": recipe.inputs.assign(row[key])
    else: recipe.set(key, row[key])
   for input in recipe.inputs:
    if not input.has_all(["item_id","count"]) or input.count <= 0 or ItemDatabase.get_item(input.item_id) == null: return
   if not recipe.catalyst_id.is_empty() and ItemDatabase.get_item(recipe.catalyst_id) == null: return
   if not recipe.failure_output_id.is_empty() and ItemDatabase.get_item(recipe.failure_output_id) == null: return
   next[recipe.id] = recipe
 recipes = next
## 验证日期、含跨午夜的时间段、地点和职业；r 为配方。
func context_ok(r: Recipe) -> bool:
 var now := GameState.minutes(GameState.current_time)
 var start := GameState.minutes(r.time_start)
 var end := GameState.minutes(r.time_end)
 var time_ok := (now >= start and now <= end) if start <= end else (now >= start or now <= end)
 return (r.required_day == 0 or GameState.current_day == r.required_day) and time_ok and (r.required_location.is_empty() or r.required_location == GameState.player_location) and (r.required_profession.is_empty() or r.required_profession in GameState.player_professions)
## 构建材料扣除后快照；催化剂消耗一个，重复材料合并计算。
func consumed(r: Recipe, inventory: Inventory) -> Dictionary:
 var next := inventory.snapshot()
 for input in r.inputs: next[input.item_id] = int(next.get(input.item_id, 0)) - int(input.count)
 if not r.catalyst_id.is_empty(): next[r.catalyst_id] = int(next.get(r.catalyst_id, 0)) - 1
 return next
## 检查输入及成功、失败两种输出容量；recipe_id 为配方 ID。
func can_craft(recipe_id: String, inventory: Inventory) -> bool:
 var r: Recipe = recipes.get(recipe_id)
 if r == null or busy.has(inventory) or not context_ok(r): return false
 var next := consumed(r, inventory)
 for count in next.values():
  if count < 0: return false
 var outcomes: Array[String] = []
 if r.success_rate > 0.0: outcomes.append(r.output_item_id)
 if r.success_rate < 1.0: outcomes.append(r.failure_output_id)
 for id in outcomes:
  var candidate := next.duplicate()
  if not id.is_empty(): candidate[id] = int(candidate.get(id, 0)) + r.output_count
  if not inventory.fits(candidate): return false
 return true
## 异步合成；调用方需 await。等待完成再次校验，保证失败不吞材料。
func attempt_craft(recipe_id: String, inventory: Inventory) -> Dictionary:
 if not can_craft(recipe_id, inventory): return {"success": false, "message": "条件或容量不足", "result_item_id": ""}
 var r: Recipe = recipes[recipe_id]
 var definition := r.definition()
 busy[inventory] = true
 craft_started.emit(recipe_id)
 await get_tree().create_timer(r.craft_time).timeout
 busy.erase(inventory)
 var current: Recipe = recipes.get(recipe_id)
 if current == null or current.definition() != definition or not can_craft(recipe_id, inventory):
  craft_completed.emit(false, "")
  return {"success": false, "message": "等待期间条件或配置变化，已取消", "result_item_id": ""}
 var success := rng.randf() < r.success_rate
 var id := r.output_item_id if success else r.failure_output_id
 var next := consumed(r, inventory)
 if not id.is_empty(): next[id] = int(next.get(id, 0)) + r.output_count
 inventory.commit(next, false)
 inventory.publish()
 craft_completed.emit(success, id)
 return {"success": success, "message": "合成成功" if success else "合成失败", "result_item_id": id}
## 获取可合成配方；inventory 为目标背包。
func get_available_recipes(inventory: Inventory) -> Array:
 return recipes.values().filter(func(r): return can_craft(r.id, inventory))
