class_name SmartCamera
extends Camera2D
@export var camera_mode: String = "gameplay"
@export var smooth_follow: bool = true
@export var follow_speed: float = 5.0
@export var boundary_margin: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var world_bounds: Dictionary = {}
var _explicit_target: bool = false
var _zoom_tween: Tween

func _ready() -> void:
 var settings: Dictionary = CoordinateConverter.config().get("camera", {})
 smooth_follow = bool(settings.get("smooth_follow", smooth_follow))
 follow_speed = float(settings.get("follow_speed", follow_speed))
 position_smoothing_enabled = smooth_follow
 position_smoothing_speed = follow_speed
 get_viewport().size_changed.connect(_update_zoom)
 _update_zoom()

func _process(_delta: float) -> void:
 if _explicit_target:
  global_position = target_position
 _clamp_to_bounds()

func set_target(point: Vector2) -> void:
 target_position = point
 _explicit_target = true

func set_mode(mode: String, bounds: Dictionary) -> void:
 camera_mode = mode
 world_bounds = bounds
 _update_zoom()

func _update_zoom() -> void:
 if not is_inside_tree(): return
 var value := CoordinateConverter.calculate_camera_zoom(camera_mode, get_viewport_rect().size, world_bounds)
 if _zoom_tween != null: _zoom_tween.kill()
 _zoom_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 _zoom_tween.tween_property(self, "zoom", Vector2.ONE * value, float(CoordinateConverter.config().get("camera", {}).get("transition_seconds", 0.3)))

func _clamp_to_bounds() -> void:
 if world_bounds.is_empty(): return
 var rect := CoordinateConverter.bounds_rect(world_bounds)
 if rect.size.x <= 0 or rect.size.y <= 0: return
 var half_view := get_viewport_rect().size / (2.0 * zoom.abs().max(Vector2.ONE * 0.0001))
 # Camera rotation expands the visible world-space AABB.
 var angle := 0.0 if ignore_rotation else global_rotation
 var half := Vector2(absf(cos(angle)) * half_view.x + absf(sin(angle)) * half_view.y, absf(sin(angle)) * half_view.x + absf(cos(angle)) * half_view.y)
 var low := rect.position + half + Vector2.ONE * boundary_margin
 var high := rect.end - half - Vector2.ONE * boundary_margin
 var point := global_position + offset
 point.x = rect.get_center().x if low.x > high.x else clampf(point.x, low.x, high.x)
 point.y = rect.get_center().y if low.y > high.y else clampf(point.y, low.y, high.y)
 global_position = point - offset
