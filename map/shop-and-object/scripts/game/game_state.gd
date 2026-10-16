extends Node
signal state_changed
signal profession_changed
signal curse_added
signal curse_removed
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
 current_day = mini(current_day + total / day_length, int(Config.data.days))
 total %= day_length
 current_time = "%02d:%02d" % [total / int(Config.data.minutes_per_hour), total % int(Config.data.minutes_per_hour)]
 state_changed.emit()
## 进入下一天，最后一天保持；无参数。
func next_day() -> void:
 current_day = mini(current_day + 1, int(Config.data.days))
 state_changed.emit()
## 设置位置 new_location。
func change_location(new_location: String) -> void:
 player_location = new_location
 state_changed.emit()
