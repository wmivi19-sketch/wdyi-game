extends Node2D
## 两种地图共用绘制视图；几何坐标从贴图左上角起算。
var bounds: Rect2
var marker_nodes: Dictionary = {}
var pixels: Vector2
## texture 为背景图；region 为地图局部边界；data 为现有地形。
func configure(texture: Texture2D, region: Rect2, data: Dictionary, local: bool, atlas: bool = false) -> void:
 $MapTexture.texture = texture
 $MapTexture.centered = false
 pixels = texture.get_size()
 bounds = region
 $TerrainLayer.setup(data, region, pixels, local)
 $TerrainLayer.visible = not atlas and not has_custom_art(local)
 clear_markers()
## 正式美术存在时关闭色块地形覆盖；local 表示区域图。
func has_custom_art(local: bool) -> bool:
 var id := GameState.current_area if local else GameState.current_continent
 var config: Dictionary = (MapDatabase.area_configs if local else MapDatabase.continent_configs).get(id, {})
 return MapDatabase.safe_texture(str(config.get("texture_path", ""))) != null
## 清理旧标记，不销毁玩家节点；无参数。
func clear_markers() -> void:
 for layer in ["POILayer", "NPCMarkers", "EnemyMarkers", "ChestMarkers"]:
  for child in get_node(layer).get_children():
   get_node(layer).remove_child(child)
   child.queue_free()
 marker_nodes.clear()
## point 为地图局部坐标；返回未缩放贴图坐标。
func map_point(point: Vector2) -> Vector2:
 if bounds.size.x <= 0 or bounds.size.y <= 0: return Vector2.ZERO
 return (point - bounds.position) / bounds.size * pixels
## layer/id/kind 为标记身份；point 是地图局部坐标，name_value 是标签。
func put_marker(layer: String, id: String, kind: String, point: Vector2, name_value: String) -> void:
 var key := layer + ":" + id
 var node: Node2D = marker_nodes.get(key)
 if node == null:
  node = Node2D.new()
  node.name = id.validate_node_name()
  var icon := Sprite2D.new()
  icon.name = "Icon"
  icon.texture = MapDatabase.marker_texture(kind)
  node.add_child(icon)
  var label := Label.new()
  label.name = "Label"
  label.add_theme_font_size_override("font_size", int(MapDatabase.settings.label_size))
  label.add_theme_color_override("font_outline_color", Color.BLACK)
  label.add_theme_constant_override("outline_size", 4)
  label.modulate = Color(MapDatabase.settings.marker_colors.get(kind, "#ffffff"))
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  node.add_child(label)
  get_node(layer).add_child(node)
  marker_nodes[key] = node
 node.position = map_point(point)
 node.visible = bounds.has_point(point)
 node.get_node("Label").text = name_value
 update_marker_scale(node)
## 为已移动离开的动态实体移除残留标记；keys 为当前有效键。
func retain_markers(keys: Array[String]) -> void:
 for key in marker_nodes.keys():
  if key not in keys:
   var node: Node = marker_nodes[key]
   node.get_parent().remove_child(node)
   node.queue_free()
   marker_nodes.erase(key)
## 标记固定屏幕尺寸，防止高分辨率底图将标记缩得过小；node 为标记容器。
func update_marker_scale(node: Node2D) -> void:
 var inverse := 1.0 / maxf(scale.x, 0.001)
 var icon: Sprite2D = node.get_node("Icon")
 icon.scale = Vector2.ONE * float(MapDatabase.settings.marker_pixels) * inverse / icon.texture.get_width()
 var label: Label = node.get_node("Label")
 label.scale = Vector2.ONE * inverse
 label.position = Vector2(float(MapDatabase.settings.marker_pixels), -float(MapDatabase.settings.label_size)) * inverse
## 更新真实玩家标记；point 是地图局部坐标。
func update_player(point: Vector2) -> void:
 var marker: Sprite2D = $PlayerMarker
 marker.texture = MapDatabase.marker_texture("player")
 marker.position = map_point(point)
 marker.visible = bounds.has_point(point)
 marker.scale = Vector2.ONE * float(MapDatabase.settings.marker_pixels) / marker.texture.get_width() / maxf(scale.x, 0.001)
## 视图缩放后重算标签大小；无参数。
func update_all_marker_scales() -> void:
 for node in marker_nodes.values(): update_marker_scale(node)
 layout_marker_labels()
## 同一位置可同时存在祭坛与交易所；避让文字确保POI均可读。
func layout_marker_labels() -> void:
 var placed: Array[Rect2] = []
 var factor := maxf(scale.x, 0.001)
 var viewport_size := get_viewport_rect().size
 for node in marker_nodes.values():
  if not node.visible: continue
  var label: Label = node.get_node("Label")
  var screen_position: Vector2 = position + node.position * factor + label.position * factor
  var size_value := label.get_minimum_size()
  var rect := Rect2(screen_position, size_value)
  rect.position.x = clampf(rect.position.x, 0.0, maxf(0.0, viewport_size.x - size_value.x))
  var attempts := 0
  while attempts < marker_nodes.size():
   var overlap := false
   for occupied in placed:
    if rect.grow(2.0).intersects(occupied):
     overlap = true
     break
   if not overlap: break
   rect.position.y += float(MapDatabase.settings.label_size) + 4.0
   attempts += 1
  label.position = (rect.position - position - node.position * factor) / factor
  placed.append(rect)
