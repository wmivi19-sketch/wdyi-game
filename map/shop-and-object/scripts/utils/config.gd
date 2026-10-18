extends Node
signal reloaded
var data: Dictionary = {}
var elapsed: float = 0.0
var fingerprint: String = ""
## 初始化配置；无参数。
func _ready() -> void:
 reload()
 fingerprint = signature()
## 读取 JSON 对象；path 为 res://shop-and-object/ 路径，错误时保留调用方原数据。
func read_json(path: String) -> Dictionary:
 if not FileAccess.file_exists(path):
  push_warning("配置不存在：" + path)
  return {}
 var parser := JSON.new()
 if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
  push_warning("JSON 格式错误：" + path)
  return {}
 return parser.data
## 原子替换通用配置；无参数。
func reload() -> void:
 var candidate := read_json("res://shop-and-object/resources/settings.json")
 if not validate(candidate):
  push_warning("通用配置校验失败，保留上一版本")
  return
 data = candidate
 reloaded.emit()
## 验证完整字段、类型及边界；candidate 是待提交配置，不修改有效数据。
func validate(candidate: Dictionary) -> bool:
 var integers := ["slots", "days", "initial_day", "minutes_per_day", "minutes_per_hour", "icon_size", "test_count", "gm_max_count", "probability_trials"]
 for key in integers:
  if not candidate.has(key) or not numeric(candidate[key]): return false
  if float(candidate[key]) <= 0 or floor(float(candidate[key])) != float(candidate[key]): return false
 for key in ["max_weight", "poll_seconds", "probability_tolerance", "seed"]:
  if not candidate.has(key) or not numeric(candidate[key]): return false
 if candidate.max_weight < 0 or candidate.poll_seconds <= 0: return false
 if candidate.probability_tolerance <= 0 or candidate.probability_tolerance > 1: return false
 if candidate.initial_day > candidate.days or candidate.test_count > candidate.gm_max_count: return false
 if floor(float(candidate.seed)) != float(candidate.seed): return false
 for key in ["initial_time", "initial_location", "test_item"]:
  if not candidate.get(key) is String: return false
 var parts: PackedStringArray = candidate.initial_time.split(":")
 if parts.size() != 2 or parts[0].length() != 2 or parts[1].length() != 2: return false
 if not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
 var hour := int(parts[0])
 var minute := int(parts[1])
 if hour < 0 or minute < 0 or minute >= candidate.minutes_per_hour: return false
 if hour * candidate.minutes_per_hour + minute >= candidate.minutes_per_day: return false
 if not candidate.get("initial_professions") is Array: return false
 for profession in candidate.initial_professions:
  if not profession is String: return false
 if not candidate.get("rarity_colors") is Array or candidate.rarity_colors.is_empty(): return false
 for color in candidate.rarity_colors:
  if not color is String or not Color.html_is_valid(color): return false
 return true
## 只接受有限数字，拒绝布尔、字符串及非有限值；value 为待验证字段。
func numeric(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))
## 列出目录中的 JSON；folder 为目录路径。
func files(folder: String) -> Array[String]:
 var result: Array[String] = []
 for name in DirAccess.get_files_at(folder):
  if name.ends_with(".json"): result.append(folder.path_join(name))
 result.sort()
 return result
## 内容哈希能检测新增、删除和同时间戳修改；无参数。
func signature() -> String:
 var value := ""
 for folder in ["res://shop-and-object/resources", "res://shop-and-object/resources/items", "res://shop-and-object/resources/recipes", "res://shop-and-object/resources/trading"]:
  for path in files(folder): value += path + FileAccess.get_file_as_string(path)
 return value.sha256_text()
## 按配置周期监视文件；delta 为帧耗时。
func _process(delta: float) -> void:
 elapsed += delta
 if elapsed < float(data.get("poll_seconds", 1.0)): return
 elapsed = 0.0
 var latest := signature()
 if latest != fingerprint:
  fingerprint = latest
  reload()
  AssetManager.clear_cache()
  ItemDatabase.reload()
  CraftingSystem.reload()
  TradeManager.reload()
