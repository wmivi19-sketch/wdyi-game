extends Control
## A compact debug harness for the global management system.

var _time_label: Label
var _rows: Array[Label] = []
var _bars: Array[ProgressBar] = []
var _advance: Button


func _ready() -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(24, 20)
	panel.size = Vector2(1232, 750)
	panel.add_theme_constant_override("separation", 12)
	add_child(panel)
	var title := Label.new()
	title.text = "逐神终焉 · 全局管理系统验证"
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)
	_time_label = Label.new()
	panel.add_child(_time_label)
	var controls := HBoxContainer.new()
	panel.add_child(controls)
	_advance = _button(controls, "推进一个时段", func(): GameManager.advance_period())
	_button(controls, "重开", func(): GameManager.start_new_game())
	_button(controls, "玩家受伤 20", func(): GameManager.damage_player(0, 20))
	_button(controls, "玩家治疗 20", func(): GameManager.heal_player(0, 20))
	_button(controls, "获得木材", func(): GameManager.add_item(0, "wood"))
	_button(controls, "消耗木材", func(): GameManager.remove_item(0, "wood"))
	_button(controls, "选择战士", func(): GameManager.set_profession(0, GameManager.Profession.WARRIOR))
	var combat_controls := HBoxContainer.new()
	panel.add_child(combat_controls)
	_button(combat_controls, "选择法师", func(): GameManager.set_profession(0, GameManager.Profession.MAGE))
	_button(combat_controls, "进入 ARPG 战斗", func(): get_tree().change_scene_to_file("res://scenes/CombatArena.tscn"))
	var hint := Label.new()
	hint.text = "回合制：早 → 中 → 晚；推进 42 次后进入终焉大陆。死亡角色不传送。"
	panel.add_child(hint)
	for id in range(GameManager.PLAYER_COUNT):
		var row := Label.new()
		panel.add_child(row)
		_rows.append(row)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 24)
		panel.add_child(bar)
		_bars.append(bar)
	GameManager.game_started.connect(_refresh)
	GameManager.period_changed.connect(func(_day, _period): _refresh())
	GameManager.player_changed.connect(func(_id): _refresh())
	GameManager.endgame_started.connect(_refresh)
	_refresh()


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _refresh() -> void:
	_time_label.text = GameManager.get_time_label()
	_advance.disabled = GameManager.phase == GameManager.Phase.ENDGAME
	for id in range(GameManager.PLAYER_COUNT):
		var player: Dictionary = GameManager.get_player(id)
		_rows[id].text = "%s | %s | 职业：%s | %s | 位置 %s | 物品 %s | 耐力 %.0f/%.0f 法力 %.0f/%.0f" % [
			player["name"], player["continent_id"],
			GameManager.PROFESSION_NAMES[player["profession"]],
			"存活" if player["alive"] else "死亡", player["position"], player["inventory"],
			player["resources"]["stamina"], player["resources"]["max_stamina"],
			player["resources"]["mana"], player["resources"]["max_mana"],
		]
		_bars[id].max_value = player["max_health"]
		_bars[id].value = player["health"]


func _process(_delta: float) -> void:
	_refresh()
