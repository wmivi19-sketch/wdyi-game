extends Node
## 单机菜单/存档适配；权威物品与职业仍由原系统持有。
var options: Dictionary = {}
var preferences: Dictionary = {"enabled":true,"bgm":1.0,"sfx":1.0,"fullscreen":false}
var storage_override: Dictionary = {}
var pending: Dictionary = {}
var world_ref: WeakRef
var last_error: String = ""
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
## 创建保存目录并保留可供界面显示的失败原因。
func prepare_storage(path: String) -> bool:
 if not safe_user_path(path):
  last_error = "保存路径无效，必须位于用户数据目录"
  return false
 var directory := ProjectSettings.globalize_path(path.get_base_dir())
 var error := DirAccess.make_dir_recursive_absolute(directory)
 if error != OK:
  last_error = "无法创建保存目录：%s（%s）" % [directory, error_string(error)]
  return false
 return true
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
 if not prepare_storage(path): return false
 var file := ConfigFile.new()
 for key in preferences: file.set_value("menu", key, preferences[key])
 var error := file.save(path)
 if error != OK:
  last_error = "设置无法保存：%s（%s），本次设置仅在当前运行期间生效" % [ProjectSettings.globalize_path(path), error_string(error)]
  return false
 last_error = ""
 return true
## 新开一局，清理旧局运行态，不删除既有磁盘存档；无参数。
func initialize_new_game() -> void:
 pending.clear()
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
 pending = data
 GameManager.current_day = int(data.day)
 GameManager.current_period = int(data.period)
 GameManager.current_continent_id = int(data.continent)
 return true
## 保存真实游戏状态；进行中的合成/仪式/交易必须先结束。
func save_game(path: String = "") -> bool:
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
 if not valid_snapshot(data):
  last_error = "当前状态无法写入有效存档"
  return false
 if path.is_empty(): path = save_path()
 if not prepare_storage(path): return false
 var text := JSON.stringify(data, "  ")
 if text.to_utf8_buffer().size() > int(options.storage.max_save_bytes):
  last_error = "存档超出大小限制"
  return false
 var temporary := path + ".tmp"
 var file := FileAccess.open(temporary, FileAccess.WRITE)
 if file == null:
  last_error = "无法创建存档临时文件：%s（%s）" % [ProjectSettings.globalize_path(temporary), error_string(FileAccess.get_open_error())]
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
 GameState.player_curses.assign(data.curses)
 GameState.curse_added.emit()
 world.player.teleport_to(world.loader.to_global(Vector2(float(data.position[0]),float(data.position[1]))))
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
