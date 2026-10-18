class_name ARPGResourceUI
extends VBoxContainer
## 支持重新绑定；先断开旧信号，避免切换英雄后重复更新。
var bound: ARPGResources
var bars: Dictionary = {}

func _ready() -> void:
	for kind in [&"hp", &"stamina", &"mana"]:
		var label := Label.new()
		label.text = String(kind).to_upper()
		add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(320, 24)
		bar.show_percentage = false
		add_child(bar)
		bars[kind] = {"bar": bar, "label": label}

func bind_character(character: ARPGCharacter) -> void:
	if is_instance_valid(bound) and bound.changed.is_connected(_update_bar):
		bound.changed.disconnect(_update_bar)
	bound = character.resources
	bound.changed.connect(_update_bar)
	bound.publish()

func _update_bar(kind: StringName, value: float, maximum: float) -> void:
	if not bars.has(kind):
		return
	bars[kind].bar.max_value = maximum
	bars[kind].bar.value = value
	bars[kind].label.text = "%s  %.0f / %.0f" % [String(kind).to_upper(), value, maximum]
