extends CharacterBody2D
signal job_changed(job_name: String)
@export var speed := 80.0
@onready var appearance = $AppearanceManager
@onready var camera: Camera2D = $Camera2D

func _physics_process(_delta: float) -> void:
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
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
	camera.reset_smoothing()
