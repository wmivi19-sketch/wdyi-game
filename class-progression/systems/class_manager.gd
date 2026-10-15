extends Node

signal notice(player_id: int, message: String)
signal ritual_started(player_id: int, ritual_id: String, duration: float, ascension: bool)
signal ritual_ended(player_id: int, ritual_id: String, success: bool, reason: String)
signal form_changed(player_id: int, form: Dictionary)

const MAX_CLASSES := 3
var classes: Dictionary = {}
var rituals: Dictionary = {}
var deities: Dictionary = {}
var players: Dictionary = {}
var altars: Dictionary = {}
var active: Dictionary = {}
var replicated_forms: Dictionary = {}
var replicated_rituals: Dictionary = {}

class PlayerState:
	extends RefCounted
	var actor: ProgressionPlayer
	var inventory: ProgressionInventory
	var base_stats: Dictionary = {}
	var class_ids: Array[String] = []
	var deity: DeityInfo = null

func register_player(id: int, actor: ProgressionPlayer, inventory: ProgressionInventory,
		base_stats: Dictionary, base_class_id: String) -> bool:
	if not multiplayer.is_server() or players.has(id) or not classes.has(base_class_id):
		return false
	var state := PlayerState.new()
	state.actor = actor
	state.inventory = inventory
	state.base_stats = base_stats.duplicate(true)
	state.base_stats["max_hp"] = float(base_stats.get("max_hp", 100.0))
	state.class_ids.append(base_class_id)
	players[id] = state
	_rebuild(id)
	return true

func unregister_player(id: int) -> void:
	if not multiplayer.is_server():
		return
	interrupt_ritual(id)
	players.erase(id)
	_forget.rpc(id)

# Trusted server API for initial/admin grants. Gameplay acquisition uses rituals.
func add_class_slot(class_id: String, player_id: int = 0) -> bool:
	if not multiplayer.is_server():
		return false
	var id := _resolve(player_id)
	var state := players.get(id) as PlayerState
	if state == null:
		return false
	var error := _class_error(state, class_id)
	if not error.is_empty() or active.has(id):
		_notice.rpc(id, error if not error.is_empty() else "仪式期间不能直接授予职业")
		return false
	state.class_ids.append(class_id)
	_rebuild(id)
	return true

func _class_error(state: PlayerState, class_id: String) -> String:
	if not classes.get(class_id) is ClassInfo:
		return "职业配置无效"
	if state.class_ids.has(class_id):
		return "已经拥有该职业"
	if state.class_ids.size() >= MAX_CLASSES:
		return "最多拥有 3 个职业"
	return ""

func check_ritual_readiness(ritual_id: String, player_id: int = 0,
		altar_id: String = "") -> bool:
	if not multiplayer.is_server():
		return false
	return _validate(_resolve(player_id), rituals.get(ritual_id) as RitualRequirement,
		altar_id).is_empty()

func _validate(id: int, requirement: RitualRequirement, altar_id: String) -> String:
	var state := players.get(id) as PlayerState
	if state == null or not is_instance_valid(state.actor):
		return "玩家不存在"
	if state.actor.hp <= 0.0:
		return "死亡状态无法举行仪式"
	if requirement == null or requirement.duration_seconds <= 0.0:
		return "仪式配置无效"
	var altar := altars.get(altar_id) as RitualAltar
	if not is_instance_valid(altar) or not altar.permits(state.actor, requirement.ritual_id):
		return "无法交互或距离祭坛过远"
	var day := int(TimeManager.get_current_day())
	if day < requirement.start_day or day > requirement.end_day:
		return "日期不符合要求"
	if not requirement.allowed_phases.is_empty():
		if not requirement.allowed_phases.has(String(TimeManager.get_current_phase())):
			return "时段不符合要求"
	if not requirement.allowed_area_tags.is_empty():
		if not requirement.allowed_area_tags.has(state.actor.current_area_tag):
			return "区域不符合要求"
	for class_id in requirement.required_class_ids:
		if not state.class_ids.has(class_id):
			return "缺少前置职业"
	if not requirement.required_mark_id.is_empty():
		if state.inventory.count_item(requirement.required_mark_id) < 1:
			return "缺少职业印记"
	if requirement.kind == RitualRequirement.Kind.CLASS_ACQUISITION:
		return _class_error(state, requirement.granted_class_id)
	if requirement.kind != RitualRequirement.Kind.DEITY_ASCENSION:
		return "未知仪式类型"
	if day < 12 or day > 14:
		return "成神仅限第 12～14 天"
	if state.class_ids.size() != MAX_CLASSES or state.deity != null:
		return "必须处于半神状态"
	if not deities.get(requirement.granted_deity_id) is DeityInfo:
		return "神明配置无效"
	return ""

func start_ritual(ritual_id: String, altar_id: String = "") -> void:
	if multiplayer.is_server():
		_start(multiplayer.get_unique_id(), ritual_id, altar_id)
	else:
		_request_start.rpc_id(1, ritual_id, altar_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_start(ritual_id: String, altar_id: String) -> void:
	if multiplayer.is_server():
		_start(multiplayer.get_remote_sender_id(), ritual_id, altar_id)

func _start(id: int, ritual_id: String, altar_id: String) -> void:
	if active.has(id):
		_notice.rpc(id, "已有仪式正在进行")
		return
	var original := rituals.get(ritual_id) as RitualRequirement
	var error := _validate(id, original, altar_id)
	if not error.is_empty():
		_notice.rpc(id, error)
		return
	var requirement := original.duplicate(true) as RitualRequirement
	var deity: DeityInfo = null
	if requirement.kind == RitualRequirement.Kind.DEITY_ASCENSION:
		deity = deities[requirement.granted_deity_id].duplicate(true) as DeityInfo
	active[id] = {"requirement": requirement, "altar_id": altar_id,
		"elapsed": 0.0, "committing": false, "deity": deity}
	_started.rpc(id, ritual_id, requirement.duration_seconds, deity != null)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for id in active.keys():
		var entry: Dictionary = active[id]
		if entry["committing"]:
			continue
		var requirement: RitualRequirement = entry["requirement"]
		var error := _validate(id, requirement, entry["altar_id"])
		if not error.is_empty():
			_end(id, false, error)
			continue
		entry["elapsed"] = float(entry["elapsed"]) + delta
		if float(entry["elapsed"]) >= requirement.duration_seconds:
			_commit(id)

func _commit(id: int) -> void:
	var entry: Dictionary = active[id]
	var requirement: RitualRequirement = entry["requirement"]
	var error := _validate(id, requirement, entry["altar_id"])
	if not error.is_empty():
		_end(id, false, error)
		return
	var state: PlayerState = players[id]
	entry["committing"] = true
	# Inventory is a signal-free transaction. No fallible callbacks after consumption.
	if requirement.consume_mark_on_success and not requirement.required_mark_id.is_empty():
		if not state.inventory.try_consume(requirement.required_mark_id, 1):
			_end(id, false, "印记扣除失败")
			return
	if requirement.kind == RitualRequirement.Kind.CLASS_ACQUISITION:
		state.class_ids.append(requirement.granted_class_id)
	else:
		ascend_to_deity(entry["deity"], id)
	# Remove active state before any actor callbacks or local signals.
	active.erase(id)
	_rebuild(id)
	_ended.rpc(id, requirement.ritual_id, true, "")

# Guarded commit API: no ritual, wrong config, or unfinished channel => no grant.
func ascend_to_deity(deity_config: Resource, player_id: int = 0) -> bool:
	if not multiplayer.is_server():
		return false
	var id := _resolve(player_id)
	if not active.has(id):
		return false
	var entry: Dictionary = active[id]
	var requirement: RitualRequirement = entry["requirement"]
	if not entry["committing"] or requirement.kind != RitualRequirement.Kind.DEITY_ASCENSION:
		return false
	if deity_config == null or deity_config != entry["deity"]:
		return false
	var state: PlayerState = players[id]
	state.deity = deity_config as DeityInfo
	return true

# Only the authoritative combat simulation calls this after confirmed damage.
func interrupt_ritual(target_player_id: int) -> void:
	if not multiplayer.is_server() or not active.has(target_player_id):
		return
	if not active[target_player_id]["committing"]:
		_end(target_player_id, false, "仪式被打断")

func apply_confirmed_damage(target_id: int, damage: float) -> void:
	if not multiplayer.is_server() or damage <= 0.0:
		return
	var state := players.get(target_id) as PlayerState
	if state == null or state.actor.hp <= 0.0:
		return
	state.actor.hp = maxf(0.0, state.actor.hp - damage)
	interrupt_ritual(target_id)
	if state.actor.hp <= 0.0:
		on_player_died(target_id)

func on_player_died(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	interrupt_ritual(id)
	var state: PlayerState = players[id]
	state.actor.hp = 0.0
	state.deity = null
	_rebuild(id)

func _rebuild(id: int) -> void:
	var state: PlayerState = players[id]
	var stats := state.base_stats.duplicate(true)
	var skills: Array[String] = []
	for class_id in state.class_ids:
		var info: ClassInfo = classes[class_id]
		_add_stats(stats, info.stat_bonuses)
		_merge_skills(skills, info.skill_ids)
	if state.deity != null:
		stats["max_hp"] = float(stats["max_hp"]) + float(state.base_stats["max_hp"]) * (state.deity.base_hp_multiplier - 1.0)
		_add_stats(stats, state.deity.stat_bonuses)
		_merge_skills(skills, state.deity.divine_skill_ids)
	var form := {"class_ids": state.class_ids.duplicate(), "stats": stats,
		"skill_ids": skills, "is_deity": state.deity != null,
		"is_demigod": state.class_ids.size() == MAX_CLASSES and state.deity == null,
		"deity_id": state.deity.deity_id if state.deity != null else ""}
	state.actor.apply_progression(stats, skills)
	_form.rpc(id, form)

func _add_stats(stats: Dictionary, bonuses: Dictionary) -> void:
	for key in bonuses:
		stats[key] = float(stats.get(key, 0.0)) + float(bonuses[key])

func _merge_skills(skills: Array[String], additions: Array[String]) -> void:
	for skill in additions:
		if not skills.has(skill):
			skills.append(skill)

func _end(id: int, success: bool, reason: String) -> void:
	var requirement: RitualRequirement = active[id]["requirement"]
	active.erase(id)
	_ended.rpc(id, requirement.ritual_id, success, reason)

func _resolve(id: int) -> int:
	return multiplayer.get_unique_id() if id == 0 else id

@rpc("authority", "call_local", "reliable")
func _notice(id: int, message: String) -> void:
	notice.emit(id, message)

@rpc("authority", "call_local", "reliable")
func _started(id: int, ritual_id: String, duration: float, ascension: bool) -> void:
	replicated_rituals[id] = {"ritual_id": ritual_id, "remaining": duration,
		"ascension": ascension, "received_ms": Time.get_ticks_msec()}
	ritual_started.emit(id, ritual_id, duration, ascension)

@rpc("authority", "call_local", "reliable")
func _ended(id: int, ritual_id: String, success: bool, reason: String) -> void:
	replicated_rituals.erase(id)
	ritual_ended.emit(id, ritual_id, success, reason)

@rpc("authority", "call_local", "reliable")
func _form(id: int, form: Dictionary) -> void:
	replicated_forms[id] = form.duplicate(true)
	form_changed.emit(id, form.duplicate(true))

@rpc("authority", "call_local", "reliable")
func _forget(id: int) -> void:
	replicated_forms.erase(id)
	replicated_rituals.erase(id)

# Call after peer scene/Autoload readiness, including after a reconnect.
func send_snapshot(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for id in replicated_forms:
		_form.rpc_id(peer_id, id, replicated_forms[id])
	for id in active:
		var entry: Dictionary = active[id]
		var requirement: RitualRequirement = entry["requirement"]
		_started.rpc_id(peer_id, id, requirement.ritual_id,
			maxf(0.0, requirement.duration_seconds - float(entry["elapsed"])),
			requirement.kind == RitualRequirement.Kind.DEITY_ASCENSION)
