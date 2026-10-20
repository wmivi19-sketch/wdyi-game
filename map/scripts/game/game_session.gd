extends Node
## 单机菜单/存档适配；权威物品与职业仍由原系统持有。
var options: Dictionary = {}
var preferences: Dictionary = {"enabled":true,"bgm":1.0,"sfx":1.0,"fullscreen":false}
var storage_override: Dictionary = {}
var pending: Dictionary = {}
var world_ref: WeakRef
var last_error: String = ""
const TUTORIAL_SCENE := "res://scenes/TutorialCandleWell.tscn"
var tutorial_pending: Dictionary = {}
var tutorial_ref: WeakRef
var tutorial_completed: bool = false
## 配置启动与偏好读取；无参数。
func _ready() -> void:
 var config := MenuResources.read_config()
 configure_menu(config if not config.is_empty() else MenuResources.defaults())
## 菜单热重载时更新资源/存储路径；override供配置档和测试隔离使用。
func configure_menu(config: Dictionary) -> void:
 var old_path := str(options.get("storage", {}).get("preferences_path", ""))
 options = config.duplicate(true)
 for key in storage_override: options.storage[key] = storage_override[key]
 if old_path != str(options.storage.preferences_path): load_preferences()
## 返回有效存档路径；无参数。
func save_path() -> String:
 return str(options.storage.save_path)
## 仅允许用户数据目录中的路径。
func safe_user_path(path: String) -> bool:
 return path.begins_with("user://") and not ".." in path and path.length() > "user://".length()
## 读取可选偏好，类型非法时保留安全默认值；无参数。
func load_preferences() -> void:
 preferences = {"enabled":true,"bgm":1.0,"sfx":1.0,"fullscreen":false}
 var file := ConfigFile.new()
 if file.load(str(options.storage.preferences_path)) != OK: return
 for key in preferences:
  var value = file.get_value("menu", key, preferences[key])
  if key in ["enabled","fullscreen"]:
   if value is bool: preferences[key] = value
  elif MenuResources.numeric(value): preferences[key] = clampf(float(value), 0.0, 1.0)
## 保存声音/全屏偏好；无参数。
func save_preferences() -> bool:
 var path := str(options.storage.preferences_path)
 if not safe_user_path(path): return false
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 var file := ConfigFile.new()
 for key in preferences: file.set_value("menu", key, preferences[key])
 return file.save(path) == OK
## 新开一局，清理旧局运行态，不删除既有磁盘存档；无参数。
func initialize_new_game() -> void:
 tutorial_pending.clear()
 tutorial_ref = null
 tutorial_completed = false
 pending.clear()
 GameManager.start_new_game()
 for id in ClassManager.players.keys(): ClassManager.unregister_player(id)
 for id in TradeManager.sessions.keys(): TradeManager.cancel_session(id)
 TradeManager.players.clear()
 TradeManager.locations.clear()
 GameManager.current_day = int(Config.data.initial_day)
 GameManager.current_period = GameManager.Period.MORNING
 GameManager.current_continent_id = int(options.storage.new_game_continent)
 GameState.player_inventory = null
 GameState.player_professions.clear()
 GameState.player_curses.clear()
 GameState.current_continent = ""
 GameState.current_area = ""
 GameState.player_location = ""
 GameState.current_map_bounds.clear()
 GameState.current_area_bounds.clear()
 world_ref = null
 last_error = ""
## 新主场景注册真实世界；地图第一次加载结束后再应用存档。
func attach_world(world: Node2D) -> void:
 world_ref = weakref(world)
 if pending.is_empty(): return
 if world.loader.current_data.is_empty(): world.loader.map_loaded.connect(restore_world, CONNECT_ONE_SHOT)
 else: restore_world(str(world.loader.current_data.id))
## 返回仍存活的世界对象；无参数。
func world_node() -> Node:
 return world_ref.get_ref() if world_ref != null else null
## 辅助验证非负整数，避免JSON浮点和布尔混用。
func whole(value: Variant, minimum: int = 0) -> bool:
 return MenuResources.numeric(value) and value >= minimum and float(value) == floor(float(value))
## 只验证数据，不改动库存；counts为快照，slots/weight为目标容量。
func counts_fit(counts: Variant, slots: int, weight: float) -> bool:
 if not counts is Dictionary: return false
 var needed := 0
 var total := 0.0
 for id in counts:
  if not id is String or not whole(counts[id], 1): return false
  var item := ItemDatabase.get_item(id)
  if item == null: return false
  var stack := item.max_stack if item.stackable else 1
  if counts[id] > slots * stack: return false
  needed += ceili(float(counts[id]) / stack)
  total += float(counts[id]) * item.weight
 return needed <= slots and total <= weight
## 校验一次性事件表；flags是字符串到布尔的映射。
func valid_flags(flags: Variant) -> bool:
 if not flags is Dictionary: return false
 for key in flags:
  if not key is String or not flags[key] is bool: return false
 return true
## 验证完整单机存档；拒绝半份数据、失效物品/职业、非法位置和数值。
func valid_snapshot(data: Variant) -> bool:
 if data is Dictionary and data.get("stage", "") == "tutorial_candle_well": return valid_tutorial_snapshot(data)
 if not data is Dictionary or data.get("version") != 1: return false
 if not whole(data.get("day"),1) or data.day > options.storage.max_day or not whole(data.get("period")) or data.period >= GameManager.PERIOD_NAMES.size(): return false
 if not whole(data.get("continent")) or not MapDatabase.continent_configs.has("continent_%d" % int(data.continent)): return false
 if not data.get("position") is Array or data.position.size() != 2: return false
 for coordinate in data.position:
  if not MenuResources.numeric(coordinate): return false
 var map_data := Config.read_json("res://data/maps/continent_%d.json" % int(data.continent))
 if not map_data.has_all(["tile_size","terrain","collision_points"]): return false
 if not MenuResources.numeric(map_data.tile_size) or map_data.tile_size <= 0 or not map_data.terrain is Array or map_data.terrain.is_empty() or not map_data.terrain[0] is Array or not map_data.collision_points is Array: return false
 var tile := float(map_data.tile_size)
 var cell := Vector2i(floori(float(data.position[0]) / tile), floori(float(data.position[1]) / tile))
 if cell.x < 0 or cell.y < 0 or cell.y >= map_data.terrain.size() or cell.x >= map_data.terrain[0].size(): return false
 for blocked in map_data.collision_points:
  if not blocked is Array or blocked.size() != 2 or not MenuResources.numeric(blocked[0]) or not MenuResources.numeric(blocked[1]): return false
  if int(blocked[0]) == cell.x and int(blocked[1]) == cell.y: return false
 if not counts_fit(data.get("inventory"), int(Config.data.slots), float(Config.data.max_weight)): return false
 var integration := Config.read_json("res://shop-and-object/resources/integration.json")
 if integration.is_empty() or not counts_fit(data.get("merchant"), int(integration.merchant_slots), float(integration.merchant_max_weight)): return false
 if not data.get("classes") is Array or data.classes.is_empty() or data.classes.size() > ClassManager.MAX_CLASSES: return false
 var seen: Dictionary = {}
 for id in data.classes:
  if not id is String or not ClassManager.classes.has(id) or seen.has(id): return false
  seen[id] = true
 if not data.get("deity") is String or (not data.deity.is_empty() and not ClassManager.deities.has(data.deity)): return false
 if not data.deity.is_empty() and data.classes.size() != ClassManager.MAX_CLASSES: return false
 if not data.get("base_stats") is Dictionary or not MenuResources.numeric(data.base_stats.get("max_hp")) or data.base_stats.max_hp <= 0: return false
 for value in data.base_stats.values():
  if not MenuResources.numeric(value) or value < 0: return false
 var maximum := float(data.base_stats.max_hp)
 for id in data.classes: maximum += float(ClassManager.classes[id].stat_bonuses.get("max_hp",0.0))
 if not data.deity.is_empty(): maximum += float(data.base_stats.max_hp) * (ClassManager.deities[data.deity].base_hp_multiplier - 1.0)
 if not is_finite(maximum) or maximum <= 0: return false
 if not MenuResources.numeric(data.get("hp")) or data.hp < 0 or data.hp > maximum or (data.hp == 0 and not data.deity.is_empty()): return false
 if not valid_flags(data.get("depleted")) or not valid_flags(data.get("claimed_events")) or not data.get("curses") is Array: return false
 for id in data.curses:
  if not id is String or id.is_empty(): return false
 if data.has("combat") and not valid_combat(data.combat, data, maximum): return false
 return true

## 可选战斗快照：旧版存档没有此字段仍然有效。
func valid_combat(combat: Variant, save: Dictionary, maximum: float) -> bool:
 if not combat is Dictionary or not whole(combat.get("phase")) or combat.phase > 1: return false
 if not combat.get("players") is Array or combat.players.size() != 6: return false
 if combat.phase == 1 and (save.day != 14 or save.period != 2 or save.continent != 5): return false
 for id in range(6):
  var state = combat.players[id]
  if not state is Dictionary or not whole(state.get("profession")) or state.profession > 5: return false
  if not state.get("placed", false) is bool: return false
  if not state.get("continent_id") is String or state.continent_id not in ["forest","desert","snow","volcano","swamp","mountain","end_continent"]: return false
  if not state.get("position") is Array or state.position.size() != 2: return false
  for coordinate in state.position:
   if not MenuResources.numeric(coordinate) or absf(float(coordinate)) > 100000.0: return false
  for key in ["hp","max_hp","stamina","mana","delay"]:
   if not MenuResources.numeric(state.get(key)) or state[key] < 0 or state[key] > 1000000.0: return false
  if state.max_hp <= 0 or state.hp > state.max_hp: return false
  var stamina_max := 140.0 if state.profession == 1 else (80.0 if state.profession == 3 else 100.0)
  var mana_max := 60.0 if state.profession == 1 else (200.0 if state.profession == 3 else 100.0)
  if state.stamina > stamina_max or state.mana > mana_max: return false
  if id == 0 and (not is_equal_approx(float(state.hp), float(save.hp)) or not is_equal_approx(float(state.max_hp), maximum)): return false
  if id == 0:
   var expected_profession := 3 if save.classes.back() == "mage" else (2 if save.classes.back() == "ranger" else 1)
   if state.profession != expected_profession: return false
   var expected_continent: String = "end_continent" if combat.phase == 1 else str(GameManager.CONTINENTS[int(save.continent)].id)
   if state.hp > 0 and state.continent_id != expected_continent: return false
  if combat.phase == 1 and state.hp > 0 and state.continent_id != "end_continent": return false
  if not state.get("cooldowns") is Dictionary: return false
  for slot in state.cooldowns:
   if slot not in ["Q","W","E","R"] or not MenuResources.numeric(state.cooldowns[slot]) or state.cooldowns[slot] < 0 or state.cooldowns[slot] > 1000000: return false
  if not state.get("effects") is Array or state.effects.size() > 64: return false
  for effect in state.effects:
   if not effect is Dictionary or not effect.get("id") is String or effect.id.is_empty() or not effect.get("stun") is bool: return false
   if not MenuResources.numeric(effect.get("remaining")) or effect.remaining <= 0 or effect.remaining > 1000000: return false
   for property in ["damage_bonus","damage_reduction","speed_bonus","stamina_regen_bonus","mana_regen_bonus"]:
    if not MenuResources.numeric(effect.get(property)) or absf(float(effect[property])) > 1000000: return false
 return true
## 读取校验存档；不会修改当前游戏和pending。
func read_snapshot(path: String = "") -> Dictionary:
 if path.is_empty(): path = save_path()
 if not safe_user_path(path) or not FileAccess.file_exists(path):
  last_error = "没有可用存档"
  return {}
 var file := FileAccess.open(path, FileAccess.READ)
 if file == null or file.get_length() > int(options.storage.max_save_bytes):
  last_error = "存档无法读取或文件过大"
  return {}
 var parser := JSON.new()
 if parser.parse(file.get_as_text()) != OK or not valid_snapshot(parser.data):
  last_error = "存档损坏或与当前配置不兼容"
  return {}
 last_error = ""
 return parser.data.duplicate(true)
## 继续按钮检测的是完整有效存档，不是仅看文件存在。
func has_valid_save(path: String = "") -> bool:
 return not read_snapshot(path).is_empty()
## 准备恢复数据，场景尚未创建时只同步地图/时钟，失败不修改状态。
func load_game(path: String = "") -> bool:
 var data := read_snapshot(path)
 if data.is_empty(): return false
 if data.get("stage", "") == "tutorial_candle_well":
  initialize_new_game()
  tutorial_pending = data
  return true
 tutorial_pending.clear()
 tutorial_ref = null
 tutorial_completed = true
 GameManager.start_new_game()
 pending = data
 GameManager.current_day = mini(int(data.day), GameManager.TOTAL_DAYS)
 GameManager.current_period = int(data.period)
 GameManager.current_continent_id = int(data.continent)
 return true
## 保存真实游戏状态；进行中的合成/仪式/交易必须先结束。
func save_game(path: String = "") -> bool:
 var tutorial: Node = tutorial_ref.get_ref() if tutorial_ref != null else null
 if is_instance_valid(tutorial): return write_tutorial_snapshot(tutorial.tutorial_snapshot(), path)
 var world := world_node()
 if world == null:
  last_error = "当前没有运行中的游戏"
  return false
 var bridge = world.get_node("WorldItems")
 if CraftingSystem.busy.has(bridge.inventory) or ClassManager.active.has(1) or not TradeManager.sessions.is_empty():
  last_error = "请先结束合成、仪式或交易后再保存"
  return false
 var state = ClassManager.players.get(1)
 if state == null: return false
 var actual := MapDatabase.continent_for_map(str(world.loader.current_data.get("id","")))
 if actual.is_empty():
  last_error = "当前地图尚未完成有效加载"
  return false
 var continent := int(actual.trim_prefix("continent_"))
 var position_value: Vector2 = world.loader.to_local(world.player.global_position)
 var data := {"version":1,"day":GameManager.current_day,"period":GameManager.current_period,"continent":continent,"position":[position_value.x,position_value.y],"inventory":bridge.inventory.snapshot(),"merchant":bridge.merchant.snapshot(),"classes":state.class_ids.duplicate(),"deity":state.deity.deity_id if state.deity != null else "","base_stats":state.base_stats.duplicate(),"hp":world.player.hp,"depleted":bridge.depleted.duplicate(),"claimed_events":world.progression_world.claimed_events.duplicate(),"curses":GameState.player_curses.duplicate()}
 data["combat"] = GameManager.export_combat()
 if not valid_snapshot(data):
  last_error = "当前状态无法写入有效存档"
  return false
 if path.is_empty(): path = save_path()
 if not safe_user_path(path): return false
 var text := JSON.stringify(data, "  ")
 if text.to_utf8_buffer().size() > int(options.storage.max_save_bytes): return false
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 var temporary := path + ".tmp"
 var file := FileAccess.open(temporary, FileAccess.WRITE)
 if file == null:
  last_error = "无法创建存档临时文件"
  return false
 file.store_string(text)
 file.flush()
 var error := file.get_error()
 file.close()
 if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
  last_error = "存档写入失败，原存档未删除"
  return false
 last_error = ""
 return true
## 地图就绪后一次应用已验证快照；map_id为载入信号参数。
func restore_world(_map_id: String) -> void:
 var world := world_node()
 if world == null or pending.is_empty(): return
 var data := pending.duplicate(true)
 if not valid_snapshot(data):
  last_error = "配置在转场期间变化，存档无法恢复"
  pending.clear()
  call_deferred("return_to_menu", false)
  return
 var bridge = world.get_node("WorldItems")
 bridge.inventory.commit(data.inventory, false)
 bridge.merchant.commit(data.merchant, false)
 bridge.depleted = data.depleted.duplicate()
 world.progression_world.harvested = data.depleted.duplicate()
 world.progression_world.claimed_events = data.claimed_events.duplicate()
 var state = ClassManager.players[1]
 state.class_ids.assign(data.classes)
 state.base_stats = data.base_stats.duplicate()
 state.deity = ClassManager.deities[data.deity].duplicate(true) if not data.deity.is_empty() else null
 ClassManager._rebuild(1)
 world.player.hp = float(data.hp)
 world.player.health_changed.emit(world.player.hp, float(world.player.stats.max_hp))
 if data.has("combat"): GameManager.restore_combat(data.combat)
 GameState.player_curses.assign(data.curses)
 GameState.curse_added.emit()
 world.player.teleport_to(world.loader.to_global(Vector2(float(data.position[0]),float(data.position[1]))))
 if world.has_node("MapCombat"): world.get_node("MapCombat").refresh_visibility()
 for marker in world.loader.resource_points.get_children():
  marker.visible = not bridge.depleted.has(str(world.loader.current_data.id) + ":" + str(marker.get_meta("map_data").id))
 bridge.inventory.publish()
 bridge.merchant.publish()
 world.progression_world.inventory_changed.emit()
 pending.clear()
 last_error = ""
## 保存反馈入口，供键盘及统一面板共用；无参数。
func quick_save_feedback() -> void:
 var success := save_game()
 var world := world_node()
 if world != null: world.get_node("WorldItems").feedback.text = "游戏已保存" if success else last_error
## 保存后返回菜单；save_first为false时仅用于恢复失败回退。
func return_to_menu(save_first: bool = true) -> bool:
 if save_first and not save_game():
  quick_error_feedback()
  return false
 var path := str(options.navigation.menu_scene)
 if not ResourceLoader.exists(path) or not ResourceLoader.load(path) is PackedScene:
  last_error = "主菜单场景不可用"
  quick_error_feedback()
  return false
 get_tree().call_deferred("change_scene_to_file", path)
 return true
## 将错误显示到现有游戏反馈栏；无参数。
func quick_error_feedback() -> void:
 var world := world_node()
 if world != null: world.get_node("WorldItems").feedback.text = last_error

## Independent tutorial save branch; continent saves and continent IDs stay unchanged.
func valid_tutorial_snapshot(data: Dictionary) -> bool:
 if data.has("glass_broken"):
  if not data.glass_broken is Dictionary: return false
  for key in data.glass_broken:
   if key not in ["GL1","GL2","GL3"] or not data.glass_broken[key] is bool or not data.glass_broken[key]: return false
 if data.get("version") != 1 or data.get("stage") != "tutorial_candle_well": return false
 if not whole(data.get("level")) or data.level > 2: return false
 if not data.get("position") is Array or data.position.size()!=2: return false
 for value in data.position:
  if not MenuResources.numeric(value) or value<5 or value>1019: return false
 var compact: bool = data.get("layout_revision","")=="reference-compact-v1"
 var definitions := Config.read_json("res://tutorial/candle_well/assets/dungeon.json" if compact else "res://tutorial/candle_well/assets/dungeon_legacy64.json")
 if definitions.is_empty(): return false
 var walkable: Dictionary = {}
 for p in definitions.levels[int(data.level)].walkable: walkable[Vector2i(int(p[0]),int(p[1]))] = true
 var point := Vector2(float(data.position[0]),float(data.position[1]))
 for offset in [Vector2(-5,-5),Vector2(5,-5),Vector2(-5,5),Vector2(5,5)]:
  var p: Vector2 = point+offset
  if not walkable.has(Vector2i(floori(p.x/16.0),floori(p.y/16.0))): return false
 for entry in [["opened",["G1","G2","G3","G4"]],["broken",["B1","B2","B3","B4"]],["collected",["C1","C2","C3","C4","C5"]]]:
  if not data.get(entry[0]) is Dictionary: return false
  for key in data[entry[0]]:
   if key not in entry[1] or not data[entry[0]][key] is bool or not data[entry[0]][key]: return false
 if not data.get("hits") is Dictionary or not data.get("returned_via_sky") is bool: return false
 for key in data.hits:
  if key not in ["B1","B2","B3","B4"] or not whole(data.hits[key]) or data.hits[key]>3: return false
 for key in data.broken:
  if data.hits.get(key,0)!=3: return false
 if data.has("continuous_height"):
  if not MenuResources.numeric(data.continuous_height) or data.continuous_height<0 or data.continuous_height>256: return false
  if not data.get("continuous_stairs") is bool: return false
  if not data.continuous_stairs and absf(float(data.continuous_height)-float(data.level)*128)>0.1: return false
 if data.has("spiral_route"):
  var route = data.spiral_route
  if not route is Dictionary or not route.get("tracking") is bool: return false
  if not whole(route.get("direction"),-1) or route.direction>1: return false
  for key in ["progress","last_angle"]:
   if not MenuResources.numeric(route.get(key)) or route[key]<0 or route[key]>TAU: return false
  if route.tracking:
   var center := Vector2(512,256) if compact else Vector2(512,512)
   if point.distance_to(center)<50 or point.distance_to(center)>116: return false
   if route.direction==0 and route.progress!=0: return false
   if absf(wrapf((point-center).angle()-float(route.last_angle),-PI,PI))>0.3: return false
 for o in definitions.levels[int(data.level)].objects:
  if o.type=="gate" and not data.opened.has(o.id):
   var r: Array = o.rect
   var gate := Rect2(float(r[0])*16,float(r[1])*16,float(r[2])*16,float(r[3])*16).grow(5)
   if gate.has_point(point): return false
 return true

## Uses the existing save slot atomically; starting a new game still preserves its old disk save.
func write_tutorial_snapshot(data: Dictionary, path: String = "") -> bool:
 if not valid_tutorial_snapshot(data):
  last_error = "新手关状态无效，未覆盖存档"
  return false
 if path.is_empty(): path = save_path()
 if not safe_user_path(path): return false
 var text := JSON.stringify(data,"  ")
 if text.to_utf8_buffer().size()>int(options.storage.max_save_bytes): return false
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null:
  last_error = "无法创建新手关存档"
  return false
 file.store_string(text)
 file.flush()
 var error := file.get_error()
 file.close()
 if error!=OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))!=OK:
  last_error = "新手关存档写入失败，原存档保留"
  return false
 last_error = ""
 return true
