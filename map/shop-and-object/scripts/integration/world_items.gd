extends CanvasLayer
## 地图与物品系统适配层：拥有本地角色背包、采集状态及商人背包。
var world: Node2D
var inventory: Inventory
var merchant: Inventory
var config: Dictionary = {}
var depleted: Dictionary = {}
var locations: Dictionary = {}
var panel: Control
var body: VBoxContainer
var summary: Label
var feedback: Label
var contents: Label
var recipe_list: VBoxContainer
var selection: OptionButton
var quantity: SpinBox
var gm: Window
var market: String = ""
var item_ids: Array[String] = []
## 从当前游戏取得角色和地图；无参数。
func _ready() -> void:
 world = get_parent()
 config = Config.read_json("res://shop-and-object/resources/integration.json")
 inventory = Inventory.new()
 merchant = Inventory.new()
 merchant.slots = int(config.merchant_slots)
 merchant.max_weight = float(config.merchant_max_weight)
 merchant.items.clear()
 for index in merchant.slots:
  var slot := InventorySlot.new()
  slot.slot_index = index
  merchant.items.append(slot)
 for id in config.starting_items: inventory.add_item(id, int(config.starting_items[id]))
 for id in config.merchant_stock: merchant.add_item(id, int(config.merchant_stock[id]))
 GameState.player_inventory = inventory
 world.player.set_meta("inventory", inventory)
 world.progression_world.inventory.bind_inventory(inventory)
 inventory.inventory_changed.connect(world.progression_world.inventory_changed.emit)
 ClassManager.form_changed.connect(on_form_changed)
 TradeManager.register_player(config.player_id, inventory, "")
 TradeManager.register_player(config.merchant_id, merchant, "")
 world.loader.map_loaded.connect(on_map_loaded)
 world.loader.location_entered.connect(on_entered)
 world.loader.location_exited.connect(on_exited)
 world.player.job_changed.connect(on_job_changed)
 GameManager.time_updated.connect(on_time_updated)
 ItemDatabase.database_reloaded.connect(refresh)
 inventory.inventory_changed.connect(refresh)
 build_ui()
 sync_time()
 on_job_changed(world.player.appearance.current_job)
 refresh()
## 原游戏的日期和时段是唯一时间来源；无参数。
func sync_time() -> void:
 GameState.current_day = GameManager.current_day
 GameState.current_time = str(config.period_times[GameManager.current_period])
 GameState.state_changed.emit()
## 接收原游戏推进时间信号；day、period 为信号参数。
func on_time_updated(_day: int, _period: int) -> void:
 sync_time()
 refresh()
## 从职业管理器同步全部职业，而不是仅用最后一个外观 ID。
func on_form_changed(id: int, _form: Dictionary) -> void:
 if id == 1: on_job_changed(world.player.appearance.current_job)
## 同步已完成仪式的职业；job 是原角色外观/职业 ID。
func on_job_changed(job: String) -> void:
 GameState.player_professions.clear()
 var form: Dictionary = ClassManager.replicated_forms.get(1, {})
 if not form.is_empty(): GameState.player_professions.assign(form.get("class_ids", []))
 elif job != "default" and not job.is_empty(): GameState.player_professions.append(job)
 GameState.state_changed.emit()
 GameState.profession_changed.emit()
 if is_instance_valid(summary): refresh()
## 地图载入后清除旧地点，并在出生点生成配置对应的交易所。
func on_map_loaded(_id: String) -> void:
 for marker in world.loader.resource_points.get_children():
  var data: Dictionary = marker.get_meta("map_data")
  marker.visible = not depleted.has(str(world.loader.current_data.id) + ":" + str(data.id))
 locations.clear()
 market = ""
 update_location()
 var index := GameManager.current_continent_id
 if index >= 0 and index < config.market_ids.size():
  var entry := {"id": str(config.market_ids[index]), "kind": "market", "name": "交易所", "cell": world.loader.current_data.spawn, "radius": int(world.loader.current_data.tile_size)}
  world.loader._add_marker(world.loader.special_locations, entry, int(world.loader.current_data.tile_size), true)
 refresh()
## 只接收本角色的地点进入事件，过滤其他角色。
func on_entered(id: String, kind: String, actor: Node2D) -> void:
 if actor != world.player: return
 locations[id] = kind
 update_location()
## 地点退出时只移除相应区域，避免重叠区域串扰。
func on_exited(id: String, _kind: String, actor: Node2D) -> void:
 if actor != world.player: return
 locations.erase(id)
 update_location()
## 同步合成位置与双方交易位置，离开市场立即禁止交易。
func update_location() -> void:
 market = ""
 var place := ""
 for id in locations:
  place = id
  if locations[id] == "market": market = id
 GameState.change_location(place)
 TradeManager.locations[config.player_id] = market
 TradeManager.locations[config.merchant_id] = market
 if is_instance_valid(summary): refresh()
## 采集最近资源一次；耗尽记录跨地图切换保留，背包满则不消耗资源。
func collect_nearest() -> bool:
 var nearest: Node2D
 var distance := float(config.collect_distance)
 for marker in world.loader.resource_points.get_children():
  var entry: Dictionary = marker.get_meta("map_data")
  var key := str(world.loader.current_data.id) + ":" + str(entry.id)
  if depleted.has(key): continue
  var candidate: float = world.player.global_position.distance_to(marker.global_position)
  if candidate <= distance:
   nearest = marker
   distance = candidate
 if world.player.hp <= 0.0 or not world.player.can_interact: return false
 if nearest == null:
  feedback.text = "附近没有可采集资源，靠近绿色标记后按 E"
  return false
 var data: Dictionary = nearest.get_meta("map_data")
 var id := str(config.resource_items.get(data.kind, ""))
 if not inventory.add_item(id, int(data.amount)):
  feedback.text = "背包容量或承重不足，资源未消耗"
  return false
 depleted[str(world.loader.current_data.id) + ":" + str(data.id)] = true
 nearest.visible = false
 feedback.text = "采集：%s × %d" % [ItemDatabase.get_item(id).name, int(data.amount)]
 return true
## 使用同一 TradeManager 原子交易；buy 为买入方向，id/count 是报价。
func exchange(buy: bool, id: String, count: int) -> bool:
 var item := ItemDatabase.get_item(id)
 if item == null or not item.is_tradeable or item.is_bound or count <= 0 or item.base_value <= 0 or id == TradeManager.config.currency_item_id: return false
 var session_id := TradeManager.create_trade_session(config.player_id, config.merchant_id)
 if session_id.is_empty():
  feedback.text = "交易需在交易日的开放时段，并位于交易所"
  return false
 var session := TradeManager.get_active_session(session_id)
 var payer: String = config.player_id if buy else config.merchant_id
 var seller: String = config.merchant_id if buy else config.player_id
 session.add_offer(payer, TradeManager.config.currency_item_id, item.base_value * count)
 session.add_offer(seller, id, count)
 session.lock_offer(config.player_id)
 session.lock_offer(config.merchant_id)
 var success := session.confirm_trade()
 if not success: session.cancel_trade()
 feedback.text = "交易成功" if success else "交易失败：数量、信仰点、库存或容量不足"
 refresh()
 return success
## 异步合成共享背包；id 是配方 ID。
func craft(id: String) -> void:
 feedback.text = "正在合成…"
 var result: Dictionary = await CraftingSystem.attempt_craft(id, inventory)
 feedback.text = result.message
 refresh()
## 创建右侧面板，所有内容连接真实玩家背包；无参数。
func build_ui() -> void:
 panel = world.character_info_ui.character_info_panel
 body = VBoxContainer.new()
 panel.backpack_page.actions.add_child(body)
 summary = Label.new()
 summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 body.add_child(summary)
 feedback = Label.new()
 feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 body.add_child(feedback)
 add_button(body, "采集附近资源 [E]", collect_nearest)
 contents = Label.new()
 body.add_child(contents)
 contents.hide()
 recipe_list = VBoxContainer.new()
 body.add_child(recipe_list)
 selection = OptionButton.new()
 selection.fit_to_longest_item = false
 selection.clip_text = true
 body.add_child(selection)
 quantity = SpinBox.new()
 quantity.min_value = 1
 quantity.max_value = Config.data.gm_max_count
 body.add_child(quantity)
 add_button(body, "向商人购买（单价=基础价值）", trade_selected.bind(true))
 add_button(body, "向商人出售（单价=基础价值）", trade_selected.bind(false))
 add_button(body, "GM 调试 [F3]", open_gm)
 add_button(body, "保存游戏 [F5]", GameSession.quick_save_feedback)
 add_button(body, "保存并返回主菜单 [F10]", GameSession.return_to_menu)
 world.character_info_ui.setup(self)
 # Mount inside the existing PlayerPanel so movement/combat/map guards and
 # Tab/B/Esc remain bound to the same window and shared inventory.
 var radial := preload("res://shop-and-object/scenes/ui/game_radial_ui.tscn").instantiate()
 radial.name = "RadialUI"
 radial.bind(self)
 panel.add_child(radial)
## 添加按钮；parent 为容器，text 为标题，action 为回调。
func add_button(parent: Node, text: String, action: Callable) -> void:
 var button := Button.new()
 button.text = text
 button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 button.focus_mode = Control.FOCUS_NONE
 button.pressed.connect(action)
 parent.add_child(button)
## 刷新物品、配方与市场状态；无参数。
func refresh() -> void:
 if not is_instance_valid(summary) or not panel.is_visible_in_tree() or panel.current_page != 0: return
 summary.text = "背包 [B] · 第 %d 天 %s\n重量 %.2f / %.2f · %s" % [GameState.current_day, GameState.current_time, inventory.current_weight, inventory.max_weight, market if not market.is_empty() else "不在交易所"]
 contents.text = "物品：\n"
 for id in inventory.snapshot():
  var item := ItemDatabase.get_item(id)
  contents.text += "%s × %d\n" % [item.name if item != null else id, inventory.get_item_count(id)]
 for child in recipe_list.get_children():
  recipe_list.remove_child(child)
  child.queue_free()
 for r in CraftingSystem.recipes.values():
  var button := Button.new()
  button.text = "合成：" + r.name
  button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  button.focus_mode = Control.FOCUS_NONE
  button.disabled = not CraftingSystem.can_craft(r.id, inventory)
  button.pressed.connect(craft.bind(r.id))
  recipe_list.add_child(button)
 var selected_id := item_ids[selection.selected] if selection.selected >= 0 and selection.selected < item_ids.size() else ""
 selection.clear()
 item_ids.clear()
 for item in ItemDatabase.entries.values():
  if item.is_tradeable and not item.is_bound and item.id != TradeManager.config.currency_item_id:
   item_ids.append(item.id)
   selection.add_item("%s · %d 信仰点 · 商人库存 %d" % [item.name, item.base_value, merchant.get_item_count(item.id)])
 if selected_id in item_ids: selection.select(item_ids.find(selected_id))
## GM 共享同一背包；天数调整回写原 GameManager，而非产生第二个时钟。
func open_gm() -> void:
 if is_instance_valid(gm):
  gm.popup_centered()
  return
 gm = Window.new()
 gm.title = "GM 调试 · 共享角色背包"
 gm.size = Vector2i(420, 400)
 add_child(gm)
 var controls = load("res://shop-and-object/scenes/ui/gm_panel.tscn").instantiate()
 controls.setup(inventory)
 gm.add_child(controls)
 controls.day.value_changed.connect(func(value):
  GameManager.current_day = int(value)
  GameManager.time_updated.emit(GameManager.current_day, GameManager.current_period))
 gm.close_requested.connect(gm.hide)
 gm.popup_centered()
## 原游戏保留移动/大陆/时间按键；B 切换面板，E 采集，F3 调试。
func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode == KEY_F3: open_gm()

## 选择为空时不创建报价；buy 指示购买/出售方向。
func trade_selected(buy: bool) -> void:
 if selection.selected < 0 or selection.selected >= item_ids.size():
  feedback.text = "请选择有效物品"
  return
 exchange(buy, item_ids[selection.selected], int(quantity.value))
