extends Node
signal continent_switched(continent_id: int)
signal time_updated(day: int, period: int)
enum Period { MORNING, NOON, EVENING }
const PERIOD_NAMES: Array[String] = ["早", "中", "晚"]
var current_day: int = 1
var current_period: int = Period.MORNING
var current_continent_id: int = 0

func switch_to_continent(continent_id: int) -> void:
	if continent_id < 0 or continent_id > 5:
		push_warning("大陆 ID 必须为 0..5")
		return
	current_continent_id = continent_id
	continent_switched.emit(continent_id)

func next_time_period() -> void:
	current_period += 1
	if current_period > Period.EVENING:
		current_period = Period.MORNING
		current_day += 1
	time_updated.emit(current_day, current_period)