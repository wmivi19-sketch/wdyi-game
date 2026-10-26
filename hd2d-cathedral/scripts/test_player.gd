@tool
extends CharacterBody3D
## 测试角色：画面与胶囊碰撞独立，可替换美术而不改变移动手感。

@export_group("人物美术")
@export var character_texture: Texture2D = preload("res://assets/characters/test_adventurer.svg"):
	set(value):
		character_texture = value
		if is_node_ready():
			_refresh_art()
@export_range(0.3, 5.0, 0.05) var art_height: float = 2.1:
	set(value):
		art_height = value
		if is_node_ready():
			_refresh_art()
@export var art_tint: Color = Color.WHITE:
	set(value):
		art_tint = value
		if is_node_ready():
			_refresh_art()
@export_group("移动")
@export var move_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var jump_speed: float = 8.5
@export var gravity: float = 12.0

var input_blocked: bool = false
var _spawn: Vector3
var _walk_time: float = 0.0
var _art_base_position: Vector3

func _ready() -> void:
	_spawn = global_position
	_refresh_art()

func _refresh_art() -> void:
	var sprite: Sprite3D = $ArtPivot/Sprite3D
	sprite.texture = character_texture
	sprite.modulate = art_tint
	sprite.visible = character_texture != null
	if character_texture == null:
		return
	var source: Image = character_texture.get_image()
	if source == null:
		return
	if source.is_compressed():
		source.decompress()
	var rect := source.get_used_rect()
	if not rect.has_area():
		sprite.visible = false
		return
	var meters_per_pixel := art_height / float(rect.size.y)
	var anchor := Vector2(rect.position) + Vector2(rect.size) * Vector2(0.5, 1.0)
	var midpoint := Vector2(source.get_size()) * 0.5
	sprite.pixel_size = meters_per_pixel
	_art_base_position = Vector3((midpoint.x-anchor.x)*meters_per_pixel, (anchor.y-midpoint.y)*meters_per_pixel, 0)
	sprite.position = _art_base_position

func reset_position() -> void:
	global_position = _spawn
	velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not input_blocked and Input.is_physical_key_pressed(KEY_R):
		reset_position()
	var move := Vector2.ZERO
	if not input_blocked:
		move.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		move.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	move = move.normalized()
	var speed := sprint_speed if Input.is_physical_key_pressed(KEY_SHIFT) else move_speed
	velocity.x = move.x * speed
	velocity.z = move.y * speed
	if is_on_floor():
		if not input_blocked and Input.is_action_just_pressed("ui_accept"):
			velocity.y = jump_speed
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	if global_position.y < -10:
		reset_position()
	var sprite: Sprite3D = $ArtPivot/Sprite3D
	if absf(move.x) > 0.01:
		sprite.flip_h = move.x < 0
	_walk_time += delta * speed * 2.5
	sprite.position = _art_base_position + Vector3(0, absf(sin(_walk_time))*0.06 if move.length_squared() > 0 and is_on_floor() else 0.0, 0)
	sprite.position.x = -_art_base_position.x if sprite.flip_h else _art_base_position.x

func load_art_file(path: String) -> Error:
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		return error
	if image.is_empty() or not image.get_used_rect().has_area():
		return ERR_INVALID_DATA
	character_texture = ImageTexture.create_from_image(image)
	return OK
