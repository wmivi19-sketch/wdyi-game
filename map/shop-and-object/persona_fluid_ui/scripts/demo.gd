extends Control

@onready var hud: Control = $HUD/VitalsHUD
var health: float = 100.0
var energy: float = 100.0
var mana: float = 100.0

func _ready() -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(46, 210)
	panel.add_theme_constant_override("separation", 12)
	add_child(panel)
	var title := Label.new()
	title.text = "TAKE CONTROL."
	title.add_theme_font_size_override("font_size", 42)
	panel.add_child(title)
	var description := Label.new()
	description.text = "DYNAMIC VITALS / THREE SLIM ROWS\nTrue length animation · 3px gaps · danger below 20%"
	description.add_theme_color_override("font_color", Color("aab2cc"))
	panel.add_child(description)
	for entry in [["[1]  TAKE DAMAGE", _damage], ["[2]  USE STAMINA", _exert],
			["[3]  CAST SPELL", _cast], ["[R]  RESTORE ALL", _restore]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(320, 37)
		button.pressed.connect(entry[1])
		panel.add_child(button)
	hud.update_vitals(health, 100, energy, 100, mana, 100, true)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("090c18"))
	draw_colored_polygon(PackedVector2Array([Vector2(620, 0), Vector2(880, 0),
		Vector2(580, 720), Vector2(320, 720)]), Color("191020"))
	draw_colored_polygon(PackedVector2Array([Vector2(880, 0), Vector2(920, 0),
		Vector2(620, 720), Vector2(580, 720)]), Color("d51b47"))
	for index in range(15):
		var x := 700.0 + index * 38.0
		draw_line(Vector2(x, 0), Vector2(x - 300, 720), Color("22283b"), 1.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1: _damage()
		KEY_2: _exert()
		KEY_3: _cast()
		KEY_R: _restore()

func _damage() -> void:
	health = maxf(0, health - 17)
	_refresh()

func _exert() -> void:
	energy = maxf(0, energy - 19)
	_refresh()

func _cast() -> void:
	mana = maxf(0, mana - 23)
	_refresh()

func _restore() -> void:
	health = 100
	energy = 100
	mana = 100
	_refresh()

func _refresh() -> void:
	hud.update_vitals(health, 100, energy, 100, mana, 100)
