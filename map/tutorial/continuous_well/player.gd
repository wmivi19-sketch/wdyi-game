extends "res://tutorial/candle_well/player.gd"
@export var move_speed: float = 120.0
@export var stair_height_per_step: float = 256.0/12.0
@export var current_z_height: float = 0.0
@export var stair_area_group: StringName = "stair_path"
var on_stair: bool = false
var stair_phase: float = 0.0
var world
var stair_detector: Area2D

func _ready() -> void:
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func _input(event: InputEvent) -> void:
    if world!=null and world.falling:
        if event is InputEventKey and (event.physical_keycode==KEY_SPACE or event.keycode==KEY_SPACE):
            get_viewport().set_input_as_handled()
        return
    super._input(event)

func _physics_process(delta: float) -> void:
    if world.falling:
        velocity = Vector2.ZERO
        world.integrate_fall(delta)
        return
    if jumping:
        jump_elapsed += delta
        if jump_elapsed>=JUMP_DURATION: reset_jump()
        else: jump_height = sin(jump_elapsed/JUMP_DURATION*PI)*JUMP_HEIGHT
    var screen_direction := Vector2(
        float(held(KEY_D) or held(KEY_RIGHT))-float(held(KEY_A) or held(KEY_LEFT)),
        float(held(KEY_S) or held(KEY_DOWN))-float(held(KEY_W) or held(KEY_UP))).normalized()
    # Inverse of the isometric ground projection. Keys now follow the screen axes.
    var ground_direction := Vector2(screen_direction.x*0.5+screen_direction.y,screen_direction.y-screen_direction.x*0.5)
    world.configure_collision()
    velocity = ground_direction*move_speed
    velocity = world.filter_stair_velocity(velocity)
    move_and_slide()
    world.sync_stair_height(delta)

func held(code: int) -> bool:
    # Physical keyboards and IME/virtual/remote keycode-only events are both supported.
    return Input.is_physical_key_pressed(code) or Input.is_key_pressed(code)
