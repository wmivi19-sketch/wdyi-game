extends CanvasLayer

signal panel_toggled(is_visible: bool)

@onready var character_info_panel: Control = $CharacterInfoPanel

func _ready() -> void:
	character_info_panel.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_TAB:
			character_info_panel.visible = not character_info_panel.visible
			panel_toggled.emit(character_info_panel.visible)
			get_viewport().set_input_as_handled()
