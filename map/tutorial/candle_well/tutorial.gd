extends "res://tutorial/continuous_well/world.gd"
## Independent prologue: deliberately absent from MapDatabase.continent_configs.
var returned_via_sky: bool = false
var leaving: bool = false
var tutorial_hint: Label
var previous_scale: Vector2i
var previous_mode: int
var previous_aspect: int
var feedback: String = ""
var previous_clear: Color

func _ready() -> void:
    var window := get_window()
    previous_clear = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color",Color(0.3,0.3,0.3))
    RenderingServer.set_default_clear_color(Color.BLACK)
    previous_scale = window.content_scale_size
    previous_mode = window.content_scale_mode
    previous_aspect = window.content_scale_aspect
    window.content_scale_size = Vector2i(480,320)
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
    super._ready()
    skylight_landed.connect(func(): returned_via_sky = true)
    get_node("/root/GameManager").world_active = false
    var state := get_node("/root/GameState")
    state.change_continent("")
    state.change_area("tutorial_candle_well")
    state.change_location("烛井 · 独立新手关")
    var overlay := CanvasLayer.new()
    overlay.layer = 30
    add_child(overlay)
    tutorial_hint = Label.new()
    tutorial_hint.position = Vector2(8,260)
    tutorial_hint.size = Vector2(464,58)
    tutorial_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tutorial_hint.add_theme_font_size_override("font_size",10)
    overlay.add_child(tutorial_hint)
    var session := get_node("/root/GameSession")
    session.tutorial_ref = weakref(self)
    var pending: Dictionary = session.tutorial_pending.duplicate(true)
    session.tutorial_pending.clear()
    if not pending.is_empty(): restore_tutorial(pending)

func load_level(index: int, destination: Array) -> void:
    if current_level == 2 and index == 1 and int(destination[0])==50 and int(destination[1])==50:
        returned_via_sky = true
    super.load_level(index,destination)

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if not is_instance_valid(tutorial_hint): return
    var objective := "沿地面石纹指引进入中央旋梯，逐层向上，到天窗直接跃下。"
    if returned_via_sky:
        objective = "开启东密室G4 → 回中央旋梯下到L0 → 东侧出口按E离开。"
    tutorial_hint.text = "烛井 · 新手关（不属于六大陆）\n" + objective + "\nF5 保存 / F10 保存回菜单；F1 观察模式（默认路线已清晰）。" + feedback

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo or leaving: return
    var code: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
    if code == KEY_F5:
        feedback = " 已保存。" if get_node("/root/GameSession").save_game() else " 保存失败。"
        return
    if code == KEY_F10:
        if not get_node("/root/GameSession").return_to_menu(): feedback = " 保存失败，请重试。"
        return
    if code == KEY_E and can_finish():
        finish_tutorial()
        return
    if code == KEY_R:
        returned_via_sky = false
    super._unhandled_key_input(event)

func can_finish() -> bool:
    return returned_via_sky and opened.has("G4") and current_level==0 and not player.on_stair and player.position.distance_to(cell([60,16]))<36.0

func finish_tutorial() -> void:
    if leaving or not can_finish(): return
    var session := get_node("/root/GameSession")
    var scene_path: String = str(session.options.navigation.game_scene)
    if not ResourceLoader.exists(scene_path) or not ResourceLoader.load(scene_path) is PackedScene:
        feedback = " 大陆入口场景不可用。"
        return
    leaving = true
    session.tutorial_pending.clear()
    session.tutorial_ref = null
    # The new-game continent remains the existing configured destination, not a tutorial continent.
    session.tutorial_completed = true
    get_tree().call_deferred("change_scene_to_file",scene_path)

func tutorial_snapshot() -> Dictionary:
    if falling: return {}
    return {"layout_revision":"reference-compact-v1","version":1,"stage":"tutorial_candle_well","level":current_level,
        "position":[player.position.x,player.position.y],"opened":opened.duplicate(),
        "glass_broken":glass_broken.duplicate(),"broken":broken.duplicate(),"collected":collected.duplicate(),"hits":hits.duplicate(),
        "continuous_height":player.current_z_height,"continuous_stairs":player.on_stair,"returned_via_sky":returned_via_sky,"spiral_route":{"tracking":spiral_tracking,
        "direction":spiral_direction,"progress":spiral_progress,"last_angle":spiral_last_angle}}

func restore_tutorial(snapshot: Dictionary) -> void:
    glass_broken = snapshot.get("glass_broken",{}).duplicate()
    opened = snapshot.opened.duplicate()
    broken = snapshot.broken.duplicate()
    collected = snapshot.collected.duplicate()
    hits = snapshot.hits.duplicate()
    returned_via_sky = snapshot.returned_via_sky
    var tile: Array = [int(snapshot.position[0])/16,int(snapshot.position[1])/16]
    load_level(int(snapshot.level),tile)
    player.position = Vector2(snapshot.position[0],snapshot.position[1])
    player.current_z_height = float(snapshot.get("continuous_height",int(snapshot.level)*128.0))
    player.on_stair = bool(snapshot.get("continuous_stairs",false))
    player.stair_phase = player.current_z_height/(256.0/12.0)
    if not snapshot.has("continuous_height") and snapshot.get("spiral_route",{}).get("tracking",false):
        player.position = Vector2(512,392) # migrate old teleport-stair saves to a safe landing
    var radial: Vector2 = player.position-Vector2(512,256)
    if radial.length()<66:
        player.position = Vector2(512,256)+radial.normalized()*68
    if snapshot.get("layout_revision","")!="reference-compact-v1":
        load_level(0,data.get("spawn_cell",[57,16]))
    if current_level==0 and opened.is_empty() and collected.is_empty() and broken.is_empty() and player.position.distance_to(cell([60,16]))<32:
        player.position = cell(data.get("spawn_cell",[57,16]))
    configure_collision()
    refresh_props()
    camera.position = project_at(player.position,player.current_z_height)
    camera.force_update_scroll()

func _exit_tree() -> void:
    RenderingServer.set_default_clear_color(previous_clear)
    var window := get_window()
    window.content_scale_size = previous_scale
    window.content_scale_mode = previous_mode
    window.content_scale_aspect = previous_aspect
    var session := get_node_or_null("/root/GameSession")
    if session != null and session.tutorial_ref != null and session.tutorial_ref.get_ref()==self:
        session.tutorial_ref = null
