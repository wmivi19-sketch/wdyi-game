extends CharacterBody2D

var jumping: bool = false
var jump_elapsed: float = 0.0
var jump_height: float = 0.0
const JUMP_DURATION := 0.55
const JUMP_HEIGHT := 28.0

func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE:
        if not jumping:
            jumping = true
            jump_elapsed = 0.0
        get_viewport().set_input_as_handled()

func reset_jump() -> void:
    jumping = false
    jump_elapsed = 0.0
    jump_height = 0.0

func _physics_process(delta: float) -> void:
    if jumping:
        jump_elapsed += delta
        if jump_elapsed >= JUMP_DURATION:
            reset_jump()
        else:
            jump_height = sin(jump_elapsed / JUMP_DURATION * PI) * JUMP_HEIGHT
    var direction := Vector2(
        float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
        float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
    )
    velocity = direction.normalized() * 112.0
    move_and_slide()

func _draw() -> void:
    pass # Feet-only physics body; pixel_actor.gd renders the projected avatar.
