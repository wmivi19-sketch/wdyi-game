class_name MapSystem
extends Control
## 大陆/区域地图查看器；不传送玩家、不更改职业/交易地点。
@onready var continent_panel: Control = $ContinentMapPanel
@onready var local_panel: Control = $LocalMapPanel
@onready var continent_view: Node2D = $ContinentMapPanel/MapViewport/SubViewport/ContinentMapView
@onready var local_view: Node2D = $LocalMapPanel/MapViewport/SubViewport/LocalMapView
@onready var continent_texture_node: Sprite2D = $ContinentMapPanel/MapViewport/SubViewport/ContinentMapView/MapTexture
@onready var local_texture_node: Sprite2D = $LocalMapPanel/MapViewport/SubViewport/LocalMapView/MapTexture
var world: Node2D
var is_continent_open: bool = false
var is_local_open: bool = false
var continent_zoom: float = 1.0
var local_zoom: float = 1.0
var continent_pan: Vector2 = Vector2.ZERO
var local_pan: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start_pos: Vector2
var drag_pointer: int = -2
var elapsed: float = 0.0
var loaded_continent: String = ""
var loaded_area: String = ""
## 注册按键与控件；无参数。
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 _register_input_actions()
 for local in [false, true]:
  var panel := panel_for(local)
  panel.hide()
  panel.get_node("UIOverlay/CloseBtn").pressed.connect(_close_local if local else _close_continent)
  panel.get_node("UIOverlay/ZoomControls/ZoomInBtn").pressed.connect(zoom_kind.bind(local, 1))
  panel.get_node("UIOverlay/ZoomControls/ZoomOutBtn").pressed.connect(zoom_kind.bind(local, -1))
  panel.get_node("UIOverlay/ZoomControls/ResetBtn").pressed.connect(reset_kind.bind(local))
  panel.get_node("MapViewport").resized.connect(layout_view.bind(local))
  panel.get_node("MapViewport").gui_input.connect(map_input.bind(local))
  panel.get_node("MapViewport/SubViewport").render_target_update_mode = SubViewport.UPDATE_DISABLED
 get_window().focus_exited.connect(cancel_drag)
## actor_world 为现有 MapDemo，不建立第二个玩家对象。
func setup(actor_world: Node2D) -> void:
 world = actor_world
 world.loader.map_loaded.connect(on_map_loaded)
 MapDatabase.database_reloaded.connect(on_database_reloaded)
 if not world.loader.current_data.is_empty(): on_map_loaded(str(world.loader.current_data.id))
## project.godot 未定义动作时补充，不覆盖已有自定义键位。
func _register_input_actions() -> void:
 for pair in [["toggle_continent_map", KEY_Y], ["toggle_local_map", KEY_M]]:
  if not InputMap.has_action(pair[0]):
   InputMap.add_action(pair[0])
   var event := InputEventKey.new()
   event.physical_keycode = pair[1]
   InputMap.action_add_event(pair[0], event)
## 返回模式对应面板；local 为区域模式。
func panel_for(local: bool) -> Control:
 return local_panel if local else continent_panel
## 返回模式对应视图；local 为区域模式。
func view_for(local: bool) -> Node2D:
 return local_view if local else continent_view
## 任一查看窗口打开时返回 true；无参数。
func any_open() -> bool:
 return is_continent_open or is_local_open
## 处理热键并阻止游戏按键穿透；event 为实际输入。
func _input(event: InputEvent) -> void:
 if world == null or MapDatabase.settings.is_empty() or not event is InputEventKey or not event.pressed or event.echo: return
 if event.is_action_pressed("toggle_continent_map"):
  _toggle_continent()
 elif event.is_action_pressed("toggle_local_map"):
  _toggle_local()
 elif any_open() and event.keycode == KEY_F5:
  GameSession.quick_save_feedback()
 elif any_open() and event.keycode == KEY_F10:
  GameSession.return_to_menu()
 elif any_open() and event.is_action_pressed("open_player_panel"):
  close_all()
  world.character_info_ui.character_info_panel.show()
 elif any_open():
  if event.keycode == KEY_ESCAPE: close_all()
 else: return
 get_viewport().set_input_as_handled()
## 切换大陆概览；无参数。
func _toggle_continent() -> void:
 if is_continent_open: _close_continent()
 else: _open_continent()
## 切换区域详情；无参数。
func _toggle_local() -> void:
 if is_local_open: _close_local()
 else: _open_local()
## 打开大陆图，关闭区域图和玩家面板；无参数。
func _open_continent() -> void:
 if GameState.current_continent.is_empty(): return
 _close_local()
 world.character_info_ui.character_info_panel.hide()
 is_continent_open = true
 continent_panel.show()
 configure_view(false)
 continent_panel.get_node("MapViewport/SubViewport").render_target_update_mode = SubViewport.UPDATE_ALWAYS
 layout_view(false)
 refresh_maps()
## 关闭大陆图并停止该 SubViewport 的渲染；无参数。
func _close_continent() -> void:
 is_continent_open = false
 continent_panel.hide()
 continent_panel.get_node("MapViewport/SubViewport").render_target_update_mode = SubViewport.UPDATE_DISABLED
 cancel_drag()
## 打开当前区域图；无参数。
func _open_local() -> void:
 if GameState.current_area.is_empty(): return
 _close_continent()
 world.character_info_ui.character_info_panel.hide()
 is_local_open = true
 local_panel.show()
 configure_view(true)
 local_panel.get_node("MapViewport/SubViewport").render_target_update_mode = SubViewport.UPDATE_ALWAYS
 layout_view(true)
 refresh_maps()
## 关闭区域图；无参数。
func _close_local() -> void:
 is_local_open = false
 local_panel.hide()
 local_panel.get_node("MapViewport/SubViewport").render_target_update_mode = SubViewport.UPDATE_DISABLED
 cancel_drag()
## 同时关闭两种地图；无参数。
func close_all() -> void:
 _close_continent()
 _close_local()
## 地图成功载入后同步身份；map_id 来自 MapLoader，而非请求切图 ID。
func on_map_loaded(map_id: String) -> void:
 cancel_drag()
 var continent := MapDatabase.continent_for_map(map_id)
 if continent.is_empty():
  close_all()
  GameState.change_continent("")
  GameState.change_area("")
  GameState.current_map_bounds = {}
  GameState.current_area_bounds = {}
  loaded_continent = ""
  loaded_area = ""
  return
 loaded_continent = ""
 loaded_area = ""
 GameState.change_continent(continent)
 sync_context()
 continent_zoom = 1.0
 local_zoom = 1.0
 continent_pan = Vector2.ZERO
 local_pan = Vector2.ZERO
 if is_continent_open: configure_view(false)
 if is_local_open: configure_view(true)
 refresh_maps()
## 只有配置提交成功才刷新，失效 ID 重新按实际地图解析。
func on_database_reloaded() -> void:
 if world == null or world.loader.current_data.is_empty(): return
 on_map_loaded(str(world.loader.current_data.id))
## 同步世界位置、区域与各自边界，不覆盖 player_location。
func sync_context() -> void:
 if world == null or world.loader.current_data.is_empty(): return
 GameState.update_player_position(world.player.global_position)
 var point: Vector2 = world.loader.to_local(world.player.global_position)
 var area := MapDatabase.area_for_position(GameState.current_continent, point)
 if area != GameState.current_area:
  GameState.change_area(area)
  loaded_area = ""
  local_zoom = 1.0
  local_pan = Vector2.ZERO
  if is_local_open: configure_view(true)
 GameState.current_map_bounds = world_bounds(MapDatabase.get_map_bounds(GameState.current_continent))
 GameState.current_area_bounds = world_bounds(MapDatabase.bounds_of(MapDatabase.area_configs.get(area, {})))
## 把地图局部矩形转换为全局 AABB，兼容加载器偏移/缩放/旋转；region 是局部边界。
func world_bounds(region: Rect2) -> Dictionary:
 var rect := Rect2(world.loader.to_global(region.position), Vector2.ZERO)
 for point in [region.end, region.position + Vector2(region.size.x, 0), region.position + Vector2(0, region.size.y)]: rect = rect.expand(world.loader.to_global(point))
 return {"begin": rect.position, "end": rect.end}
## 延迟加载对应模式的背景和地形；local 为区域模式。
func configure_view(local: bool) -> void:
 if world == null: return
 var id := GameState.current_area if local else GameState.current_continent
 if id == (loaded_area if local else loaded_continent): return
 var entry: Dictionary = (MapDatabase.area_configs if local else MapDatabase.continent_configs).get(id, {})
 if entry.is_empty(): return
 var view := view_for(local)
 var atlas := not local and bool(MapDatabase.atlas_config.get("enabled", false))
 if atlas:
  var texture := MapDatabase.atlas_texture()
  view.configure(texture, Rect2(Vector2.ZERO, Vector2(float(MapDatabase.atlas_config.width), float(MapDatabase.atlas_config.height))), {}, false, true)
 else:
  view.configure(MapDatabase.map_texture(id, local), MapDatabase.bounds_of(entry), world.loader.current_data, local)
 if local: loaded_area = id
 else: loaded_continent = id
 var title: Label = panel_for(local).get_node("UIOverlay/TitleLabel")
 title.text = (str(MapDatabase.atlas_config.name) + " · 当前：" if atlas else ("区域地图 · " if local else "大陆地图 · ")) + str(entry.name)
 layout_view(local)
## 贴图以左上角定位，容器尺寸变化时重新居中适配；local 为模式。
func layout_view(local: bool) -> void:
 if not is_node_ready() or MapDatabase.settings.is_empty(): return
 var view := view_for(local)
 var texture: Texture2D = view.get_node("MapTexture").texture
 if texture == null: return
 var viewport: SubViewport = panel_for(local).get_node("MapViewport/SubViewport")
 var container: Control = panel_for(local).get_node("MapViewport")
 var available := container.size.max(Vector2.ONE)
 var fit := minf(available.x / texture.get_width(), available.y / texture.get_height()) * float(MapDatabase.settings.fit_margin)
 var zoom := local_zoom if local else continent_zoom
 var scale_value := maxf(fit * zoom, 0.001)
 var pan := local_pan if local else continent_pan
 var max_pan := (texture.get_size() * scale_value + available) / 2.0 - Vector2.ONE * float(MapDatabase.settings.min_visible_pixels)
 max_pan = max_pan.max(Vector2.ZERO)
 pan = pan.clamp(-max_pan, max_pan)
 if local: local_pan = pan
 else: continent_pan = pan
 view.scale = Vector2.ONE * scale_value
 view.position = available / 2.0 + pan - texture.get_size() * scale_value / 2.0
 view.update_all_marker_scales()
 view.get_node("TerrainLayer").queue_redraw()
 update_player_marker(local)
 update_zoom_buttons(local)
## 缩放后保持鼠标所指位置不漂移；anchor 是 SubViewport 坐标，负值表示中心。
func zoom_kind(local: bool, direction: int, anchor: Vector2 = Vector2(-1, -1)) -> void:
 var view := view_for(local)
 var viewport: SubViewport = panel_for(local).get_node("MapViewport/SubViewport")
 if anchor.x < 0: anchor = Vector2(viewport.size) / 2.0
 var point := (anchor - view.position) / view.scale
 var previous := local_zoom if local else continent_zoom
 var value := clampf(previous + direction * float(MapDatabase.settings.zoom_step), float(MapDatabase.settings.min_zoom), float(MapDatabase.settings.max_zoom))
 if local: local_zoom = value
 else: continent_zoom = value
 layout_view(local)
 var correction := anchor - (view.position + point * view.scale)
 if local: local_pan += correction
 else: continent_pan += correction
 layout_view(local)
## 重置到当前窗口适配比例及中心；local 为模式。
func reset_kind(local: bool) -> void:
 if local:
  local_zoom = 1.0
  local_pan = Vector2.ZERO
 else:
  continent_zoom = 1.0
  continent_pan = Vector2.ZERO
 layout_view(local)
## 更新缩放边界按钮；local 为模式。
func update_zoom_buttons(local: bool) -> void:
 var zoom := local_zoom if local else continent_zoom
 var panel := panel_for(local)
 panel.get_node("UIOverlay/ZoomControls/ZoomInBtn").disabled = zoom >= float(MapDatabase.settings.max_zoom)
 panel.get_node("UIOverlay/ZoomControls/ZoomOutBtn").disabled = zoom <= float(MapDatabase.settings.min_zoom)
## 只接受地图视口内开始的拖动/滚轮，按钮区不触发；event 为 GUI 输入。
func map_input(event: InputEvent, local: bool) -> void:
 if not (is_local_open if local else is_continent_open): return
 var viewport_rect := Rect2(Vector2.ZERO, panel_for(local).get_node("MapViewport").size)
 if event is InputEventMouseButton:
  if event.button_index == MOUSE_BUTTON_LEFT:
   if event.pressed and viewport_rect.has_point(event.position):
    is_dragging = true
    drag_pointer = -1
    drag_start_pos = event.position
   elif not event.pressed: cancel_drag()
  elif event.pressed and viewport_rect.has_point(event.position):
   if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_kind(local, 1, event.position)
   elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_kind(local, -1, event.position)
 elif event is InputEventMouseMotion and is_dragging and drag_pointer == -1:
  pan_kind(local, event.position - drag_start_pos)
  drag_start_pos = event.position
 elif event is InputEventScreenTouch:
  if event.pressed and not is_dragging and viewport_rect.has_point(event.position):
   is_dragging = true
   drag_pointer = event.index
   drag_start_pos = event.position
  elif not event.pressed and drag_pointer == event.index: cancel_drag()
 elif event is InputEventScreenDrag and is_dragging and drag_pointer == event.index:
  pan_kind(local, event.position - drag_start_pos)
  drag_start_pos = event.position
## delta 是屏幕像素平移量，互不影响另一种地图。
func pan_kind(local: bool, delta: Vector2) -> void:
 if local: local_pan += delta
 else: continent_pan += delta
 layout_view(local)
## 关闭、切换窗口或失去焦点时结束拖动；无参数。
func cancel_drag() -> void:
 is_dragging = false
 drag_pointer = -2
## 将真实全局坐标映射到该视图独有的边界，而非复用大陆边界。
func _world_to_map_coords(world_position: Vector2, view: Node2D) -> Vector2:
 var point: Vector2 = world.loader.to_local(world_position)
 if view == continent_view and bool(MapDatabase.atlas_config.get("enabled", false)): point = MapDatabase.atlas_point(GameState.current_continent, point)
 return view.map_point(point)
## 仅更新已打开视图中的玩家点；local 为模式。
func update_player_marker(local: bool) -> void:
 if world == null: return
 var point: Vector2 = world.loader.to_local(world.player.global_position)
 if not local and bool(MapDatabase.atlas_config.get("enabled", false)): point = MapDatabase.atlas_point(GameState.current_continent, point)
 view_for(local).update_player(point)
## 把配置标记与现有场景 POI 合并；无参数。
func continent_markers() -> Array:
 var result := MapDatabase.get_pois(GameState.current_continent)
 var by_id: Dictionary = {}
 for entry in result: by_id[entry.id] = entry
 for marker in world.loader.special_locations.get_children():
  var data: Dictionary = marker.get_meta("map_data")
  var type := str({"market":"exchange", "altar":"altar", "artifact":"artifact"}.get(data.kind, "portal"))
  var point: Vector2 = world.loader.to_local(marker.global_position)
  by_id[data.id] = {"id":data.id, "name":data.name, "type":type, "position":{"x":point.x, "y":point.y}}
 var entries: Array = by_id.values()
 for entry in entries: entry["continent_id"] = GameState.current_continent
 if bool(MapDatabase.atlas_config.get("enabled", false)):
  for id in MapDatabase.continent_configs:
   if id == GameState.current_continent: continue
   for entry in MapDatabase.get_pois(id):
    entry["continent_id"] = id
    entries.append(entry)
 return entries
## 更新 POI、区域配置与动态实体标记，保留同 ID 节点避免每帧重建。
func refresh_markers(local: bool) -> void:
 var view := view_for(local)
 var keys: Array[String] = []
 if not local:
  for entry in continent_markers():
   var point := MapDatabase.vector(entry.position)
   var id := str(entry.continent_id) + ":" + str(entry.id)
   if bool(MapDatabase.atlas_config.get("enabled", false)): point = MapDatabase.atlas_point(str(entry.continent_id), point)
   view.put_marker("POILayer", id, str(entry.type), point, str(entry.name))
   keys.append("POILayer:" + id)
  if bool(MapDatabase.atlas_config.get("enabled", false)):
   for id in MapDatabase.continent_configs:
    var key := "continent_name:" + str(id)
    var position_value := MapDatabase.vector(MapDatabase.atlas_config.regions[id].label_position)
    var text := str(MapDatabase.continent_configs[id].name) + (" · 当前" if id == GameState.current_continent else "")
    view.put_marker("POILayer", key, "continent", position_value, text)
    var marker: Node = view.marker_nodes["POILayer:" + key]
    marker.get_node("Icon").hide()
    marker.get_node("Label").add_theme_font_size_override("font_size", int(MapDatabase.settings.label_size) + 2)
    keys.append("POILayer:" + key)
 else:
  for pair in [["NPCMarkers","npc",MapDatabase.get_npcs(GameState.current_area)], ["EnemyMarkers","enemy",MapDatabase.get_enemies(GameState.current_area)], ["ChestMarkers","chest",MapDatabase.get_chests(GameState.current_area)]]:
   for entry in pair[2]:
    view.put_marker(pair[0], str(entry.id), pair[1], MapDatabase.vector(entry.position), str(entry.name))
    keys.append(str(pair[0]) + ":" + str(entry.id))
  for pair in [["map_npcs","NPCMarkers","npc"], ["map_enemies","EnemyMarkers","enemy"], ["map_chests","ChestMarkers","chest"]]:
   for actor in get_tree().get_nodes_in_group(pair[0]):
    if not actor is Node2D or not actor.is_visible_in_tree(): continue
    if actor.get_meta("continent_id", GameState.current_continent) != GameState.current_continent: continue
    var id := str(actor.get_meta("map_marker_id", actor.get_instance_id()))
    view.put_marker(pair[1], id, pair[2], world.loader.to_local(actor.global_position), str(actor.get_meta("map_marker_name", actor.name)))
    keys.append(str(pair[1]) + ":" + id)
 view.retain_markers(keys)
 view.update_all_marker_scales()
## 刷新地图文字、玩家点和低频详情；无参数。
func refresh_maps() -> void:
 if world == null or MapDatabase.settings.is_empty(): return
 for local in [false, true]:
  if not (is_local_open if local else is_continent_open): continue
  configure_view(local)
  update_player_marker(local)
  refresh_markers(local)
  update_info(local)
## 位置文字与玩家点每帧同步，详情标记仍低频更新；local 为模式。
func update_info(local: bool) -> void:
 var point: Vector2 = world.loader.to_local(world.player.global_position)
 panel_for(local).get_node("InfoPanel/CurrentLocationLabel").text = "位置 (%d, %d) · %s · 滚轮缩放 / 拖动平移 / Esc关闭" % [point.x, point.y, GameState.current_area if local else GameState.current_continent]
## 位置每帧同步，地图关闭时不生成纹理或重建标记；delta 为秒。
func _process(delta: float) -> void:
 if world == null or MapDatabase.settings.is_empty(): return
 sync_context()
 if not any_open(): return
 update_player_marker(is_local_open)
 update_info(is_local_open)
 elapsed += delta
 if elapsed >= float(MapDatabase.settings.detail_refresh_seconds):
  elapsed = 0.0
  refresh_maps()
