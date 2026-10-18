extends Node2D
## 独立演示：按键使用物理键码，无需修改现有 Input Map。
var heroes: Array[ARPGCharacter] = []
var selected: int = 0
var hud: ARPGResourceUI
var message: Label
var cooldown_label: Label

func _ready() -> void:
	for mage in [false, true]:
		var hero := ARPGHeroes.create(mage)
		hero.position = Vector2(300 + heroes.size() * 90, 350)
		add_child(hero)
		heroes.append(hero)
		hero.cast_result.connect(_on_cast)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = ARPGResourceUI.new()
	hud.position = Vector2(24, 24)
	layer.add_child(hud)
	var help := Label.new()
	help.position = Vector2(24, 205)
	help.text = "WARRIOR / MAGE\n1/2 切换英雄 | 方向键移动 | QWER 技能\nH：当前英雄受伤 25 | J：眩晕 2 秒 | T：复活\n另一位英雄为目标；战士 Q 需要靠近。"
	layer.add_child(help)
	message = Label.new()
	message.position = Vector2(24, 470)
	layer.add_child(message)
	cooldown_label = Label.new()
	cooldown_label.position = Vector2(24, 500)
	layer.add_child(cooldown_label)
	hud.bind_character(heroes[selected])

func _process(_delta: float) -> void:
	for hero in heroes:
		hero.move_input = Vector2.ZERO
	var hero := heroes[selected]
	hero.move_input = Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	var text := "%s%s\n" % [hero.name, "（死亡）" if hero.dead else ""]
	for slot in [&"Q", &"W", &"E", &"R"]:
		text += "%s: %.1fs  " % [slot, float(hero.cooldowns.get(slot, 0.0))]
	cooldown_label.text = text

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var hero := heroes[selected]
	match event.physical_keycode:
		KEY_1, KEY_2:
			selected = 0 if event.physical_keycode == KEY_1 else 1
			hud.bind_character(heroes[selected])
		KEY_Q: hero.try_cast(&"Q", heroes[1 - selected])
		KEY_W: hero.try_cast(&"W")
		KEY_E: hero.try_cast(&"E")
		KEY_R: hero.try_cast(&"R", heroes[1 - selected])
		KEY_H: hero.take_damage(25.0)
		KEY_J:
			var stun := ARPGStatusEffect.new()
			stun.id = &"demo_stun"
			stun.stun = true
			stun.duration = 2.0
			hero.add_effect(stun)
		KEY_T: hero.revive()

func _on_cast(slot: StringName, reason: String) -> void:
	message.text = "%s：%s" % [slot, reason]
