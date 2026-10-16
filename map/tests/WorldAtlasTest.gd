extends Node
var failures: int = 0
var checks: int = 0
## 自动加载就绪后执行；无参数。
func _ready() -> void:
 call_deferred("run")
## condition 为断言，message 为检查说明。
func check(condition: bool, message: String) -> void:
 checks += 1
 if condition: print("PASS: ", message)
 else:
  failures += 1
  push_error(message)
## 对真实场景进行世界图、坐标校准与容错检查；无参数。
func run() -> void:
 get_window().size = Vector2i(1080, 740)
 var world = preload("res://scenes/MapDemo.tscn").instantiate()
 add_child(world)
 for frame in 6: await get_tree().process_frame
 world.player.set_physics_process(false)
 var maps: MapSystem = world.map_system
 var atlas: Dictionary = MapDatabase.atlas_config
 var inventory: Inventory = world.get_node("WorldItems").inventory
 var snapshot := inventory.snapshot()
 check(FileAccess.get_sha256(atlas.texture_path) == atlas.source_sha256, "上传图片原文件完整保存，SHA256一致")
 maps._open_continent()
 for frame in 2: await get_tree().process_frame
 check(maps.continent_texture_node.texture.get_size() == Vector2(1536, 1024), "按原始1536x1024尺寸加载整张世界图")
 check(not maps.continent_view.get_node("TerrainLayer").visible, "世界原图不被旧色块地形覆盖")
 var labels := 0
 for key in maps.continent_view.marker_nodes:
  if key.begins_with("POILayer:continent_name:"): labels += 1
 check(labels == 6, "世界图显示全部六大陆名称")
 check(maps.continent_view.scale.x == maps.continent_view.scale.y, "保持图片宽高比例")
 for id in MapDatabase.continent_configs:
  var bounds := MapDatabase.get_map_bounds(id)
  var region := MapDatabase.atlas_region(id)
  check(MapDatabase.atlas_point(id, bounds.get_center()).is_equal_approx(region.get_center()), "大陆中心校准：" + id)
  check(MapDatabase.atlas_point(id, bounds.position).is_equal_approx(region.position), "大陆原点校准：" + id)
  check(MapDatabase.atlas_point(id, bounds.end).is_equal_approx(region.end), "大陆边界校准：" + id)
 for index in 6:
  GameManager.switch_to_continent(index)
  for frame in 4: await get_tree().process_frame
  var id := "continent_%d" % index
  var point := MapDatabase.get_map_bounds(id).get_center()
  world.player.teleport_to(world.loader.to_global(point))
  await get_tree().process_frame
  var expected: Vector2 = maps.continent_view.map_point(MapDatabase.atlas_point(id, point))
  check(maps.continent_view.get_node("PlayerMarker").position.is_equal_approx(expected), "切大陆后玩家点落在对应岛屿：" + id)
  check(maps.continent_panel.get_node("UIOverlay/TitleLabel").text.contains(MapDatabase.continent_configs[id].name), "切大陆同步当前名称：" + id)
 check(inventory.snapshot() == snapshot, "查看和切地图不修改共享背包")
 # 使用测试纹理检验更换高分辨率版本时仍沿用原图校准坐标，不修改上传原图。
 var image := Image.create(3072, 2048, false, Image.FORMAT_RGBA8)
 var texture := ImageTexture.create_from_image(image)
 maps.continent_view.configure(texture, Rect2(0, 0, atlas.width, atlas.height), {}, false, true)
 var center := MapDatabase.atlas_region("continent_0").get_center()
 check(maps.continent_view.map_point(center).is_equal_approx(center * 2.0), "替换更高分辨率图片不会偏移标记")
 maps.loaded_continent = ""
 maps.configure_view(false)
 var original: String = atlas.texture_path
 atlas.texture_path = "res://assets/maps/world/missing.png"
 MapDatabase.cache.clear()
 MapDatabase.cache_order.clear()
 var placeholder := MapDatabase.atlas_texture()
 check(placeholder.get_size() == Vector2(atlas.width, atlas.height), "大图资源缺失按正确比例生成占位")
 atlas.texture_path = original
 MapDatabase.cache.clear()
 MapDatabase.cache_order.clear()
 maps.loaded_continent = ""
 maps.configure_view(false)
 var broken := atlas.duplicate(true)
 broken.regions.continent_0.rect.width = -1
 check(not MapDatabase.validate_atlas(broken, MapDatabase.continent_configs), "拒绝负尺寸校准矩形")
 broken = atlas.duplicate(true)
 broken.regions.erase("continent_0")
 check(not MapDatabase.validate_atlas(broken, MapDatabase.continent_configs), "拒绝遗漏大陆校准")
 broken = atlas.duplicate(true)
 broken.regions.continent_0.label_position.x = atlas.width + 1
 check(not MapDatabase.validate_atlas(broken, MapDatabase.continent_configs), "拒绝越界标签位置")
 maps._open_local()
 check(maps.is_local_open and not maps.is_continent_open and maps.local_view.get_node("TerrainLayer").visible, "M模式仍使用当前区域精细地形")
 maps._close_local()
 GameManager.switch_to_continent(0)
 for frame in 4: await get_tree().process_frame
 world.player.teleport_to(world.loader.to_global(MapDatabase.get_map_bounds("continent_0").get_center()))
 await get_tree().process_frame
 maps._open_continent()
 if OS.get_cmdline_user_args().has("--capture-atlas"):
  for frame in 3: await get_tree().process_frame
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute("res://.validation")
  get_viewport().get_texture().get_image().save_png("res://.validation/world-atlas.png")
 check(FileAccess.get_sha256(atlas.texture_path) == atlas.source_sha256, "运行结束原图字节保持不变")
 print("World atlas: %d checks, %d failures" % [checks, failures])
 get_tree().quit(0 if failures == 0 else 1)
