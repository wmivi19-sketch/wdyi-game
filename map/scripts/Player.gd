extends CharacterBody2D
class_name ProgressionPlayer
signal job_changed(job_name: String)
signal health_changed(hp: float, maximum: float)
@export var speed := 80.0
@onready var appearance = $AppearanceManager
@onready var camera: Camera2D = $Camera2D
var current_area_tag: String = ""
var _legacy_hp: float = 100.0
var combat_managed: bool = false
var combat_manager: Node:
	get:
		return get_node("/root/GameManager")
var hp: float:
	get:
		return combat_manager.get_combatant(0).resources.hp if combat_managed else _legacy_hp
	set(value):
		if combat_managed:
			combat_manager.set_player_health(0, value)
		else:
			_legacy_hp = value
var stats: Dictionary = {"max_hp": 100.0}
var skill_ids: Array[String] = []
var can_interact: bool = true
var deity_active: bool = false
@export var jump_height: float = 28.0
@export var jump_duration: float = 0.55
var jump_elapsed: float = 0.0
var jumping: bool = false
var landing_left: float = 0.0

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode != KEY_SPACE and event.keycode != KEY_SPACE:
		return
	if _controls_blocked():
		return
	try_jump()
	get_viewport().set_input_as_handled()

func try_jump() -> bool:
	if jumping or hp <= 0.0 or _controls_blocked():
		return false
	if combat_managed and combat_manager.get_combatant(0).is_stunned():
		return false
	jumping = true
	jump_elapsed = 0.0
	landing_left = 0.0
	return true

func _controls_blocked() -> bool:
	var ui := get_parent().get_node_or_null("GameUI/PlayerPanel")
	var maps := get_parent().get_node_or_null("MapUI/MapSystem")
	return (ui != null and ui.visible) or (maps != null and maps.any_open())

func _update_jump(delta: float) -> void:
	var height := 0.0
	var stretch := Vector2.ONE
	var landing_delta := delta
	if jumping:
		jump_elapsed += delta
		var progress := clampf(jump_elapsed / maxf(jump_duration, 0.01), 0.0, 1.0)
		height = sin(progress * PI) * jump_height
		stretch = Vector2(0.92, 1.08)
		if progress >= 1.0:
			jumping = false
			landing_left = 0.12
			landing_delta = maxf(0.0, jump_elapsed - maxf(jump_duration, 0.01))
			height = 0.0
	if not jumping and landing_left > 0.0:
		landing_left = maxf(0.0, landing_left - landing_delta)
		stretch = Vector2.ONE + Vector2(0.16, -0.16) * (landing_left / 0.12)
	for sprite in appearance.layers:
		sprite.position.y = -height
		sprite.scale = stretch
	queue_redraw()

func _reset_jump() -> void:
	jumping = false
	jump_elapsed = 0.0
	landing_left = 0.0
	_update_jump(0.0)

func set_deity_form(enabled: bool) -> void:
	deity_active = enabled
	queue_redraw()

func _draw() -> void:
	if jumping:
		draw_set_transform(Vector2(0, 7), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO)
	if deity_active:
		draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.75, 0.15, 0.2))
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 40, Color("ffd166"), 2.0)

func apply_progression(new_stats: Dictionary, new_skills: Array[String]) -> void:
	stats = new_stats.duplicate(true)
	skill_ids.assign(new_skills)
	if combat_managed:
		var pool: ARPGResources = combat_manager.get_combatant(0).resources
		pool.max_hp = float(stats["max_hp"])
	hp = clampf(hp, 0.0, float(stats["max_hp"]))
	if combat_managed:
		combat_manager.get_combatant(0).resources.publish()
	health_changed.emit(hp, float(stats["max_hp"]))

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		_reset_jump()
	else:
		_update_jump(delta)
	if hp <= 0.0 or _controls_blocked():
		velocity = Vector2.ZERO
		appearance.set_motion(Vector2.ZERO)
		if combat_managed:
			combat_manager.set_move_input(0, Vector2.ZERO)
			combat_manager.get_combatant(0).dash_left = 0.0
		return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if combat_managed:
		if Input.is_physical_key_pressed(KEY_SHIFT):
			direction = Vector2.ZERO
		var actor: ARPGCharacter = combat_manager.get_combatant(0)
		actor.move_speed = speed
		combat_manager.set_move_input(0, direction)
		appearance.set_motion(velocity)
		return
	velocity = direction.normalized() * speed
	move_and_slide()
	appearance.set_motion(velocity)

func update_skin(job_name: String) -> void:
	$AppearanceManager.update_skin(job_name)
	job_changed.emit(job_name)

## Invoke only after the game's ritual completion conditions have passed.
func complete_job_ritual(job_name: String) -> void:
	update_skin(job_name)

func teleport_to(world_position: Vector2) -> void:
	_reset_jump()
	global_position = world_position
	velocity = Vector2.ZERO
	if combat_managed:
		combat_manager.update_player_position(0, world_position)
		combat_manager.get_combatant(0).dash_left = 0.0
	camera.reset_smoothing()

func enable_combat() -> void:
	combat_managed = true
	combat_manager.register_player_body(0, self)
	combat_manager.get_combatant(0).resources.max_hp = float(stats["max_hp"])
	combat_manager.set_player_health(0, _legacy_hp)
	combat_manager.resource_changed.connect(_on_combat_resource)
	combat_manager.world_active = true

func _on_combat_resource(id: int, kind: StringName, value: float, maximum: float) -> void:
	if id == 0 and kind == &"hp":
		health_changed.emit(value, maximum)

func take_damage(amount: float) -> void:
	if combat_managed:
		combat_manager.damage_actor(0, amount)
	else:
		hp = maxf(0.0, hp - amount)
		health_changed.emit(hp, float(stats["max_hp"]))

func _exit_tree() -> void:
	if combat_managed:
		combat_manager.unregister_player_body(0, self)
		combat_manager.set_move_input(0, Vector2.ZERO)
		combat_manager.world_active = false
