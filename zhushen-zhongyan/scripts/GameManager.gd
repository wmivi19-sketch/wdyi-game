extends Node
## Autoload: GameManager. Time advances only after the strategy layer calls
## advance_period(). All public state queries return detached snapshots.

signal game_started
signal period_changed(day: int, period: int)
signal day_finished(day: int)
signal player_changed(player_id: int)
signal health_changed(player_id: int, health: int, maximum: int)
signal player_died(player_id: int)
signal inventory_changed(player_id: int, inventory: Dictionary)
signal endgame_started
signal player_teleported(player_id: int, continent_id: String, position: Vector2)

enum Period { MORNING, NOON, EVENING }
enum Phase { SURVIVAL, ENDGAME }
enum Profession { UNASSIGNED, WARRIOR, RANGER, MAGE, GATHERER, HEALER }

const TOTAL_DAYS: int = 14
const PLAYER_COUNT: int = 6
const HUMAN_PLAYER_ID: int = 0
const END_CONTINENT_ID: String = "end_continent"
const PERIOD_NAMES: Array[String] = ["早", "中", "晚"]
const PROFESSION_NAMES: Array[String] = ["未选择", "战士", "游侠", "法师", "采集者", "治疗者"]
const CONTINENTS: Array[Dictionary] = [
	{"id": "forest", "name": "苍翠大陆", "terrain": "森林", "spawn": Vector2(120, 180)},
	{"id": "desert", "name": "流沙大陆", "terrain": "沙漠", "spawn": Vector2(480, 180)},
	{"id": "snow", "name": "霜雪大陆", "terrain": "雪原", "spawn": Vector2(840, 180)},
	{"id": "volcano", "name": "熔火大陆", "terrain": "火山", "spawn": Vector2(120, 440)},
	{"id": "swamp", "name": "迷雾大陆", "terrain": "沼泽", "spawn": Vector2(480, 440)},
	{"id": "mountain", "name": "峭峰大陆", "terrain": "山地", "spawn": Vector2(840, 440)},
]
const END_SPAWNS: Array[Vector2] = [
	Vector2(240, 200), Vector2(520, 200), Vector2(800, 200),
	Vector2(240, 440), Vector2(520, 440), Vector2(800, 440),
]

var current_day: int = 1
var current_period: Period = Period.MORNING
var phase: Phase = Phase.SURVIVAL
var _players: Dictionary = {}
var _bodies: Dictionary = {}
var _advancing: bool = false
var _initializing: bool = false


func _ready() -> void:
	start_new_game()


func start_new_game() -> void:
	# Reject synchronous reset attempts from transition signal listeners.
	if _advancing or _initializing:
		return
	_initializing = true
	current_day = 1
	current_period = Period.MORNING
	phase = Phase.SURVIVAL
	_players.clear()
	for id in range(PLAYER_COUNT):
		var continent: Dictionary = CONTINENTS[id]
		_players[id] = {
			"id": id, "name": "玩家" if id == HUMAN_PLAYER_ID else "AI %d" % id,
			"is_ai": id != HUMAN_PLAYER_ID,
			"home_continent_id": continent["id"], "continent_id": continent["id"],
			"spawn_position": continent["spawn"], "position": continent["spawn"],
			"profession": Profession.UNASSIGNED, "profession_status": {},
			"max_health": 100, "health": 100, "alive": true, "inventory": {},
		}
		_place_registered_body(id, continent["spawn"])
	game_started.emit()
	period_changed.emit(current_day, current_period)
	for id in range(PLAYER_COUNT):
		health_changed.emit(id, _players[id]["health"], _players[id]["max_health"])
		inventory_changed.emit(id, _players[id]["inventory"].duplicate(true))
		player_changed.emit(id)
	_initializing = false


func advance_period() -> bool:
	if phase != Phase.SURVIVAL or _advancing or _initializing:
		return false
	_advancing = true
	if current_period == Period.EVENING:
		var finished_day: int = current_day
		# Synchronous listeners finish hunger/damage settlement before teleport.
		day_finished.emit(finished_day)
		if current_day == TOTAL_DAYS:
			_enter_endgame()
		else:
			current_day += 1
			current_period = Period.MORNING
			period_changed.emit(current_day, current_period)
	else:
		current_period = Period.NOON if current_period == Period.MORNING else Period.EVENING
		period_changed.emit(current_day, current_period)
	_advancing = false
	return true


func _enter_endgame() -> void:
	phase = Phase.ENDGAME
	# Commit every survivor's destination before notifying any listener.
	var survivors: Array[int] = []
	for id in range(PLAYER_COUNT):
		if not _players[id]["alive"]:
			continue
		_players[id]["continent_id"] = END_CONTINENT_ID
		_players[id]["position"] = END_SPAWNS[id]
		survivors.append(id)
	for id in survivors:
		_place_registered_body(id, END_SPAWNS[id])
	endgame_started.emit()
	for id in survivors:
		player_teleported.emit(id, END_CONTINENT_ID, END_SPAWNS[id])
		player_changed.emit(id)


func get_player(player_id: int) -> Dictionary:
	if not _players.has(player_id):
		return {}
	return _players[player_id].duplicate(true)


func get_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in range(PLAYER_COUNT):
		result.append(get_player(id))
	return result


func get_continents() -> Array[Dictionary]:
	return CONTINENTS.duplicate(true)


func get_time_label() -> String:
	if phase == Phase.ENDGAME:
		return "第 14 天结束 · 终焉大陆"
	return "第 %d 天 · %s" % [current_day, PERIOD_NAMES[current_period]]


func set_profession(player_id: int, profession: Profession) -> bool:
	if not _is_alive(player_id) or profession < 0 or profession >= PROFESSION_NAMES.size():
		return false
	_players[player_id]["profession"] = profession
	_players[player_id]["profession_status"] = {}
	player_changed.emit(player_id)
	return true


func set_profession_status(player_id: int, status_name: String, value: Variant) -> bool:
	# Status values are primitive gameplay data, not Nodes or Resources.
	if not _is_alive(player_id) or status_name.is_empty():
		return false
	if typeof(value) not in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		return false
	_players[player_id]["profession_status"][status_name] = value
	player_changed.emit(player_id)
	return true


func damage_player(player_id: int, amount: int) -> bool:
	if not _is_alive(player_id) or amount <= 0:
		return false
	_players[player_id]["health"] = maxi(0, _players[player_id]["health"] - amount)
	var died: bool = _players[player_id]["health"] == 0
	if died:
		_players[player_id]["alive"] = false
	health_changed.emit(player_id, _players[player_id]["health"], _players[player_id]["max_health"])
	player_changed.emit(player_id)
	if died:
		player_died.emit(player_id)
	return true


func heal_player(player_id: int, amount: int) -> bool:
	if not _is_alive(player_id) or amount <= 0:
		return false
	_players[player_id]["health"] = mini(_players[player_id]["max_health"], _players[player_id]["health"] + amount)
	health_changed.emit(player_id, _players[player_id]["health"], _players[player_id]["max_health"])
	player_changed.emit(player_id)
	return true


func add_item(player_id: int, item_id: String, amount: int = 1) -> bool:
	if not _is_alive(player_id) or item_id.is_empty() or amount <= 0:
		return false
	var inventory: Dictionary = _players[player_id]["inventory"]
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	inventory_changed.emit(player_id, inventory.duplicate(true))
	player_changed.emit(player_id)
	return true


func remove_item(player_id: int, item_id: String, amount: int = 1) -> bool:
	if not _is_alive(player_id) or item_id.is_empty() or amount <= 0:
		return false
	var inventory: Dictionary = _players[player_id]["inventory"]
	var count: int = int(inventory.get(item_id, 0))
	if count < amount:
		return false
	if count == amount:
		inventory.erase(item_id)
	else:
		inventory[item_id] = count - amount
	inventory_changed.emit(player_id, inventory.duplicate(true))
	player_changed.emit(player_id)
	return true


func register_player_body(player_id: int, body: Node2D) -> bool:
	if not _players.has(player_id) or not is_instance_valid(body) or not body.is_inside_tree():
		return false
	_bodies[player_id] = weakref(body)
	_place_registered_body(player_id, _players[player_id]["position"])
	return true


func unregister_player_body(player_id: int, body: Node2D) -> void:
	if _bodies.has(player_id) and _bodies[player_id].get_ref() == body:
		_bodies.erase(player_id)


func update_player_position(player_id: int, position: Vector2) -> bool:
	if not _is_alive(player_id) or not position.is_finite():
		return false
	_players[player_id]["position"] = position
	return true


func _is_alive(player_id: int) -> bool:
	return _players.has(player_id) and _players[player_id]["alive"]


func _place_registered_body(player_id: int, position: Vector2) -> void:
	if not _bodies.has(player_id):
		return
	var body: Node2D = _bodies[player_id].get_ref() as Node2D
	if not is_instance_valid(body) or not body.is_inside_tree():
		_bodies.erase(player_id)
		return
	body.global_position = position
	if body is CharacterBody2D:
		(body as CharacterBody2D).velocity = Vector2.ZERO
