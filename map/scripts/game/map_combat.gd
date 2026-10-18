extends Node
## 地图/仪式适配器。真人沿用原外观、相机与背包，AI 使用持久化战斗实体。
var world: Node2D
var hud: ARPGResourceUI
var info: Label
var feedback: Label
var target_id: int = 1
var previous_hp: float = 100.0
var hud_layer: CanvasLayer

func setup(map_world: Node2D) -> void:
	world = map_world
	world.loader.map_loaded.connect(_map_loaded)
	ClassManager.form_changed.connect(_on_form)
	GameManager.skill_cast.connect(_on_cast)
	GameManager.resource_changed.connect(_on_resource)
	GameManager.player_died.connect(_on_death)
	for id in range(1, GameManager.PLAYER_COUNT):
		GameManager.set_profession(id, GameManager.Profession.MAGE if id % 2 == 0 else GameManager.Profession.WARRIOR)
		var actor := GameManager.get_combatant(id)
		actor.z_index = 10 # 与真人一致，避免被稍后绘制的地图地形覆盖。
		actor.collision_mask = 1
		actor.collision_layer = 4
		(actor.get_child(1) as CollisionShape2D).shape.radius = 6.0
		var label := Label.new()
		label.name = "NameTag"
		label.position = Vector2(-20, -48)
		label.add_theme_font_size_override("font_size", 12)
		actor.add_child(label)
	var layer := CanvasLayer.new()
	hud_layer = layer
	layer.name = "CombatHUD"
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(16, 260)
	panel.custom_minimum_size.x = 320
	layer.add_child(panel)
	hud = ARPGResourceUI.new()
	panel.add_child(hud)
	hud.bind_character(GameManager.get_combatant(0))
	info = Label.new()
	panel.add_child(info)
	var buttons := HBoxContainer.new()
	panel.add_child(buttons)
	for slot in [&"Q", &"W", &"E", &"R"]:
		var button := Button.new()
		button.text = String(slot)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(cast.bind(slot))
		buttons.add_child(button)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.x = 320
	panel.add_child(feedback)
	previous_hp = world.player.hp
	_on_form(1, ClassManager.replicated_forms.get(1, {}))
	set_process(true)

func _on_form(id: int, form: Dictionary) -> void:
	if id != 1:
		return
	var classes: Array = form.get("class_ids", [])
	# 仪式获得的职业决定当前技能配置，保留旧职业槽位与外观系统。
	var profession = GameManager.Profession.WARRIOR
	if not classes.is_empty() and classes.back() == "mage":
		profession = GameManager.Profession.MAGE
	elif not classes.is_empty() and classes.back() == "ranger":
		profession = GameManager.Profession.RANGER
	GameManager.set_profession(0, profession)

func _map_loaded(_map_id: String) -> void:
	if GameManager.phase == GameManager.Phase.ENDGAME:
		var points := _landing_points()
		var next := 0
		for id in range(GameManager.PLAYER_COUNT):
			if not GameManager.get_player(id).alive:
				continue
			var position: Vector2 = points[next % points.size()]
			next += 1
			GameManager._place_registered_body(id, position)
			GameManager._players[id]["position"] = position
		world.player.camera.reset_smoothing()
	else:
		GameManager._players[0]["continent_id"] = GameManager.CONTINENTS[GameManager.current_continent_id].id
		# 只加载当前大陆上的 AI，位置记录不会因来回切图而刷新。
		for id in range(1, GameManager.PLAYER_COUNT):
			var data := GameManager.get_player(id)
			if data.continent_id == GameManager.CONTINENTS[GameManager.current_continent_id].id:
				var actor := GameManager.get_combatant(id)
				if not actor.has_meta("map_placed"):
					var points := _landing_points()
					actor.global_position = points[mini(1, points.size() - 1)]
					actor.set_meta("map_placed", true)
					GameManager.update_player_position(id, actor.global_position)
	refresh_visibility()

func _landing_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var layer: TileMapLayer = world.loader.terrain_layer
	var cells := layer.get_used_cells()
	cells.sort_custom(func(a, b): return layer.map_to_local(a).distance_squared_to(world.loader.spawn_position) < layer.map_to_local(b).distance_squared_to(world.loader.spawn_position))
	for cell in cells:
		var clear := true
		for x in range(-1, 2):
			for y in range(-1, 2):
				var tile := layer.get_cell_tile_data(cell + Vector2i(x, y))
				if tile == null or tile.get_collision_polygons_count(0) > 0:
					clear = false
		if not clear:
			continue
		var position := layer.to_global(layer.map_to_local(cell))
		for existing in result:
			if existing.distance_to(position) < 64.0:
				clear = false
		if clear:
			result.append(position)
		if result.size() == GameManager.PLAYER_COUNT:
			break
	if result.is_empty():
		result.append(world.loader.to_global(world.loader.spawn_position))
	return result

func refresh_visibility() -> void:
	for id in range(GameManager.PLAYER_COUNT):
		var actor := GameManager.get_combatant(id)
		actor.visible = id != 0 and GameManager.get_player(id).continent_id == GameManager.get_player(0).continent_id
		actor.collision_mask = 1 if actor.visible else 0
	previous_hp = world.player.hp

func blocked() -> bool:
	var panel := world.get_node_or_null("GameUI/PlayerPanel")
	return world.player.hp <= 0.0 or (panel != null and panel.visible) or world.map_system.any_open() or not world.player.can_interact

func cast(slot: StringName) -> void:
	if blocked():
		return
	var actor := GameManager.get_combatant(0)
	var skill: ARPGSkill = actor.get(String(slot).to_lower())
	GameManager.try_cast_skill(0, slot, target_id if skill is ARPGDamageSkill else -1)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.shift_pressed:
		match event.keycode:
			KEY_Q: cast(&"Q")
			KEY_W: cast(&"W")
			KEY_E: cast(&"E")
			KEY_R: cast(&"R")
			_: return
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_T:
		target_id = target_id % 5 + 1

func _on_cast(id: int, slot: StringName, reason: String) -> void:
	if id == 0:
		feedback.text = "%s：%s" % [slot, reason]

func _on_resource(id: int, kind: StringName, value: float, _maximum: float) -> void:
	if id == 0 and kind == &"hp":
		if value < previous_hp:
			ClassManager.interrupt_ritual(1)
		previous_hp = value

func _on_death(id: int) -> void:
	if id == 0 and ClassManager.players.has(1):
		ClassManager.on_player_died(1)

func _process(_delta: float) -> void:
	if not is_instance_valid(world.player):
		return
	var panel := world.get_node_or_null("GameUI/PlayerPanel")
	hud_layer.visible = not ((panel != null and panel.visible) or world.map_system.any_open())
	var target := GameManager.get_player(target_id)
	info.text = "Shift+Q/W/E/R 技能 · T 切换目标\n目标 AI %d · HP %d · %s" % [target_id, target.health, "同大陆" if target.continent_id == GameManager.get_player(0).continent_id else "其他大陆"]
	var hero := GameManager.get_combatant(0)
	for slot in [&"Q", &"W", &"E", &"R"]:
		var skill: ARPGSkill = hero.get(String(slot).to_lower())
		info.text += "\n%s %s %.1fs" % [slot, skill.title if skill != null else "未配置", float(hero.cooldowns.get(slot, 0.0))]
	for id in range(1, GameManager.PLAYER_COUNT):
		var actor := GameManager.get_combatant(id)
		actor.get_node("NameTag").text = "AI %d%s\nHP %.0f" % [id, " ◀" if id == target_id else "", actor.resources.hp]

func _exit_tree() -> void:
	for id in range(GameManager.PLAYER_COUNT):
		var actor := GameManager.get_combatant(id)
		if is_instance_valid(actor):
			actor.visible = false
