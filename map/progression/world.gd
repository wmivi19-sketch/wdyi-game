extends Node
## Connects the existing 2D player, map markers and authoritative inventory.

signal message(text: String)
signal inventory_changed

const LOCAL_PLAYER_ID := 1
var loader: MapLoader
var player: ProgressionPlayer
var inventory := ProgressionInventory.new()
var harvested: Dictionary = {}
var claimed_events: Dictionary = {}
var current_altars: Array[RitualAltar] = []
var next_divine_cast_ms: int = 0

func setup(map_loader: MapLoader, actor: ProgressionPlayer) -> void:
	loader = map_loader
	player = actor
	ClassManager.register_player(LOCAL_PLAYER_ID, player, inventory,
		{"max_hp": 100.0, "attack": 10.0}, "warrior")
	loader.map_loaded.connect(_map_loaded)
	if not loader.current_data.is_empty():
		_map_loaded(String(loader.current_data.id))

func _exit_tree() -> void:
	_clear_altars()
	if is_instance_valid(ClassManager):
		ClassManager.unregister_player(LOCAL_PLAYER_ID)

func _clear_altars() -> void:
	ClassManager.interrupt_ritual(LOCAL_PLAYER_ID)
	for altar in current_altars:
		if is_instance_valid(altar):
			ClassManager.altars.erase(altar.altar_id)
			altar.queue_free()
	current_altars.clear()

func _map_loaded(map_id: String) -> void:
	_clear_altars()
	player.current_area_tag = map_id
	for marker in loader.special_locations.get_children():
		var data: Dictionary = marker.get_meta("map_data")
		if data.kind != "altar":
			continue
		var altar := RitualAltar.new()
		altar.altar_id = map_id + ":" + String(data.id)
		altar.interaction_radius = float(data.radius)
		if map_id == "continent_0":
			altar.ritual_ids.assign(["learn_mage"])
		elif map_id == "continent_1":
			altar.ritual_ids.assign(["learn_ranger"])
		elif map_id == "continent_5":
			altar.ritual_ids.assign(["sun_ascension"])
		marker.add_child(altar)
		current_altars.append(altar)
		ClassManager.altars[altar.altar_id] = altar
	for marker in loader.resource_points.get_children():
		var data: Dictionary = marker.get_meta("map_data")
		marker.visible = not harvested.has(map_id + ":" + String(data.id))

func craft(recipe_id: String) -> bool:
	if not multiplayer.is_server() or player.hp <= 0.0:
		return false
	var recipe := preload("res://progression/catalog.gd").recipe(recipe_id)
	var success := inventory.craft(recipe)
	message.emit("合成成功：已获得职业印记" if success else "材料不足")
	inventory_changed.emit()
	return success

func interact() -> void:
	if not multiplayer.is_server() or player.hp <= 0.0 or not player.can_interact:
		return
	var map_id: String = String(loader.current_data.get("id", ""))
	# Story reward is once per world session, not once per map load.
	for marker in loader.special_locations.get_children():
		var data: Dictionary = marker.get_meta("map_data")
		if data.kind != "artifact" or player.global_position.distance_to(marker.global_position) > float(data.radius):
			continue
		var key: String = map_id + ":" + String(data.id)
		if not claimed_events.has(key):
			if not inventory.add_item("sun_mark", 1):
				message.emit("背包已满，剧情奖励未领取")
				return
			claimed_events[key] = true
			message.emit("剧情奖励：获得太阳神印记")
			inventory_changed.emit()
			return
	var bridge := get_parent().get_node_or_null("WorldItems")
	if bridge != null:
		if bridge.collect_nearest():
			inventory_changed.emit()
			return
	else:
		for marker in loader.resource_points.get_children():
			var data: Dictionary = marker.get_meta("map_data")
			var key: String = map_id + ":" + String(data.id)
			if harvested.has(key) or player.global_position.distance_to(marker.global_position) > 24.0:
				continue
			harvested[key] = true
			inventory.add_item(String(data.kind), int(data.amount))
			marker.hide()
			message.emit("采集 %s × %s" % [data.kind, data.amount])
			inventory_changed.emit()
			return
	for altar in current_altars:
		if not altar.ritual_ids.is_empty() and altar.permits(player, altar.ritual_ids[0]):
			ClassManager.start_ritual(altar.ritual_ids[0], altar.altar_id)
			return
	message.emit("靠近资源、剧情遗物或祭坛后按 E")

func cast_sun_burst() -> bool:
	if not multiplayer.is_server() or player.hp <= 0.0:
		return false
	if not player.skill_ids.has("sun_burst"):
		message.emit("需要成神后才能释放太阳爆发")
		return false
	var now := Time.get_ticks_msec()
	if now < next_divine_cast_ms:
		message.emit("太阳爆发正在冷却")
		return false
	next_divine_cast_ms = now + 5000
	# The existing map has no enemy actors. Registered hostile targets are
	# damaged only after the server checks living state and range.
	for id in ClassManager.players.keys():
		if id == LOCAL_PLAYER_ID:
			continue
		var state = ClassManager.players[id]
		if not is_instance_valid(state.actor) or state.actor.hp <= 0.0:
			continue
		if state.actor.current_area_tag != player.current_area_tag:
			continue
		if player.global_position.distance_to(state.actor.global_position) <= 120.0:
			ClassManager.apply_confirmed_damage(id, 50.0)
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(48):
		points.append(Vector2.from_angle(TAU * i / 48.0) * 120.0)
	ring.polygon = points
	ring.color = Color(1.0, 0.8, 0.15, 0.25)
	player.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)
	message.emit("太阳爆发：范围120，伤害50，冷却5秒")
	return true
