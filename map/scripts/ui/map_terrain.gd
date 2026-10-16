extends Node2D
## 以现有地形数据生成概览/精细色块，不加载游戏物理节点。
var data: Dictionary = {}
var bounds: Rect2
var texture_size: Vector2
var detailed: bool
## config 是规范化地图数据；region 为局部边界，pixels 为背景尺寸。
func setup(config: Dictionary, region: Rect2, pixels: Vector2, local: bool) -> void:
 data = config
 bounds = region
 texture_size = pixels
 detailed = local
 queue_redraw()
## 绘制可见区域地形，精细模式额外显示墙壁与格线；无参数。
func _draw() -> void:
 if data.is_empty() or bounds.size.x <= 0 or bounds.size.y <= 0: return
 var tile := float(data.tile_size)
 var stride := 1 if detailed else int(MapDatabase.settings.overview_stride)
 var ratio := texture_size / bounds.size
 var line_width := 1.0 / maxf(get_global_transform().get_scale().x, 0.001)
 var start_x := maxi(0, floori(bounds.position.x / tile))
 var start_y := maxi(0, floori(bounds.position.y / tile))
 var end_x := mini(int(data.width), ceili(bounds.end.x / tile))
 var end_y := mini(int(data.height), ceili(bounds.end.y / tile))
 for y in range(start_y, end_y, stride):
  for x in range(start_x, end_x, stride):
   var terrain: Dictionary = data.terrain_types[data.terrain_rows[y][x]]
   var world_rect := Rect2(Vector2(x, y) * tile, Vector2.ONE * tile * stride).intersection(bounds)
   var pixel_rect := Rect2((world_rect.position - bounds.position) * ratio, world_rect.size * ratio)
   var color := Color.html(terrain.color)
   color.a = float(MapDatabase.settings.terrain_opacity)
   draw_rect(pixel_rect, color)
   if detailed:
    draw_rect(pixel_rect, Color(MapDatabase.settings.grid_color), false, line_width)
    if terrain.solid: draw_rect(pixel_rect.grow(-pixel_rect.size.x * 0.15), Color(MapDatabase.settings.grid_color), false, line_width * 1.5)
