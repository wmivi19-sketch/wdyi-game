extends Node
signal state_changed
signal profession_changed
signal curse_added
signal curse_removed
## 统一通知外部系统已完成职业同步。
func notify_profession_changed() -> void:
 profession_changed.emit()

var player_inventory: Inventory
var player_curses: Array[String] = []
## id 为诅咒标识；UI 展示接口，不改变战斗数值。
func add_curse(id: String) -> void:
 if id.is_empty() or id in player_curses: return
 player_curses.append(id)
 curse_added.emit()
## 移除 id 对应的展示条目。
func remove_curse(id: String) -> void:
 if id not in player_curses: return
 player_curses.erase(id)
 curse_removed.emit()

var current_day: int
var current_time: String
var player_location: String
var player_professions: Array[String] = []
## 初始化全局上下文；无参数。
func _ready() -> void:
 current_day = int(Config.data.initial_day)
 current_time = Config.data.initial_time
 player_location = Config.data.initial_location
 player_professions.assign(Config.data.initial_professions)
## 解析 HH:MM；text 为时间文本。
func minutes(text: String) -> int:
 var parts := text.split(":")
 return int(parts[0]) * int(Config.data.minutes_per_hour) + int(parts[1])
## 推进非负 minutes_count 分钟，周期末停止。
func advance_time(minutes_count: int) -> void:
 if minutes_count < 0: return
 var total := minutes(current_time) + minutes_count
 var day_length := int(Config.data.minutes_per_day)
 current_day = mini(current_day + floori(float(total) / day_length), int(Config.data.days))
 total %= day_length
 current_time = "%02d:%02d" % [floori(float(total) / int(Config.data.minutes_per_hour)), total % int(Config.data.minutes_per_hour)]
 state_changed.emit()
## 进入下一天，最后一天保持；无参数。
func next_day() -> void:
 current_day = mini(current_day + 1, int(Config.data.days))
 state_changed.emit()
## 设置位置 new_location。
func change_location(new_location: String) -> void:
 player_location = new_location
 state_changed.emit()

# 地图区域与合成/交易的 player_location 分离，避免把祭坛位置替换成区域名。
signal map_context_changed
signal player_position_changed(position: Vector2)
var player_node: Node2D = null
var player_world_position: Vector2 = Vector2.ZERO
var current_continent: String = ""
var current_area: String = ""
var current_map_bounds: Dictionary = {}
var current_area_bounds: Dictionary = {}
## position_value 是实际场景全局坐标；只在位置改变时发信号。
func update_player_position(position_value: Vector2) -> void:
 if player_world_position == position_value: return
 player_world_position = position_value
 player_position_changed.emit(position_value)
## continent_id 来自实际加载地图；不会请求或执行传送。
func change_continent(continent_id: String) -> void:
 if current_continent == continent_id: return
 current_continent = continent_id
 map_context_changed.emit()
## area_id 是地图区域 ID，不覆盖用于合成/交易的 player_location。
func change_area(area_id: String) -> void:
 if current_area == area_id: return
 current_area = area_id
 map_context_changed.emit()

## 主菜单的新游戏入口；保留磁盘存档，由GameSession重置运行状态。
func initialize_new_game() -> void:
 GameSession.initialize_new_game()
## 主菜单继续入口；path为空使用菜单配置的存档路径。
func load_game(path: String = "") -> bool:
 return GameSession.load_game(path)
