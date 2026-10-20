extends CanvasLayer
## Presentation only: bind the existing player's authoritative combat resources.
const HUD_SCENE = preload("../../persona_fluid_ui/scenes/vitals_hud.tscn")
var world: Node2D
var hud: Control
var _title: Label
var _selector: OptionButton

func _ready() -> void:
	layer = 0
	world = get_parent().world
	# MapCombat and MapSystem are created after WorldItems in MapDemo._ready.
	call_deferred("_mount")

func _mount() -> void:
	if not is_instance_valid(world):
		return
	hud = HUD_SCENE.instantiate()
	hud.name = "VitalsHUD"
	hud.character_name = "逐神终焉 / 旅者"
	add_child(hud)
	var combat := world.get_node("MapCombat")
	# Keep the legacy instance (and its public API), but stop drawing duplicates.
	combat.hud.hide()
	combat.hud.get_parent().position.y = 210
	for child in world.character_info_ui.get_children():
		if child is Label and child != world.status:
			_title = child
		elif child is OptionButton:
			_selector = child
	_layout_header()
	get_viewport().size_changed.connect(_layout_header)
	GameManager.resource_changed.connect(_resource_changed)
	world.loader.map_loaded.connect(_map_loaded)
	_sync(true)
	_update_visibility()

func _layout_header() -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var available := maxf(160.0, viewport_width - 120.0)
	hud.size.x = clampf(viewport_width - 48.0, 260.0, 340.0)
	if is_instance_valid(_title):
		_title.position = Vector2(60, 106)
		_title.custom_minimum_size.x = 0
		_title.size.x = available
		_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_instance_valid(_selector):
		_selector.position = Vector2(60, 154)
	world.status.position = Vector2(310, 158)
	world.status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world.status.size.x = maxf(100.0, viewport_width - 330.0)

func _resource_changed(id: int, kind: StringName, value: float, maximum: float) -> void:
	if id != 0 or not is_instance_valid(hud):
		return
	match kind:
		&"hp": hud.hp.set_value(value, maximum)
		&"stamina": hud.stamina.set_value(value, maximum)
		&"mana": hud.mp.set_value(value, maximum)

func _sync(instant: bool = false) -> void:
	if not is_instance_valid(hud):
		return
	var state := GameManager.get_combat_state(0)
	if state.is_empty():
		return
	hud.update_vitals(state.hp, state.max_hp, state.stamina, state.max_stamina,
		state.mana, state.max_mana, instant)

func _map_loaded(_id: String) -> void:
	# Save restoration runs in map_loaded listeners; snap after all of them finish.
	call_deferred("_sync", true)

func _process(_delta: float) -> void:
	_update_visibility()

func _update_visibility() -> void:
	if not is_instance_valid(hud) or not is_instance_valid(world.map_system):
		return
	visible = not (world.character_info_ui.character_info_panel.visible or world.map_system.any_open())
