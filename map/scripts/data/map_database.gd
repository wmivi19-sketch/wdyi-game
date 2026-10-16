extends Node
## 地图配置与美术容错；不与已有 MapLoader 的地形数据库混淆。
signal database_reloaded
var continent_configs: Dictionary = {}
var area_configs: Dictionary = {}
var settings: Dictionary = {}
var atlas_config: Dictionary = {}
var cache: Dictionary = {}
var cache_order: Array[String] = []
var elapsed: float = 0.0
var fingerprint: String = ""
## 初始化配置；无参数。
func _ready() -> void:
 reload()
 fingerprint = signature()
## 对三个文件一起验证并提交；无参数。
func reload() -> bool:
 var continents := Config.read_json("res://resources/maps/continents.json")
 var areas := Config.read_json("res://resources/maps/areas.json")
 var options := Config.read_json("res://resources/maps/map_settings.json")
 var atlas := Config.read_json("res://resources/maps/atlas.json")
 if not validate(continents, areas, options) or not validate_atlas(atlas, continents):
  push_warning("地图配置无效，保留有效版本")
  return false
 continent_configs = continents
 area_configs = areas
 settings = options
 atlas_config = atlas
 cache.clear()
 cache_order.clear()
 database_reloaded.emit()
 return true
## 检查配置形状、正面积边界和数值；不会改写生效配置。
func validate(continents: Dictionary, areas: Dictionary, options: Dictionary) -> bool:
 if continents.is_empty() or areas.is_empty(): return false
 for key in ["min_zoom","max_zoom","zoom_step","overview_size","local_size","icon_size","marker_pixels","label_size","overview_stride","detail_refresh_seconds","poll_seconds","texture_cache_limit","fit_margin","min_visible_pixels","terrain_opacity"]:
  if not options.has(key) or not Config.numeric(options[key]) or options[key] <= 0: return false
 if options.min_zoom > 1 or options.max_zoom < 1 or options.min_zoom > options.max_zoom or options.fit_margin > 1 or options.terrain_opacity > 1: return false
 for key in ["overview_size", "local_size", "icon_size", "label_size", "overview_stride", "texture_cache_limit"]:
  if options[key] != floor(float(options[key])): return false
 if options.overview_size > 4096 or options.local_size > 4096 or options.icon_size > 256: return false
 for key in ["overview_color", "local_color", "grid_color"]:
  if not options.get(key) is String or not Color.html_is_valid(options[key]): return false
 if not options.get("marker_paths") is Dictionary or not options.get("marker_colors") is Dictionary: return false
 for kind in ["player","npc","enemy","chest","exchange","altar","portal","artifact"]:
  if not valid_path(options.marker_paths.get(kind)): return false
  if not options.marker_colors.get(kind) is String or not Color.html_is_valid(options.marker_colors[kind]): return false
 for id in continents:
  var entry = continents[id]
  if not valid_entry(entry) or not entry.get("map_id") is String or not entry.get("default_area") is String or not valid_markers(entry.get("pois"), true): return false
  if not areas.has(entry.default_area) or areas[entry.default_area].get("continent_id") != id: return false
 for id in areas:
  var entry = areas[id]
  if not valid_entry(entry) or not continents.has(entry.get("continent_id")): return false
  for key in ["npcs", "enemies", "chests"]:
   if not valid_markers(entry.get(key), false): return false
 return true
## entry 为单地图配置；验证资源路径与矩形边界。
func valid_entry(entry: Variant) -> bool:
 if not entry is Dictionary or not entry.get("name") is String: return false
 if not valid_path(entry.get("texture_path")) or not valid_path(entry.get("placeholder_path")): return false
 var bounds = entry.get("bounds")
 if not bounds is Dictionary or not valid_point(bounds.get("begin")) or not valid_point(bounds.get("end")): return false
 return bounds.end.x > bounds.begin.x and bounds.end.y > bounds.begin.y
## paths 只允许 res:// 资源，不允许目录逃逸；path 是待验证字段。
func valid_path(path: Variant) -> bool:
 return path is String and (path.is_empty() or (path.begins_with("res://") and not ".." in path))
## 校验二维坐标，拒绝缺字段及 NaN；point 为 JSON 坐标对象。
func valid_point(point: Variant) -> bool:
 return point is Dictionary and Config.numeric(point.get("x")) and Config.numeric(point.get("y"))
## entries 为标记数组；typed 表示 POI 必须具备类型。
func valid_markers(entries: Variant, typed: bool) -> bool:
 if not entries is Array: return false
 var ids: Dictionary = {}
 for entry in entries:
  if not entry is Dictionary or not entry.get("id") is String or entry.id.is_empty() or ids.has(entry.id) or not entry.get("name") is String or not valid_point(entry.get("position")): return false
  if typed and entry.get("type") not in ["exchange", "altar", "portal", "artifact"]: return false
  ids[entry.id] = true
 return true
## 返回大陆 POI 独立副本；id 为大陆 ID。
func get_pois(id: String) -> Array:
 return continent_configs.get(id, {}).get("pois", []).duplicate(true)
## 返回区域 NPC；id 为区域 ID。
func get_npcs(id: String) -> Array:
 return area_configs.get(id, {}).get("npcs", []).duplicate(true)
## 返回区域敌人；id 为区域 ID。
func get_enemies(id: String) -> Array:
 return area_configs.get(id, {}).get("enemies", []).duplicate(true)
## 返回区域宝箱；id 为区域 ID。
func get_chests(id: String) -> Array:
 return area_configs.get(id, {}).get("chests", []).duplicate(true)
## config 是单张地图数据；返回其地图局部坐标矩形。
func bounds_of(config: Dictionary) -> Rect2:
 var bounds: Dictionary = config.get("bounds", {})
 if bounds.is_empty(): return Rect2()
 var begin := vector(bounds.begin)
 return Rect2(begin, vector(bounds.end) - begin)
## id 为大陆 ID；返回矩形，未知时返回空矩形。
func get_map_bounds(id: String) -> Rect2:
 return bounds_of(continent_configs.get(id, {}))
## point 为 JSON x/y 对象；转成 Vector2。
func vector(point: Dictionary) -> Vector2:
 return Vector2(float(point.x), float(point.y))
## 根据实际加载地图 ID 查询大陆；不会采用失败的切图请求。
func continent_for_map(map_id: String) -> String:
 for id in continent_configs:
  if continent_configs[id].map_id == map_id: return id
 return ""
## 在大陆下选择包含 position 的最小区域，未命中返回配置默认区域。
func area_for_position(continent: String, position: Vector2) -> String:
 var result := str(continent_configs.get(continent, {}).get("default_area", ""))
 var smallest := INF
 for id in area_configs:
  var entry: Dictionary = area_configs[id]
  var bounds := bounds_of(entry)
  if entry.continent_id == continent and bounds.has_point(position) and bounds.get_area() < smallest:
   result = id
   smallest = bounds.get_area()
 return result
## 资源不存在/类型不符返回 null；path 为配置路径。
func safe_texture(path: String) -> Texture2D:
 if path.is_empty() or not ResourceLoader.exists(path): return null
 return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
## 取得指定地图背景，优先美术、其次占位文件、最后运行时纯色图。
func map_texture(id: String, local: bool) -> Texture2D:
 var key := ("local:" if local else "continent:") + id
 if cache.has(key): return cache[key]
 var entry: Dictionary = (area_configs if local else continent_configs).get(id, {})
 var texture := safe_texture(str(entry.get("texture_path", "")))
 if texture == null: texture = safe_texture(str(entry.get("placeholder_path", "")))
 if texture == null:
  var size_value := int(settings.local_size if local else settings.overview_size)
  texture = placeholder(size_value, Color(settings.local_color if local else settings.overview_color))
 remember(key, texture)
 return texture
## 生成纯色方块纹理；size_value 是边长，color 是颜色。
func placeholder(size_value: int, color: Color) -> Texture2D:
 var bitmap := Image.create(size_value, size_value, false, Image.FORMAT_RGBA8)
 bitmap.fill(color)
 return ImageTexture.create_from_image(bitmap)
## 获取标记图标；缺失时生成对应颜色方块并缓存。
func marker_texture(kind: String) -> Texture2D:
 var key := "icon:" + kind
 if cache.has(key): return cache[key]
 var texture := safe_texture(str(settings.marker_paths.get(kind, "")))
 if texture == null: texture = placeholder(int(settings.icon_size), Color(settings.marker_colors.get(kind, "#ffffff")))
 remember(key, texture)
 return texture
## 有界纹理缓存；key 是缓存键，texture 为已加载纹理。
func remember(key: String, texture: Texture2D) -> void:
 if cache.has(key): cache_order.erase(key)
 cache[key] = texture
 cache_order.append(key)
 while cache_order.size() > int(settings.texture_cache_limit): cache.erase(cache_order.pop_front())
## 计算配置内容哈希；无参数。
func signature() -> String:
 var content := ""
 for file in ["continents.json", "areas.json", "map_settings.json", "atlas.json"]:
  var path: String = "res://resources/maps/" + str(file)
  content += FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "missing:" + file
 return content.sha256_text()
## 监视 JSON 热重载；delta 是真实帧耗时。
func _process(delta: float) -> void:
 if settings.is_empty(): return
 elapsed += delta
 if elapsed < float(settings.poll_seconds): return
 elapsed = 0.0
 var latest := signature()
 if latest != fingerprint:
  fingerprint = latest
  reload()

## atlas 为世界图配置；regions 必须覆盖所有现有大陆且位于图片边界内。
func validate_atlas(atlas: Dictionary, continents: Dictionary) -> bool:
 if not atlas.get("enabled") is bool or not atlas.get("name") is String or not valid_path(atlas.get("texture_path")): return false
 for key in ["width", "height"]:
  if not Config.numeric(atlas.get(key)) or atlas[key] <= 0 or atlas[key] > 8192 or atlas[key] != floor(float(atlas[key])): return false
 if not atlas.get("regions") is Dictionary: return false
 for id in continents:
  var entry = atlas.regions.get(id)
  if not entry is Dictionary or not entry.get("rect") is Dictionary or not valid_point(entry.get("label_position")): return false
  var label_point := vector(entry.label_position)
  if label_point.x < 0 or label_point.y < 0 or label_point.x > atlas.width or label_point.y > atlas.height: return false
  var rect: Dictionary = entry.rect
  for key in ["x", "y", "width", "height"]:
   if not Config.numeric(rect.get(key)): return false
  if rect.x < 0 or rect.y < 0 or rect.width <= 0 or rect.height <= 0 or rect.x + rect.width > atlas.width or rect.y + rect.height > atlas.height: return false
 return true
## 返回大陆在世界原图上的校准矩形；id 为大陆ID。
func atlas_region(id: String) -> Rect2:
 var data: Dictionary = atlas_config.get("regions", {}).get(id, {}).get("rect", {})
 if data.is_empty(): return Rect2()
 return Rect2(float(data.x), float(data.y), float(data.width), float(data.height))
## 把现有大陆局部坐标映射到世界图像素；不改写玩家真实位置。
func atlas_point(id: String, point: Vector2) -> Vector2:
 var source := get_map_bounds(id)
 var target := atlas_region(id)
 if source.size.x <= 0 or source.size.y <= 0: return Vector2.ZERO
 return target.position + (point - source.position) / source.size * target.size
## 世界底图沿用原图比例；缺资源时按配置尺寸生成安全占位背景。
func atlas_texture() -> Texture2D:
 if cache.has("atlas"): return cache["atlas"]
 var texture := safe_texture(str(atlas_config.texture_path))
 if texture == null:
  var image := Image.create(int(atlas_config.width), int(atlas_config.height), false, Image.FORMAT_RGBA8)
  image.fill(Color(settings.overview_color))
  texture = ImageTexture.create_from_image(image)
 remember("atlas", texture)
 return texture
