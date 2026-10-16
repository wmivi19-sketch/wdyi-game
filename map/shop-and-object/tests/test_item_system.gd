extends Node
var failures: int = 0
## 延迟测试至单例初始化结束；无参数。
func _ready() -> void:
 call_deferred("run")
## condition 为断言，message 为失败说明。
func check(condition: bool, message: String) -> void:
 if not condition:
  failures += 1
  push_error(message)
## 运行背包、异步合成及交易回归测试；无参数。
func run() -> void:
 var inv := Inventory.new()
 var item := ItemDatabase.get_item("mat_fire_01")
 check(inv.add_item(item.id, item.max_stack + 1), "添加和拆分堆叠")
 check(inv.items[0].count == item.max_stack and inv.items[1].count == 1, "堆叠上限")
 check(is_equal_approx(inv.current_weight, item.weight * (item.max_stack + 1)), "重量计算")
 check(inv.remove_item(item.id, 1), "移除")
 var before := inv.snapshot()
 check(not inv.remove_item(item.id, item.max_stack + 1) and inv.snapshot() == before, "移除失败原子性")
 check(not inv.add_item("missing", 1), "拒绝未知物品")
 check(not inv.add_item(item.id, item.max_stack * inv.slots), "拒绝超重")
 inv = Inventory.new()
 inv.add_item("mat_fire_01", 1)
 var result: Dictionary = await CraftingSystem.attempt_craft("fire_fragment", inv)
 check(result.success and inv.get_item_count("mat_fragment") == 1 and inv.get_item_count("mat_fire_01") == 0, "成功合成提交")
 var recipe: Recipe = CraftingSystem.recipes.wind_fragment
 var rate := recipe.success_rate
 CraftingSystem.rng.seed = int(Config.data.seed)
 var wins := 0
 var trials := int(Config.data.probability_trials)
 for index in trials:
  var sample := Inventory.new()
  sample.add_item("wind_essence", 1)
  var outcome: Dictionary = await CraftingSystem.attempt_craft("wind_fragment", sample)
  if outcome.success: wins += 1
  check(sample.get_item_count("wind_essence") == 0, "概率合成消耗")
 check(absf(float(wins) / trials - rate) < float(Config.data.probability_tolerance), "合成成功率分布")
 GameState.current_day = int(TradeManager.config.trade_days[0])
 GameState.current_time = "%02d:00" % int(TradeManager.config.trade_hours.start)
 var place: String = TradeManager.config.exchange_locations[0]
 var a := Inventory.new()
 var b := Inventory.new()
 a.add_item("mat_fire_01", 1)
 b.add_item("water_essence", 1)
 TradeManager.register_player("a", a, place)
 TradeManager.register_player("b", b, place)
 var id := TradeManager.create_trade_session("a", "b")
 var s := TradeManager.get_active_session(id)
 check(s != null, "创建交易")
 if s != null:
  s.add_offer("a", "mat_fire_01", 1)
  s.add_offer("b", "water_essence", 1)
  s.lock_offer("a")
  s.lock_offer("b")
  check(s.confirm_trade(), "交易提交")
  check(a.has_item("water_essence", 1) and b.has_item("mat_fire_01", 1), "交换结果")
  check(not s.confirm_trade(), "拒绝重复提交")
 var blocked := TradeManager.create_trade_session("a", "b")
 var pending := TradeManager.get_active_session(blocked)
 if pending != null:
  pending.add_offer("a", "water_essence", 1)
  pending.lock_offer("a")
  pending.lock_offer("b")
  b.max_weight = 0.0
  var saved_a := a.snapshot()
  var saved_b := b.snapshot()
  check(not pending.confirm_trade(), "容量不足拒绝交易")
  check(a.snapshot() == saved_a and b.snapshot() == saved_b, "交易失败双方无变化")
  pending.timeout_timer = 0.0
  TradeManager._process(0.0)
  check(pending.cancelled and TradeManager.get_active_session(blocked) == null, "超时取消")
 var texture := item.get_icon()
 check(texture != null and texture.get_width() == int(Config.data.icon_size), "占位图标")
 var old_count := ItemDatabase.entries.size()
 ItemDatabase.reload()
 check(ItemDatabase.entries.size() == old_count, "数据库重载")
 check(not CraftingSystem.can_craft("god_material", Inventory.new()), "合成条件限制")
 await review_regressions()
 print("Tests complete; failures=", failures)
 get_tree().quit(0 if failures == 0 else 1)

## 覆盖代码审查发现的热重载、配置以及概率边界；无参数。
func review_regressions() -> void:
 var inv := Inventory.new()
 inv.slots = 2
 inv.items.resize(2)
 check(inv.add_item("mat_fragment", 10), "准备旧堆叠")
 var item := ItemDatabase.get_item("mat_fragment")
 var previous_stack := item.max_stack
 item.max_stack = 1
 check(inv.remove_item("mat_fragment", 1), "新堆叠限制下仍可移除")
 check(inv.get_item_count("mat_fragment") == 9, "移除不会丢失剩余物品")
 var before := inv.snapshot()
 check(not inv.commit(before) and inv.snapshot() == before, "不合法提交保留原背包")
 item.max_stack = previous_stack
 var valid := Config.data.duplicate(true)
 check(Config.validate(valid), "有效完整配置")
 var broken := valid.duplicate(true)
 broken.erase("slots")
 check(not Config.validate(broken), "拒绝遗漏字段")
 for key in ["minutes_per_day", "minutes_per_hour", "slots", "icon_size", "poll_seconds"]:
  broken = valid.duplicate(true)
  broken[key] = 0
  check(not Config.validate(broken), "拒绝零值：" + key)
 broken = valid.duplicate(true)
 broken.max_weight = "50"
 check(not Config.validate(broken), "拒绝错误字段类型")
 broken = valid.duplicate(true)
 broken.initial_time = "invalid"
 check(not Config.validate(broken), "拒绝非法时间")
 broken = valid.duplicate(true)
 broken.rarity_colors = []
 check(not Config.validate(broken), "拒绝空颜色表")
 # 在同一帧保存、加载、恢复文件，验证失败时不会覆盖有效配置。
 var path := "res://shop-and-object/resources/settings.json"
 var original := FileAccess.get_file_as_string(path)
 var file := FileAccess.open(path, FileAccess.WRITE)
 file.store_string(JSON.stringify({"slots": 2}))
 file.close()
 Config.reload()
 check(Config.data == valid, "无效热重载保留有效配置")
 file = FileAccess.open(path, FileAccess.WRITE)
 file.store_string(original)
 file.close()
 var r: Recipe = CraftingSystem.recipes.fire_fragment
 var old_failure := r.failure_output_id
 r.failure_output_id = "iron_sword"
 var small := Inventory.new()
 small.max_weight = 0.5
 small.add_item("mat_fire_01", 1)
 check(CraftingSystem.can_craft(r.id, small), "100%配方忽略失败产物容量")
 var outcome: Dictionary = await CraftingSystem.attempt_craft(r.id, small)
 check(outcome.success and small.has_item("mat_fragment", 1), "100%配方实际提交")
 r.failure_output_id = old_failure
 var old_success := r.output_item_id
 var old_rate := r.success_rate
 r.success_rate = 0.0
 r.output_item_id = "iron_sword"
 var failure_inv := Inventory.new()
 failure_inv.max_weight = 0.5
 failure_inv.add_item("mat_fire_01", 1)
 check(CraftingSystem.can_craft(r.id, failure_inv), "0%配方忽略成功产物容量")
 outcome = await CraftingSystem.attempt_craft(r.id, failure_inv)
 check(not outcome.success and failure_inv.has_item(old_failure, 1), "0%配方实际提交")
 r.output_item_id = old_success
 r.success_rate = old_rate
 CraftingSystem.craft_started.connect(reload_during_craft, CONNECT_ONE_SHOT)
 var waiting := Inventory.new()
 waiting.add_item("mat_fire_01", 1)
 outcome = await CraftingSystem.attempt_craft("fire_fragment", waiting)
 check(outcome.success and waiting.has_item("mat_fragment", 1), "相同内容重新加载不会取消合成")
 CraftingSystem.craft_started.connect(change_during_craft, CONNECT_ONE_SHOT)
 waiting = Inventory.new()
 waiting.add_item("mat_fire_01", 1)
 outcome = await CraftingSystem.attempt_craft("fire_fragment", waiting)
 check(not outcome.success and waiting.has_item("mat_fire_01", 1), "实际配方改变取消并保留材料")
 CraftingSystem.reload()
## 模拟无关配置变化引起配方重载；recipe_id 是合成开始信号参数。
func reload_during_craft(_recipe_id: String) -> void:
 CraftingSystem.reload()
## 模拟正在合成的配方实际发生变化；recipe_id 为目标配方。
func change_during_craft(recipe_id: String) -> void:
 CraftingSystem.recipes[recipe_id].output_count += 1
