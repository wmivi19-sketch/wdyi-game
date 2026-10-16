class_name CoordinateConverter
extends RefCounted
## World coordinates are Godot pixels; one design unit is 32 pixels.
const WORLD_UNIT: float = 32.0
static var _config: Dictionary = {}

static func config() -> Dictionary:
 if _config.is_empty():
  var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://resources/config/scale_config.json"))
  if parsed is Dictionary: _config = parsed
 return _config

static func vector(value: Variant) -> Vector2:
 if value is Vector2: return value
 if value is Array and value.size() == 2: return Vector2(float(value[0]), float(value[1]))
 if value is Dictionary: return Vector2(float(value.get("x", 0)), float(value.get("y", 0)))
 return Vector2.ZERO

static func bounds_rect(bounds: Dictionary) -> Rect2:
 var start := vector(bounds.get("begin", Vector2.ZERO))
 return Rect2(start, vector(bounds.get("end", start)) - start)

static func world_to_map(point: Vector2, bounds: Dictionary, texture_size: Vector2) -> Vector2:
 var rect := bounds_rect(bounds)
 if rect.size.x <= 0 or rect.size.y <= 0 or texture_size.x <= 0 or texture_size.y <= 0: return Vector2.ZERO
 return (point - rect.position) / rect.size * texture_size

static func map_to_world(point: Vector2, bounds: Dictionary, texture_size: Vector2) -> Vector2:
 var rect := bounds_rect(bounds)
 if texture_size.x <= 0 or texture_size.y <= 0: return rect.position
 return rect.position + point / texture_size * rect.size

static func world_to_screen(point: Vector2, camera: Camera2D) -> Vector2:
 return camera.get_canvas_transform() * point

static func screen_to_world(point: Vector2, camera: Camera2D) -> Vector2:
 return camera.get_canvas_transform().affine_inverse() * point

static func fit_margin(mode: String) -> float:
 return float(config().get("maps", {}).get(mode, {}).get("fit_margin", 1.0))

static func calculate_camera_zoom(mode: String, viewport_size: Vector2, bounds: Dictionary) -> float:
 var size := bounds_rect(bounds).size
 if mode == "gameplay" or size.x <= 0 or size.y <= 0:
  return float(config().get("camera", {}).get("default_zoom", 1.0))
 return maxf(0.0001, minf(viewport_size.x / size.x, viewport_size.y / size.y) * fit_margin(mode))

## Returns desired screen pixels. Zoom compensation belongs to the display node.
static func calculate_marker_size(mode: String, base_size: Vector2 = Vector2(32, 32), _zoom: float = 1.0) -> Vector2:
 return vector(config().get("maps", {}).get(mode, {}).get("marker_size", base_size))
