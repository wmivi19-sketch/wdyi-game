class_name MapMarker
extends Sprite2D
@export var marker_type: String = "player"
@export var base_size: Vector2 = Vector2(32, 32)
@export var world_position: Vector2 = Vector2.ZERO
var current_map_type: String = "gameplay"
var map_bounds: Dictionary = {}
var map_texture_size: Vector2 = Vector2.ONE

func _ready() -> void:
 if texture == null: texture = MapDatabase.marker_texture(marker_type)
 update_appearance()

func _process(_delta: float) -> void:
 update_appearance()

func update_appearance() -> void:
 if not map_bounds.is_empty():
  position = CoordinateConverter.world_to_map(world_position, map_bounds, map_texture_size)
 if texture == null or not is_inside_tree(): return
 var transform := get_viewport_transform() * get_global_transform()
 var parent_pixels := Vector2(transform.x.length(), transform.y.length()) / scale.abs().max(Vector2.ONE * 0.0001)
 scale = CoordinateConverter.calculate_marker_size(current_map_type, base_size) / texture.get_size() / parent_pixels.max(Vector2.ONE * 0.0001)

func set_map_context(mode: String, bounds: Dictionary, texture_size: Vector2) -> void:
 current_map_type = mode
 map_bounds = bounds
 map_texture_size = texture_size
 update_appearance()

func set_world_position(point: Vector2) -> void:
 world_position = point
 update_appearance()
