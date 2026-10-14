extends Node
## Sprite sheets: columns are movement frames, rows are directions.
signal skin_updated(job_name: String)
@export_file("*.json") var skins_path := "res://data/skins.json"
var current_job := "default"
var facing := "down"
var jobs: Dictionary = {}
var direction_rows: Dictionary = {"down": 0, "left": 1, "right": 2, "up": 3}
var _placeholder: Texture2D
@onready var animator: AnimationPlayer = $"../AnimationPlayer"
@onready var layers: Array[Sprite2D] = [$"../BaseBody", $"../Outfit", $"../Accessory"]

func _ready() -> void:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("f6cf72"))
	_placeholder = ImageTexture.create_from_image(image)
	_read_config()
	update_skin(current_job)

func _read_config() -> void:
	if not FileAccess.file_exists(skins_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(skins_path))
	if not parsed is Dictionary or parsed.get("schema_version") != 1 or not parsed.get("jobs") is Dictionary:
		return
	jobs = parsed.jobs
	var rows: Variant = parsed.get("direction_rows", {})
	if rows is Dictionary:
		for direction in direction_rows:
			var row: Variant = rows.get(direction, direction_rows[direction])
			if _whole(row) and row >= 0:
				direction_rows[direction] = int(row)

func update_skin(job_name: String) -> void:
	current_job = job_name
	if not is_node_ready():
		return
	animator.stop()
	var skin: Variant = jobs.get(job_name, jobs.get("default", {}))
	if not skin is Dictionary:
		skin = {}
	for sprite in layers:
		var entry: Variant = skin.get(str(sprite.name), {})
		var texture: Texture2D = null
		var columns := 1
		var rows := 1
		if entry is Dictionary:
			var path: Variant = entry.get("path", "")
			var h: Variant = entry.get("hframes", 1)
			var v: Variant = entry.get("vframes", 1)
			if path is String and path.begins_with("res://assets/skins/") and not ".." in path and _whole(h) and _whole(v) and h >= 1 and h <= 64 and v >= 1 and v <= 64:
				if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
					texture = ResourceLoader.load(path, "Texture2D") as Texture2D
					columns = int(h)
					rows = int(v)
		if texture != null and (texture.get_width() % columns != 0 or texture.get_height() % rows != 0):
			texture = null
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.frame = 0
		sprite.texture = texture if texture != null else _placeholder
		sprite.visible = texture != null or sprite.name == &"BaseBody"
		if texture != null:
			sprite.hframes = columns
			sprite.vframes = rows
	_build_animations()
	set_motion(Vector2.ZERO)
	skin_updated.emit(job_name)

func _whole(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) == floor(float(value))

func _build_animations() -> void:
	if animator.has_animation_library(""):
		animator.remove_animation_library("")
	var library := AnimationLibrary.new()
	for direction in direction_rows:
		var animation := Animation.new()
		animation.length = 0.48
		animation.loop_mode = Animation.LOOP_LINEAR
		for sprite in layers:
			var track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track, NodePath(str(sprite.name) + ":frame"))
			animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
			var row := mini(int(direction_rows[direction]), sprite.vframes - 1)
			for column in range(sprite.hframes):
				animation.track_insert_key(track, 0.48 * column / sprite.hframes, row * sprite.hframes + column)
		library.add_animation("walk_" + direction, animation)
	animator.add_animation_library("", library)

func set_motion(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			facing = "right" if direction.x > 0 else "left"
		else:
			facing = "down" if direction.y > 0 else "up"
		var animation_name := "walk_" + facing
		if animator.current_animation != animation_name or not animator.is_playing():
			animator.play(animation_name)
	else:
		animator.stop()
		for sprite in layers:
			sprite.frame = mini(int(direction_rows[facing]), sprite.vframes - 1) * sprite.hframes
