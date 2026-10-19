extends "../../radial_ui_demo/radial_ui.gd"
## Presentation adapter only: gameplay mutations go through the original systems.
var source: Node
var host: Control
var legacy_controls: Array[Control] = []
var return_button: Button
var selected_item_id := ""
var recipe_id := ""
var dirty := true
var elapsed := 0.0

func bind(items: Node) -> void:
 source = items
 host = items.panel
 for child in host.get_children():
  if child is Control:
   legacy_controls.append(child)
   child.hide()

func _ready() -> void:
 super._ready()
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 source.inventory.inventory_changed.connect(mark_dirty)
 ItemDatabase.database_reloaded.connect(mark_dirty)
 GameState.state_changed.connect(mark_dirty)
 ClassManager.form_changed.connect(_form_changed)
 source.world.progression_world.message.connect(_notice)
 ClassManager.notice.connect(_class_notice)
 ClassManager.ritual_ended.connect(_ritual_ended)
 host.visibility_changed.connect(_host_visibility_changed)
 return_button = Button.new()
 return_button.name = "ReturnToRadial"
 return_button.text = "返回环形界面"
 return_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
 return_button.position = Vector2(host.size.x - 240, host.size.y - 52)
 return_button.size = Vector2(190, 40)
 return_button.pressed.connect(show_radial)
 host.add_child(return_button)
 return_button.hide()
 message.text = "Tab/B 或 Esc 关闭 · 1–4 切换模块 · T 切换主题 · F5 保存"

func _build() -> void:
 super._build()
 (canvas.get_child(0) as Label).text = "逐 神 终 焉    /    旅 者 星 环"
 theme_button.position.x = 790
 theme_button.size.x = 220
 var close := Button.new()
 close.name = "Close"
 close.text = "关闭"
 close.position = Vector2(1020, 26)
 close.size = Vector2(70, 48)
 close.pressed.connect(host.close_panel)
 canvas.add_child(close)
 var legacy := Button.new()
 legacy.name = "Legacy"
 legacy.text = "商店 / 存档 / 原职业面板"
 legacy.position = Vector2(38, 610)
 legacy.size = Vector2(330, 44)
 legacy.pressed.connect(show_legacy)
 canvas.add_child(legacy)

func mark_dirty() -> void:
 dirty = true

func _form_changed(_id: int, _form: Dictionary) -> void:
 mark_dirty()

func _notice(text: String) -> void:
 message.text = text
 mark_dirty()

func _class_notice(id: int, text: String) -> void:
 if id == 1: _notice(text)

func _ritual_ended(id: int, _ritual: String, success: bool, reason: String) -> void:
 if id == 1: _notice("仪式成功" if success else reason)

func _host_visibility_changed() -> void:
 if host.visible:
  show_radial()

func show_legacy() -> void:
 hide()
 for child in legacy_controls: child.show()
 return_button.show()
 host._update_page_positions()
 host.refresh_data()

func show_radial() -> void:
 for child in legacy_controls: child.hide()
 if is_instance_valid(return_button): return_button.hide()
 show()
 _select(active)

func _process(delta: float) -> void:
 if not is_visible_in_tree(): return
 elapsed += delta
 if elapsed < 0.25: return
 elapsed = 0.0
 # Resource pools regenerate continuously. Only stats need periodic rebuilding.
 if dirty or active == 2:
  dirty = false
  var scroll := detail_scroll.scroll_vertical
  _select(active)
  detail_scroll.set_deferred("scroll_vertical", scroll)

func _select(index: int) -> void:
 super._select(index)
 if source == null: return
 var names: Array[String] = []
 for id in GameState.player_professions:
  var data: Dictionary = ProfessionDatabase.get_profession(id)
  names.append(str(data.get("name", id)))
 center_info.text = "%s\nHP %.0f / %.0f" % [" / ".join(names), source.world.player.hp, source.world.player.stats.max_hp]
 center_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 center_info.add_theme_font_size_override("font_size", 14)
 (detail.get_child(1) as Label).text = ["共享背包 · 点击物品查看详情", "原有配方 · 原子扣料与容量校验", "实时战斗资源与职业属性", "职业印记 → 祭坛仪式 → 技能成长"][active]

func _inventory() -> void:
 var bag: Inventory = source.inventory
 label("承重 %.2f / %.2f  ·  %d 格" % [bag.current_weight, bag.max_weight, bag.items.size()])
 var grid := GridContainer.new()
 grid.name = "Slots"
 grid.columns = 4
 detail.add_child(grid)
 for i in bag.items.size():
  var slot: InventorySlot = bag.items[i]
  var button := Button.new()
  button.name = "Slot%d" % i
  button.custom_minimum_size = Vector2(92, 72)
  grid.add_child(button)
  button.disabled = slot.is_empty()
  if slot.is_empty():
   button.text = "·"
   continue
  var item := ItemDatabase.get_item(slot.item_id)
  button.text = "%s\n×%d" % [item.name if item != null else slot.item_id, slot.count]
  button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  button.tooltip_text = item.description if item != null else slot.item_id
  button.icon = _item_icon(slot.item_id)
  button.add_theme_constant_override("icon_max_width", 16)
  button.expand_icon = true
  button.pressed.connect(_inspect.bind(slot.item_id))
 var selected := ItemDatabase.get_item(selected_item_id)
 if selected != null and bag.has_item(selected_item_id, 1):
  label("%s\n%s\n重量 %.2f · 价值 %d" % [selected.name, selected.description, selected.weight, selected.base_value])
 else:
  label("选择物品查看详情；交易请打开下方商店入口。")

func _item_icon(id: String) -> Texture2D:
 var item := ItemDatabase.get_item(id)
 if item != null and not item.icon_path.is_empty():
  return AssetManager.get_item_icon(id, item.icon_path)
 return Art.texture("herb" if id == "herb" else "ore")

func _inspect(id: String) -> void:
 selected_item_id = id
 _select(active)

func _crafting() -> void:
 for recipe in CraftingSystem.recipes.values():
  action(("▶ " if recipe_id == recipe.id else "") + recipe.name, _pick_recipe.bind(recipe.id))
 var recipe: Recipe = CraftingSystem.recipes.get(recipe_id)
 if recipe != null:
  label("所需材料")
  for ingredient in recipe.inputs:
   label("%s  %d / %d" % [_item_name(ingredient.item_id), source.inventory.get_item_count(ingredient.item_id), int(ingredient.count)])
  if not recipe.catalyst_id.is_empty(): label("催化剂：" + _item_name(recipe.catalyst_id))
  var preview := TextureRect.new()
  preview.texture = _item_icon(recipe.output_item_id)
  preview.custom_minimum_size = Vector2(48, 48)
  preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  detail.add_child(preview)
  label("产物：%s ×%d\n成功率 %.0f%% · 耗时 %.1f 秒\n日期 %s · %s–%s\n地点 %s · 职业 %s" % [_item_name(recipe.output_item_id), recipe.output_count, recipe.success_rate * 100, recipe.craft_time, str(recipe.required_day) if recipe.required_day > 0 else "不限", recipe.time_start, recipe.time_end, recipe.required_location if not recipe.required_location.is_empty() else "不限", recipe.required_profession if not recipe.required_profession.is_empty() else "不限"])
  action("合成所选配方", _craft_game.bind(recipe.id), source.world.player.hp > 0 and CraftingSystem.can_craft(recipe.id, source.inventory))
 else:
  label("选择上方配方查看材料和结果。")
 label("职业印记合成")
 action("法师印记：矿石 ×3 + 药草 ×2", _craft_mark.bind("mage_recipe"))
 action("游侠印记：木材 ×3 + 药草 ×2", _craft_mark.bind("ranger_recipe"))

func _item_name(id: String) -> String:
 var item := ItemDatabase.get_item(id)
 return item.name if item != null else id

func _pick_recipe(id: String) -> void:
 if not CraftingSystem.recipes.has(id): return
 recipe_id = id
 _select(active)

func _craft_game(id: String) -> void:
 if source.world.player.hp <= 0: return
 message.text = "正在合成…"
 var result: Dictionary = await CraftingSystem.attempt_craft(id, source.inventory)
 if not is_inside_tree(): return
 _notice(str(result.message))

func _craft_mark(id: String) -> void:
 source.world.progression_world.craft(id)
 mark_dirty()

func _stats() -> void:
 var actor = source.world.player
 var combatant = GameManager.get_combatant(0)
 var pool = combatant.resources
 _bar("生命", roundi(actor.hp), roundi(pool.max_hp), Color("bd5246"))
 _bar("体力", roundi(pool.stamina), roundi(pool.max_stamina), Color("77aa59"))
 _bar("法力", roundi(pool.mana), roundi(pool.max_mana), Color("83c9ca"))
 label("攻击  %s\n伤害减免  %.0f%%" % [actor.stats.get("attack", 0), combatant.modifier(&"damage_reduction") * 100])
 label("第 %d 天 · %s\n所在大陆 %d\n职业技能：%s" % [GameState.current_day, GameState.current_time, GameManager.current_continent_id + 1, " / ".join(actor.skill_ids)])

func _skills() -> void:
 for id in GameState.player_professions:
  var data: Dictionary = ProfessionDatabase.get_profession(id)
  label(str(data.get("name", id)), true)
  label("技能：" + " / ".join(data.get("skills", [])))
 label("战斗技能配置")
 var combatant = GameManager.get_combatant(0)
 for key in ["q", "w", "e", "r"]:
  var skill = combatant.get(key)
  if skill != null: label("%s  /  %s" % [key.to_upper(), skill.title])
 label("法师/游侠：对应大陆夜晚，在祭坛使用职业印记。\n三职业后，第12–14天可在终焉祭坛成神。\n技能随仪式成长，当前游戏未提供自由加点。")
 action("附近交互 / 祭坛仪式", source.world.progression_world.interact, source.world.player.hp > 0)
 action("打开原职业与仪式详情", _open_profession)

func _open_profession() -> void:
 show_legacy()
 host.switch_to_page(1)

func _input(event: InputEvent) -> void:
 if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
 if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
 if event.keycode == KEY_T:
  _next_theme()
 elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
  _select(event.keycode - KEY_1)
 else:
  return # Existing Tab/B/Esc, map, save, and debug handlers retain ownership.
 get_viewport().set_input_as_handled()

func _unhandled_key_input(_event: InputEvent) -> void:
 pass # Never activate demo shortcuts while the game's window is closed.
