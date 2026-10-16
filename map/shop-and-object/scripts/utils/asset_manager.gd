extends Node
var cache: Dictionary = {}
## 根据物品与路径缓存纹理；无效路径回退占位图。
func get_item_icon(item_id: String, icon_path: String) -> Texture2D:
 var key := item_id + ":" + icon_path
 if cache.has(key): return cache[key]
 var texture: Texture2D
 if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
  texture = ResourceLoader.load(icon_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
 if texture == null:
  var item = ItemDatabase.get_item(item_id)
  texture = generate_placeholder(item.rarity if item != null else 0)
 cache[key] = texture
 return texture
## 清除已缓存图标；无参数。
func clear_cache() -> void:
 cache.clear()
## rarity 为配置颜色列表的索引；生成实色占位图。
func generate_placeholder(rarity: int) -> Texture2D:
 var colors: Array = Config.data["rarity_colors"]
 var size := int(Config.data["icon_size"])
 var bitmap := Image.create(size, size, false, Image.FORMAT_RGBA8)
 bitmap.fill(Color(colors[clampi(rarity, 0, colors.size() - 1)]))
 return ImageTexture.create_from_image(bitmap)
