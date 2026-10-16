class_name Recipe
extends Resource
@export var id: String
@export var name: String
@export var output_item_id: String
@export var output_count: int
@export var inputs: Array[Dictionary]
@export var catalyst_id: String
@export var required_day: int
@export var time_start: String
@export var time_end: String
@export var required_location: String
@export var required_profession: String
@export var success_rate: float
@export var failure_output_id: String
@export var craft_time: float

## 返回独立的配方内容快照，用于等待期间版本比较；无参数。
func definition() -> Dictionary:
 var result: Dictionary = {}
 for key in ["id", "name", "output_item_id", "output_count", "inputs", "catalyst_id", "required_day", "time_start", "time_end", "required_location", "required_profession", "success_rate", "failure_output_id", "craft_time"]:
  result[key] = get(key)
 return result.duplicate(true)
