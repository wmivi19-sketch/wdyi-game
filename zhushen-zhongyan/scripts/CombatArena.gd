extends Node2D
## 使用 GameManager 持久化战斗实体，场景切换不重置资源与冷却。
var target_id: int = 1
var hud: ARPGResourceUI
var info: Label
var result: Label
var skill_info: Label

func _ready() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := VBoxContainer.new()
	panel.position = Vector2(900, 20)
	panel.custom_minimum_size.x = 350
	canvas.add_child(panel)
	info = Label.new()
	panel.add_child(info)
	hud = ARPGResourceUI.new()
	panel.add_child(hud)
	var hint := Label.new()
	hint.text = "方向键移动，QWER 施法\n数字 1—5 选择对应 AI 目标\n大陆隔离：进入终焉后可互相攻击\nAI 当前为静止测试目标"
	panel.add_child(hint)
	skill_info = Label.new()
	panel.add_child(skill_info)
	result = Label.new()
	panel.add_child(result)
	_button(panel, "战士", func(): GameManager.set_profession(0, GameManager.Profession.WARRIOR))
	_button(panel, "法师", func(): GameManager.set_profession(0, GameManager.Profession.MAGE))
	_button(panel, "推进一个时段", func(): GameManager.advance_period())
	_button(panel, "测试：推进至终焉", _advance_to_endgame)
	_button(panel, "重开", func(): GameManager.start_new_game())
	_button(panel, "返回管理面板", func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	GameManager.game_started.connect(_bind_actors)
	GameManager.skill_cast.connect(_on_cast)
	_bind_actors()

func _button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)

func _bind_actors() -> void:
	for id in range(GameManager.PLAYER_COUNT):
		var actor := GameManager.get_combatant(id)
		actor.visible = true
		# 生存期实体可能坐标接近，但大陆不同；不启用跨大陆碰撞。
		actor.collision_layer = 0
		actor.collision_mask = 0
	hud.bind_character(GameManager.get_combatant(0))
	queue_redraw()

func _advance_to_endgame() -> void:
	while GameManager.phase == GameManager.Phase.SURVIVAL:
		if not GameManager.advance_period():
			break

func _process(_delta: float) -> void:
	GameManager.set_move_input(0, Vector2(
		float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))))
	var player := GameManager.get_player(0)
	var target := GameManager.get_player(target_id)
	info.text = "%s\n职业：%s\n目标 AI %d：HP %d，%s" % [GameManager.get_time_label(),
		GameManager.PROFESSION_NAMES[player["profession"]], target_id, target["health"], target["continent_id"]]
	var hero := GameManager.get_combatant(0)
	var text := "被动：%s\n" % (hero.passive.title if hero.passive != null else "无")
	for slot in [&"Q", &"W", &"E", &"R"]:
		var skill: ARPGSkill = hero.get(String(slot).to_lower())
		text += "%s %s  %.1fs\n" % [slot, skill.title if skill != null else "未配置", float(hero.cooldowns.get(slot, 0.0))]
	skill_info.text = text
	queue_redraw()

func _draw() -> void:
	for player in GameManager.get_players():
		var actor := GameManager.get_combatant(player["id"])
		if is_instance_valid(actor):
			draw_string(ThemeDB.fallback_font, actor.global_position + Vector2(-20, -28),
				"%s HP %d" % [player["name"], player["health"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			if player["id"] == target_id:
				draw_arc(actor.global_position, 24.0, 0, TAU, 32, Color.YELLOW, 2.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
		target_id = event.physical_keycode - KEY_0
	match event.physical_keycode:
		KEY_Q: GameManager.try_cast_skill(0, &"Q", target_id)
		KEY_W: GameManager.try_cast_skill(0, &"W")
		KEY_E: GameManager.try_cast_skill(0, &"E")
		KEY_R:
			var targeted: bool = GameManager.get_combatant(0).r is ARPGDamageSkill
			GameManager.try_cast_skill(0, &"R", target_id if targeted else -1)

func _on_cast(player_id: int, slot: StringName, reason: String) -> void:
	if player_id == 0:
		result.text = "%s：%s" % [slot, reason]

func _exit_tree() -> void:
	for id in range(GameManager.PLAYER_COUNT):
		var actor := GameManager.get_combatant(id)
		if is_instance_valid(actor):
			actor.visible = false
			actor.move_input = Vector2.ZERO
			actor.dash_left = 0.0
