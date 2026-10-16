extends Node
var failures := 0
## 执行地图、角色、采集、合成及商人交易集成；无参数。
func _ready() -> void:
 call_deferred("run")
## condition 为测试条件，message 是失败说明。
func check(condition: bool, message: String) -> void:
 if not condition:
  failures += 1
  push_error(message)
## 使用真正主场景的适配层，不另建模拟背包。
func run() -> void:
 var scene = load("res://scenes/MapDemo.tscn").instantiate()
 add_child(scene)
 await get_tree().process_frame
 await get_tree().physics_frame
 var bridge = scene.get_node("WorldItems")
 check(scene.player.get_meta("inventory") == bridge.inventory, "角色与 UI 共用背包")
 check(GameState.current_day == GameManager.current_day, "日期同步")
 GameManager.next_time_period()
 check(GameState.current_time == bridge.config.period_times[GameManager.current_period], "时段同步")
 ClassManager.add_class_slot("mage", 1)
 check("mage" in GameState.player_professions, "原角色职业同步")
 var marker = scene.loader.resource_points.get_child(0)
 scene.player.teleport_to(marker.global_position)
 var entry: Dictionary = marker.get_meta("map_data")
 var item_id: String = bridge.config.resource_items[entry.kind]
 var before: int = bridge.inventory.get_item_count(item_id)
 check(bridge.collect_nearest(), "地图资源采集")
 check(bridge.inventory.get_item_count(item_id) == before + int(entry.amount), "资源进入角色背包")
 check(not bridge.collect_nearest(), "同一资源不能重复采集")
 var map_id: int = GameManager.current_continent_id
 scene.loader.load_map_from_json(map_id)
 marker = scene.loader.resource_points.get_child(0)
 scene.player.teleport_to(marker.global_position)
 check(not bridge.collect_nearest(), "切换地图后耗尽记录仍存在")
 check(not marker.visible, "耗尽资源不再显示")
 bridge.inventory.add_item("mat_fire_01", 1)
 var crafted: Dictionary = await CraftingSystem.attempt_craft("fire_fragment", bridge.inventory)
 check(crafted.success, "地图背包可合成")
 var market_id: String = bridge.config.market_ids[GameManager.current_continent_id]
 check(scene.loader.special_locations.get_child_count() > 0, "地图生成交易所")
 bridge.on_entered(market_id, "market", scene.player)
 GameManager.current_day = int(TradeManager.config.trade_days[0])
 GameManager.current_period = GameManager.Period.NOON
 GameManager.time_updated.emit(GameManager.current_day, GameManager.current_period)
 bridge.inventory.add_item("faith_point", ItemDatabase.get_item("mat_fragment").base_value)
 var cash_before: int = bridge.inventory.get_item_count("faith_point")
 var goods_before: int = bridge.inventory.get_item_count("mat_fragment")
 check(bridge.exchange(true, "mat_fragment", 1), "交易所买入")
 check(bridge.inventory.get_item_count("mat_fragment") == goods_before + 1, "买入到账")
 check(bridge.inventory.get_item_count("faith_point") == cash_before - ItemDatabase.get_item("mat_fragment").base_value, "买入扣费")
 check(bridge.exchange(false, "mat_fragment", 1), "交易所卖出")
 check(bridge.inventory.get_item_count("faith_point") == cash_before, "卖出到账")
 check(not bridge.exchange(true, "bound_relic", 1), "绑定物不能产生单向扣费")
 bridge.on_exited(market_id, "market", scene.player)
 check(not bridge.exchange(true, "mat_fragment", 1), "离开市场禁止交易")
 print("Item world integration complete; failures=", failures)
 get_tree().quit(0 if failures == 0 else 1)
