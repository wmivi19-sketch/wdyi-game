@tool
class_name SceneElement
extends Node3D
## 可复用的 HD-2D 元素。原点就是摆放、旋转及缩放的中心。
## 在检查器修改参数即更新；碰撞按尺寸重建，避免非均匀缩放物理节点。

enum Pivot { TOP_LEFT, TOP_CENTER, TOP_RIGHT, MIDDLE_LEFT, CENTER, MIDDLE_RIGHT, BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT }
enum CollisionMode { SILHOUETTE, BOUNDS, DISABLED }

@export_group("贴图与尺寸")
## 拖入 PNG 或其他 Texture2D。透明像素会从碰撞外轮廓中排除。
@export var texture: Texture2D:
	set(value):
		if texture != null and texture.changed.is_connected(_invalidate_texture):
			texture.changed.disconnect(_invalidate_texture)
		texture = value
		if texture != null:
			texture.changed.connect(_invalidate_texture)
		_invalidate_texture()
## 每个像素对应多少米；默认 100 像素 = 1 米。
@export_range(0.0001, 0.1, 0.0001, "or_greater") var pixel_size: float = 0.01:
	set(value):
		pixel_size = maxf(value, 0.0001)
		_schedule_update()
## 推荐使用这里缩放。X 为宽，Y 为高，碰撞同步更新。
@export var size_scale: Vector2 = Vector2.ONE:
	set(value):
		size_scale = Vector2(maxf(value.x, 0.001), maxf(value.y, 0.001))
		_schedule_update()

@export_group("中心点与镜像")
@export_enum("左上", "上中", "右上", "左中", "居中", "右中", "左下", "下中（默认）", "右下") var pivot: int = Pivot.BOTTOM_CENTER:
	set(value):
		pivot = clampi(value, 0, 8)
		_schedule_update()
## 开启时，以可见内容的边界定位，避免透明留白导致悬空。
@export var trim_transparent_border: bool = true:
	set(value):
		trim_transparent_border = value
		_schedule_update()
## 相对九宫格点的额外中心偏移，单位像素，右/下为正。
@export var pivot_offset_pixels: Vector2 = Vector2.ZERO:
	set(value):
		pivot_offset_pixels = value
		_schedule_update()
@export var flip_h: bool = false:
	set(value):
		flip_h = value
		_schedule_update()
@export var flip_v: bool = false:
	set(value):
		flip_v = value
		_schedule_update()

@export_group("自动碰撞")
@export_enum("透明外轮廓", "可见边界矩形", "关闭") var collision_mode: int = CollisionMode.SILHOUETTE:
	set(value):
		collision_mode = value
		_schedule_update()
## 三维碰撞厚度，单位米；随宽度缩放一起变化。
@export_range(0.01, 5.0, 0.01, "or_greater") var collision_depth: float = 0.3:
	set(value):
		collision_depth = maxf(value, 0.01)
		_schedule_update()
@export_flags_3d_physics var collision_layer: int = 1:
	set(value):
		collision_layer = value
		_schedule_update()
@export_flags_3d_physics var collision_mask: int = 1:
	set(value):
		collision_mask = value
		_schedule_update()
## 透明度低于此值的区域不生成碰撞。
@export_range(0.01, 0.99, 0.01) var alpha_threshold: float = 0.1:
	set(value):
		alpha_threshold = value
		_invalidate_texture()
## 越小越贴近轮廓，越大越省物理开销，单位为原图像素。
@export_range(0.5, 20.0, 0.5) var outline_simplification: float = 3.0:
	set(value):
		outline_simplification = value
		_invalidate_texture()

@export_group("显示")
## 颜色乘数，可用于统一场景明暗与色温。
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		_schedule_update()
@export var receive_lighting: bool = true:
	set(value):
		receive_lighting = value
		_schedule_update()
@export_tool_button("重新识别贴图与碰撞") var rebuild_action: Callable = _invalidate_texture

var _update_pending: bool = false
var _texture_dirty: bool = true
var _image_size: Vector2 = Vector2.ZERO
var _visible_rect: Rect2 = Rect2()
var _outlines: Array[PackedVector2Array] = []

func _ready() -> void:
	_rebuild()

func _invalidate_texture() -> void:
	_texture_dirty = true
	_schedule_update()

func _schedule_update() -> void:
	if not is_inside_tree() or _update_pending:
		return
	_update_pending = true
	_rebuild.call_deferred()

func _read_texture() -> void:
	_texture_dirty = false
	_outlines.clear()
	_image_size = Vector2.ZERO
	_visible_rect = Rect2()
	if texture == null:
		return
	var source: Image = texture.get_image()
	if source == null or source.is_empty():
		return
	if source.is_compressed() and source.decompress() != OK:
		return
	_image_size = Vector2(source.get_size())
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(source, alpha_threshold)
	# 使用原始像素分辨率分析轮廓；仅换图或调整精度时重新计算。
	var polygons := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, source.get_size()), outline_simplification)
	var first := true
	for polygon in polygons:
		if polygon.size() < 3:
			continue
		_outlines.append(polygon)
		for point in polygon:
			if first:
				_visible_rect = Rect2(point, Vector2.ZERO)
				first = false
			else:
				_visible_rect = _visible_rect.expand(point)
	if first:
		_visible_rect = Rect2()

func _mirrored_rect() -> Rect2:
	var rect := _visible_rect if trim_transparent_border else Rect2(Vector2.ZERO, _image_size)
	if flip_h:
		rect.position.x = _image_size.x - rect.end.x
	if flip_v:
		rect.position.y = _image_size.y - rect.end.y
	return rect

func get_pivot_pixels() -> Vector2:
	var rect := _mirrored_rect()
	var fraction := Vector2(float(pivot % 3) * 0.5, floorf(float(pivot) / 3.0) * 0.5)
	return rect.position + rect.size * fraction + pivot_offset_pixels

func _pixel_to_local(point: Vector2, anchor: Vector2) -> Vector2:
	if flip_h:
		point.x = _image_size.x - point.x
	if flip_v:
		point.y = _image_size.y - point.y
	return Vector2((point.x - anchor.x) * pixel_size * size_scale.x,
		(anchor.y - point.y) * pixel_size * size_scale.y)

func _rebuild() -> void:
	_update_pending = false
	if not is_inside_tree() or not has_node("Visual") or not has_node("Body"):
		return
	if _texture_dirty:
		_read_texture()
	var visual: Sprite3D = $Visual
	var body: StaticBody3D = $Body
	visual.texture = texture
	visual.visible = texture != null and _visible_rect.has_area()
	visual.pixel_size = pixel_size
	visual.scale = Vector3(size_scale.x, size_scale.y, 1.0)
	visual.flip_h = flip_h
	visual.flip_v = flip_v
	visual.shaded = receive_lighting
	visual.modulate = tint
	visual.alpha_scissor_threshold = alpha_threshold
	body.collision_layer = collision_layer
	body.collision_mask = collision_mask
	for child in body.get_children(true):
		body.remove_child(child)
		child.queue_free()
	if texture == null or not _visible_rect.has_area():
		update_configuration_warnings()
		return
	var anchor := get_pivot_pixels()
	# Sprite3D offset 使用向上为正的局部坐标；不移动根节点。
	visual.position = Vector3((_image_size.x * 0.5 - anchor.x) * pixel_size * size_scale.x,
		(anchor.y - _image_size.y * 0.5) * pixel_size * size_scale.y, 0.0)
	if collision_mode == CollisionMode.DISABLED:
		return
	var contours: Array[PackedVector2Array] = _outlines
	if collision_mode == CollisionMode.BOUNDS:
		var r := _visible_rect
		contours = [PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])]
	for contour in contours:
		var polygon := PackedVector2Array()
		for point in contour:
			polygon.append(_pixel_to_local(point, anchor))
		var collision := CollisionPolygon3D.new()
		collision.name = "AutoCollision"
		collision.depth = collision_depth * size_scale.x
		collision.polygon = polygon
		# 内部节点不会被保存进模板，重开场景时重新生成，实例互不污染。
		body.add_child(collision, false, Node.INTERNAL_MODE_BACK)
	update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if texture == null:
		warnings.append("请在「贴图与尺寸 → Texture」拖入元素贴图。")
	elif not _visible_rect.has_area():
		warnings.append("贴图没有可见像素，或无法读取图像；请检查透明度阈值。")
	if not scale.is_equal_approx(Vector3.ONE):
		warnings.append("建议保持 Transform Scale = (1,1,1)，使用 Size Scale 缩放，以保持物理碰撞稳定。")
	return warnings
