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

func set_deity_form(enabled: bool) -> void:
	deity_active = enabled
	queue_redraw()

func _draw() -> void:
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

func _physics_process(_delta: float) -> void:
	var ui := get_parent().get_node_or_null("GameUI/PlayerPanel")
	var maps := get_parent().get_node_or_null("MapUI/MapSystem")
	if hp <= 0.0 or (ui != null and ui.visible) or (maps != null and maps.any_open()):
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
