extends "res://scripts/game/survival_manager.gd"
signal continent_switched(continent_id: int)
signal time_updated(day: int, period: int)
var current_continent_id: int = 0
var world_active: bool = false

func _ready() -> void:
	period_changed.connect(func(day, period): time_updated.emit(day, period))
	endgame_started.connect(_on_endgame)
	super._ready()

func start_new_game() -> void:
	if _advancing or _initializing or _combat_mutating:
		return
	world_active = false
	current_continent_id = 0
	super.start_new_game()

func get_current_day() -> int:
	return current_day

func get_current_phase() -> String:
	return ["morning", "noon", "night"][current_period]

func switch_to_continent(continent_id: int) -> void:
	if continent_id < 0 or continent_id > 5:
		return
	if phase == Phase.ENDGAME and continent_id != 5:
		return
	current_continent_id = continent_id
	if _is_alive(0):
		_players[0]["continent_id"] = END_CONTINENT_ID if phase == Phase.ENDGAME else CONTINENTS[continent_id]["id"]
	continent_switched.emit(continent_id)

func next_time_period() -> void:
	advance_period()

func _on_endgame() -> void:
	current_continent_id = 5
	continent_switched.emit(5)
	time_updated.emit(current_day, current_period)

func _physics_process(delta: float) -> void:
	if world_active:
		super._physics_process(delta)

func set_player_health(player_id: int, value: float) -> void:
	# 旧 hp 写入及读档使用同一资源池；正常伤害仍经过 take_damage。
	if not _combatants.has(player_id) or not is_finite(value):
		return
	var actor: ARPGCharacter = _combatants[player_id]
	var desired := clampf(value, 0.0, actor.resources.max_hp)
	if desired == actor.resources.hp:
		return
	if desired < actor.resources.hp:
		actor.resources.damage(actor.resources.hp - desired)
	else:
		actor.dead = false
		actor.resources.enabled = true
		actor.resources.hp = desired
		actor.resources.publish()

func get_player(player_id: int) -> Dictionary:
	var data := super.get_player(player_id)
	if player_id == 0 and not data.is_empty() and GameState.player_inventory != null:
		data["inventory"] = GameState.player_inventory.snapshot()
	return data

func damage_actor(player_id: int, amount: float) -> bool:
	if _combat_mutating or _initializing or not _is_alive(player_id) or not is_finite(amount) or amount <= 0.0:
		return false
	_combat_mutating = true
	_combatants[player_id].take_damage(amount)
	_combat_mutating = false
	return true

func add_item(player_id: int, item_id: String, amount: int = 1) -> bool:
	if player_id != 0 or GameState.player_inventory == null:
		return super.add_item(player_id, item_id, amount)
	if not _is_alive(0) or amount <= 0:
		return false
	return GameState.player_inventory.add_item(item_id, amount)

func remove_item(player_id: int, item_id: String, amount: int = 1) -> bool:
	if player_id != 0 or GameState.player_inventory == null:
		return super.remove_item(player_id, item_id, amount)
	if not _is_alive(0) or amount <= 0:
		return false
	return GameState.player_inventory.remove_item(item_id, amount)

func export_combat() -> Dictionary:
	var states: Array = []
	for id in range(PLAYER_COUNT):
		var actor: ARPGCharacter = _combatants[id]
		var effects: Array = []
		for key in actor.effects:
			var entry: Dictionary = actor.effects[key]
			var effect: ARPGStatusEffect = entry.effect
			var saved := {"id": String(effect.id), "remaining": entry.remaining}
			for property in ["damage_bonus", "damage_reduction", "speed_bonus", "stamina_regen_bonus", "mana_regen_bonus", "stun"]:
				saved[property] = effect.get(property)
			effects.append(saved)
		states.append({"profession": _players[id]["profession"], "continent_id": _players[id]["continent_id"],
			"placed": actor.has_meta("map_placed"),
			"position": [actor.position.x, actor.position.y], "hp": actor.resources.hp, "max_hp": actor.resources.max_hp,
			"stamina": actor.resources.stamina, "mana": actor.resources.mana,
			"delay": actor.resources.delay_left, "cooldowns": actor.cooldowns.duplicate(true), "effects": effects})
	return {"phase": phase, "players": states}

func restore_combat(data: Dictionary) -> void:
	# GameSession 完整验证后调用。读档恢复，不发送新的击杀事件。
	phase = int(data.phase) as Phase
	for id in range(PLAYER_COUNT):
		var saved: Dictionary = data.players[id]
		var actor: ARPGCharacter = _combatants[id]
		_players[id]["profession"] = int(saved.profession)
		_configure_loadout(id, int(saved.profession) as Profession)
		_players[id]["continent_id"] = saved.continent_id
		if saved.get("placed", false):
			actor.set_meta("map_placed", true)
		actor.resources.max_hp = float(saved.max_hp)
		actor.resources.hp = float(saved.hp)
		actor.resources.stamina = float(saved.stamina)
		actor.resources.mana = float(saved.mana)
		actor.resources.delay_left = float(saved.delay)
		actor.dead = actor.resources.hp <= 0.0
		actor.resources.enabled = not actor.dead
		actor.cooldowns = saved.cooldowns.duplicate(true)
		actor.effects.clear()
		for entry in saved.effects:
			var effect := ARPGStatusEffect.new()
			effect.id = StringName(entry.id)
			for property in ["damage_bonus", "damage_reduction", "speed_bonus", "stamina_regen_bonus", "mana_regen_bonus", "stun"]:
				effect.set(property, entry[property])
			actor.effects[effect.id] = {"effect": effect, "remaining": float(entry.remaining)}
		_place_registered_body(id, Vector2(float(saved.position[0]), float(saved.position[1])))
		actor.resources.publish()
