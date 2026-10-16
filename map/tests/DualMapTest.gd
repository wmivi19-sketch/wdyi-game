extends Node
var failures: int = 0
var checks: int = 0
var demo: Node
var maps: MapSystem
## 自动加载就绪后测试；无参数。
func _ready() -> void:
 call_deferred("run")
## condition 为断言，description 为说明。
func check(condition: bool, description: String) -> void:
 checks += 1
 if condition: print("PASS: ", description)
 else:
  failures += 1
  push_error(description)
## code 为按键，echo_value 测试按住重复不会反复开关。
func key(code: Key, echo_value: bool = false) -> void:
 var event := InputEventKey.new()
 event.keycode = code
 event.physical_keycode = code
 event.pressed = true
 event.echo = echo_value
 Input.parse_input_event(event)
 var release := event.duplicate() as InputEventKey
 release.pressed = false
 release.echo = false
 Input.parse_input_event(release)
## input 为视口 GUI 事件；local 为区域模式。
func send_map_input(input: InputEvent, local: bool) -> void:
 maps.panel_for(local).get_node("MapViewport").gui_input.emit(input)
## 可选真实渲染截图；name_value 为标签。
func capture(name_value: String) -> void:
 if not OS.get_cmdline_user_args().has("--capture-maps"): return
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute("res://.validation")
 get_viewport().get_texture().get_image().save_png("res://.validation/map-" + name_value + ".png")
## 驱动真正 MapDemo 和现有角色；无参数。
func run() -> void:
 get_window().size = Vector2i(1080, 740)
 demo = preload("res://scenes/MapDemo.tscn").instantiate()
 add_child(demo)
 for frame in 6: await get_tree().process_frame
 maps = demo.map_system
 demo.player.set_physics_process(false)
 check(not maps.any_open(), "两种地图初始关闭")
 check(maps.continent_texture_node.texture == null and maps.local_texture_node.texture == null, "关闭时不提前分配背景纹理")
 check(GameState.current_continent == "continent_0", "绑定实际加载大陆")
 check(GameState.current_area == "area_0", "初始化当前区域")
 key(KEY_Y)
 for frame in 3: await get_tree().process_frame
 check(maps.is_continent_open and not maps.is_local_open, "Y打开大陆概览")
 check(maps.continent_texture_node.texture.get_width() == int(MapDatabase.atlas_config.width), "世界地图加载上传图片原始宽度")
 check(maps.continent_view.get_node("POILayer").get_child_count() >= 3, "显示交易所祭坛传送门POI")
 check(maps.continent_panel.get_node("MapViewport/SubViewport").world_2d != get_viewport().world_2d, "地图视口与游戏世界隔离")
 var expected := MapDatabase.atlas_region(GameState.current_continent).get_center()
 var bounds := MapDatabase.get_map_bounds(GameState.current_continent)
 demo.player.teleport_to(demo.loader.to_global(bounds.get_center()))
 await get_tree().process_frame
 check(maps.continent_view.get_node("PlayerMarker").position.is_equal_approx(expected), "地图中心玩家点正确考虑加载器偏移")
 check(GameState.player_world_position.is_equal_approx(demo.player.global_position), "全局玩家坐标实时同步")
 await capture("continent")
 var screen_point := Vector2(maps.continent_panel.get_node("MapViewport/SubViewport").size) * Vector2(0.4, 0.6)
 var before := (screen_point - maps.continent_view.position) / maps.continent_view.scale
 maps.zoom_kind(false, 1, screen_point)
 var after := (screen_point - maps.continent_view.position) / maps.continent_view.scale
 check(before.is_equal_approx(after), "鼠标锚点缩放不漂移")
 for index in 30: maps.zoom_kind(false, 1)
 check(is_equal_approx(maps.continent_zoom, float(MapDatabase.settings.max_zoom)), "缩放上限")
 for index in 30: maps.zoom_kind(false, -1)
 check(is_equal_approx(maps.continent_zoom, float(MapDatabase.settings.min_zoom)), "缩放下限")
 maps.reset_kind(false)
 # 经真实GUI路由进入SubViewportContainer，而非只调用控制器函数。
 var container: Control = maps.continent_panel.get_node("MapViewport")
 var start := get_viewport().get_screen_transform() * (container.global_position + Vector2(100, 100))
 var real_down := InputEventMouseButton.new()
 real_down.button_index = MOUSE_BUTTON_LEFT
 real_down.pressed = true
 real_down.position = start
 Input.parse_input_event(real_down)
 var real_motion := InputEventMouseMotion.new()
 real_motion.position = start + Vector2(15, 10)
 real_motion.relative = Vector2(15, 10)
 real_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
 Input.parse_input_event(real_motion)
 var real_up := real_down.duplicate() as InputEventMouseButton
 real_up.position = real_motion.position
 real_up.pressed = false
 Input.parse_input_event(real_up)
 await get_tree().process_frame
 check(maps.continent_pan.is_equal_approx(Vector2(15, 10)), "实际鼠标输入经视口GUI路由拖动地图")
 maps.reset_kind(false)
 var down := InputEventMouseButton.new()
 down.button_index = MOUSE_BUTTON_LEFT
 down.pressed = true
 down.position = Vector2(100, 100)
 send_map_input(down, false)
 var motion := InputEventMouseMotion.new()
 motion.position = Vector2(140, 130)
 send_map_input(motion, false)
 var up := down.duplicate() as InputEventMouseButton
 up.pressed = false
 send_map_input(up, false)
 check(maps.continent_pan.is_equal_approx(Vector2(40, 30)) and not maps.is_dragging, "鼠标拖拽与松开终止")
 var wheel := down.duplicate() as InputEventMouseButton
 wheel.button_index = MOUSE_BUTTON_WHEEL_UP
 send_map_input(wheel, false)
 check(maps.continent_zoom > 1.0, "地图视口滚轮放大")
 var overlay_scale: Vector2 = maps.continent_panel.get_node("UIOverlay").scale
 check(overlay_scale == Vector2.ONE, "地图缩放不影响UI按钮")
 key(KEY_M)
 for frame in 3: await get_tree().process_frame
 check(maps.is_local_open and not maps.is_continent_open, "M切到区域并关闭大陆图")
 check(maps.local_texture_node.texture.get_width() == int(MapDatabase.settings.local_size), "缺失区域美术生成2048占位图")
 for layer in ["NPCMarkers", "EnemyMarkers", "ChestMarkers"]:
  check(maps.local_view.get_node(layer).get_child_count() > 0, "区域配置图层：" + layer)
 check(maps.continent_panel.get_node("MapViewport/SubViewport").render_target_update_mode == SubViewport.UPDATE_DISABLED, "隐藏视口停止渲染")
 check(is_equal_approx(maps.local_zoom, 1.0), "两地图缩放独立")
 var live := Node2D.new()
 live.name = "动态NPC"
 demo.add_child(live)
 live.add_to_group("map_npcs")
 live.set_meta("map_marker_id", "live_npc")
 live.set_meta("map_marker_name", "移动商人")
 live.position = demo.loader.to_global(Vector2(150, 150))
 maps.refresh_maps()
 var marker: Node2D = maps.local_view.marker_nodes["NPCMarkers:live_npc"]
 var marker_position := marker.position
 live.position += Vector2(20, 10)
 maps.refresh_maps()
 check(marker == maps.local_view.marker_nodes["NPCMarkers:live_npc"] and marker.position != marker_position, "动态标记复用节点并跟随实体")
 live.queue_free()
 await get_tree().process_frame
 maps.refresh_maps()
 check(not maps.local_view.marker_nodes.has("NPCMarkers:live_npc"), "已移除实体不留残影")
 await capture("local")
 var day := GameManager.current_day
 var period := GameManager.current_period
 key(KEY_SPACE)
 await get_tree().process_frame
 check(day == GameManager.current_day and period == GameManager.current_period, "地图窗口阻止时间热键穿透")
 key(KEY_M, true)
 await get_tree().process_frame
 check(maps.is_local_open, "按键重复不关闭地图")
 key(KEY_TAB)
 await get_tree().process_frame
 check(not maps.any_open() and demo.character_info_ui.character_info_panel.visible, "Tab切回统一玩家面板")
 key(KEY_Y)
 await get_tree().process_frame
 check(maps.is_continent_open and not demo.character_info_ui.character_info_panel.visible, "从背包直接切到大陆图互斥")
 key(KEY_ESCAPE)
 await get_tree().process_frame
 check(not maps.any_open(), "Esc关闭地图")
 GameManager.switch_to_continent(4)
 for frame in 5: await get_tree().process_frame
 demo.player.teleport_to(demo.loader.to_global(Vector2(220, 220)))
 await get_tree().process_frame
 check(GameState.current_continent == "continent_4" and GameState.current_area == "area_volcano", "切大陆并自动识别子区域")
 key(KEY_M)
 for frame in 3: await get_tree().process_frame
 check(maps.local_view.bounds.size == Vector2(200, 200), "区域图使用独立200x200边界")
 check(maps.local_view.get_node("PlayerMarker").position.is_equal_approx(maps.local_texture_node.texture.get_size() / 2.0), "子区域中心映射不误用大陆边界")
 check(GameState.player_location != GameState.current_area, "区域ID不覆盖合成/交易地点")
 var touch := InputEventScreenTouch.new()
 touch.index = 2
 touch.position = Vector2(100, 100)
 touch.pressed = true
 send_map_input(touch, true)
 var drag := InputEventScreenDrag.new()
 drag.index = 2
 drag.position = Vector2(125, 105)
 send_map_input(drag, true)
 touch.pressed = false
 send_map_input(touch, true)
 check(maps.local_pan.is_equal_approx(Vector2(25, 5)), "触摸拖动独立区域图")
 var zoom_before := maps.local_zoom
 var outside := wheel.duplicate() as InputEventMouseButton
 outside.position = Vector2(-20, -20)
 send_map_input(outside, true)
 check(is_equal_approx(zoom_before, maps.local_zoom), "视口外滚轮不缩放")
 get_window().size = Vector2i(480, 800)
 for frame in 5: await get_tree().process_frame
 maps.layout_view(true)
 check(maps.local_panel.get_node("MapViewport/SubViewport").size.x == 448, "地图视口适配480像素窄屏")
 await capture("narrow")
 maps.local_panel.get_node("UIOverlay/ZoomControls/ResetBtn").pressed.emit()
 check(maps.local_pan == Vector2.ZERO and is_equal_approx(maps.local_zoom, 1.0), "按钮重置缩放和平移")
 maps.local_panel.get_node("UIOverlay/CloseBtn").pressed.emit()
 check(not maps.any_open(), "关闭按钮生效")
 var invalid := MapDatabase.continent_configs.duplicate(true)
 invalid.continent_0.bounds.end.x = invalid.continent_0.bounds.begin.x
 check(not MapDatabase.validate(invalid, MapDatabase.area_configs, MapDatabase.settings), "拒绝零宽边界")
 var invalid_options := MapDatabase.settings.duplicate(true)
 invalid_options.min_zoom = 0
 check(not MapDatabase.validate(MapDatabase.continent_configs, MapDatabase.area_configs, invalid_options), "拒绝非法缩放设置")
 check(MapDatabase.safe_texture("res://assets/maps/nonexistent.png") == null, "缺失纹理安全回退")
 check(MapDatabase.get_pois("unknown").is_empty(), "未知大陆安全返回空列表")
 check(MapDatabase.cache.size() <= int(MapDatabase.settings.texture_cache_limit), "纹理缓存有界")
 check(ClassManager.players[1].inventory.shared == GameState.player_inventory, "职业背包仍为同一权威数据")
 print("Dual maps: %d checks, %d failures" % [checks, failures])
 get_tree().quit(0 if failures == 0 else 1)
