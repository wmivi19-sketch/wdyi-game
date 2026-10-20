extends Node2D
signal skylight_landed
const FLOOR_HEIGHT := 128.0
const DARK_VISIBLE_AMBIENT := Color(0.92,0.94,0.96)
const PLAYER_BIT := 8
const STAIR_BIT := 16
var data: Dictionary
var route: Dictionary
var current_level: int = 0
var player
var camera: Camera2D
var ambient: CanvasModulate
var candle: PointLight2D
var status: Label
var avatar: Node2D
var floor_roots: Array[Node2D] = []
var floor_views: Array[Node2D] = []
var contexts: Array[Node] = []
var trigger_nodes: Array[Area2D] = []
var opened: Dictionary = {}
var broken: Dictionary = {}
var hits: Dictionary = {}
var collected: Dictionary = {}
var gate_bodies: Dictionary = {}
var glass_broken: Dictionary = {}
var glass_platforms: Array[Area2D] = []
var debug_view: bool = false
var cooldown: float = 0.0
var interact: bool = false
var falling: bool = false
var fall_velocity: float = 0.0
var fall_target_floor: int = 0
var fall_target_point := Vector2.ZERO
var fall_id: String = ""
var darkness: ColorRect
var resident_build_count: int = 0
var stair_spindle: Node2D
# Legacy save aliases; no angular-lap trigger remains in this implementation.
var spiral_tracking: bool = false
var spiral_direction: int = 0
var spiral_progress: float = 0.0
var spiral_last_angle: float = 0.0

func cell(v: Array) -> Vector2:
    return Vector2(float(v[0])*16+8,float(v[1])*16+8)
func region(r: Array) -> Rect2:
    return Rect2(float(r[0])*16,float(r[1])*16,float(r[2])*16,float(r[3])*16)
func project(p: Vector2) -> Vector2:
    return Vector2(p.x-p.y+1024,(p.x+p.y)*0.5)
func project_at(p: Vector2,z: float) -> Vector2:
    var center := Vector2(1280,384)
    return center+(project(p)-center)*(1.0+z/256.0*0.035)+Vector2(0,-z*1.10)

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    data = JSON.parse_string(FileAccess.get_file_as_string("res://tutorial/candle_well/assets/dungeon.json"))
    route = JSON.parse_string(FileAccess.get_file_as_string("res://tutorial/continuous_well/stair_path.json"))
    ambient = CanvasModulate.new()
    ambient.color = DARK_VISIBLE_AMBIENT
    add_child(ambient)
    player = CharacterBody2D.new()
    player.set_script(load("res://tutorial/continuous_well/player.gd"))
    player.world = self
    player.collision_layer = PLAYER_BIT
    var shape := CircleShape2D.new()
    shape.radius = 5
    var collider := CollisionShape2D.new()
    collider.shape = shape
    player.add_child(collider)
    var detector := Area2D.new()
    detector.name = "StairDetector"
    detector.collision_layer = 0
    detector.collision_mask = STAIR_BIT
    var ds := CollisionShape2D.new()
    var dc := CircleShape2D.new()
    dc.radius = 5
    ds.shape = dc
    detector.add_child(ds)
    player.add_child(detector)
    player.stair_detector = detector
    add_child(player)
    for index in range(3): build_floor(index)
    build_stairs()
    build_glass_platforms()
    build_wayfinding()
    avatar = Node2D.new()
    avatar.set_script(load("res://tutorial/candle_well/pixel_actor.gd"))
    avatar.player = player
    add_child(avatar)
    camera = Camera2D.new()
    camera.zoom = Vector2(1.15,1.15)
    add_child(camera)
    camera.make_current()
    build_candle()
    build_darkness()
    var ui := CanvasLayer.new()
    ui.layer = 10
    add_child(ui)
    status = Label.new()
    status.position = Vector2(6,5)
    status.add_theme_font_size_override("font_size",8)
    ui.add_child(status)
    resident_build_count = 1
    load_level(0,data.get("spawn_cell",[57,16]))

func make_body(parent: Node2D,r: Rect2,bit: int) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = r.get_center()
    body.collision_layer = bit
    body.collision_mask = PLAYER_BIT
    var cs := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = r.size
    cs.shape = shape
    body.add_child(cs)
    parent.add_child(body)
    return body

func build_floor(index: int) -> void:
    var root := Node2D.new()
    root.name = "ResidentFloor%d" % index
    add_child(root)
    floor_roots.append(root)
    var walls: Dictionary = {}
    for c in data.levels[index].solid: walls[Vector2i(int(c[0]),int(c[1]))] = true
    for y in range(32):
        var x: int = 0
        while x<64:
            if not walls.has(Vector2i(x,y)):
                x += 1
                continue
            var begin: int = x
            while x<64 and walls.has(Vector2i(x,y)): x += 1
            make_body(root,Rect2(begin*16,y*16,(x-begin)*16,16),1<<index)
    var ctx := Node.new()
    ctx.set_script(load("res://tutorial/continuous_well/floor_context.gd"))
    ctx.data = data
    ctx.current_level = index
    ctx.player = player
    ctx.opened = opened
    ctx.broken = broken
    ctx.collected = collected
    add_child(ctx)
    contexts.append(ctx)
    var view := Node2D.new()
    view.set_script(load("res://tutorial/continuous_well/floor_view.gd"))
    view.game = ctx
    view.name = "ResidentView%d" % index
    add_child(view)
    view.build()
    view.avatar.hide()
    floor_views.append(view)
    var scale_factor: float = 1+float(index)*128/256*0.035
    view.scale = Vector2.ONE*scale_factor
    view.position = Vector2(1280,384)*(1-scale_factor)+Vector2(0,-index*128*1.10)
    view.z_index = index*32
    for node in view.find_children("*","LightOccluder2D",true,false): node.occluder_light_mask = 1<<index
    for o in data.levels[index].objects:
        if o.type=="gate": gate_bodies[o.id] = make_body(root,region(o.rect),1<<index)
        if o.type not in ["break","drop"]: continue
        var area := Area2D.new()
        if o.type=="break":
            area.set_script(load("res://tutorial/continuous_well/breakable_floor.gd"))
            area.world = self
            area.floor_index = index
            area.object_id = o.id
            area.target_floor = int(o.target_level)
            area.target_cell = Vector2i(int(o.target_cell[0]),int(o.target_cell[1]))
        area.position = region(o.rect).get_center()
        area.collision_layer = 0
        area.collision_mask = PLAYER_BIT
        var cs := CollisionShape2D.new()
        var shape := RectangleShape2D.new()
        shape.size = region(o.rect).size
        cs.shape = shape
        area.add_child(cs)
        area.set_meta("object",o)
        area.set_meta("floor",index)
        root.add_child(area)
        trigger_nodes.append(area)

func build_stairs() -> void:
    var physics := Node2D.new()
    physics.name = "ContinuousStairPhysics"
    add_child(physics)
    var core := StaticBody2D.new()
    core.position = Vector2(512,256)
    core.collision_layer = STAIR_BIT
    core.collision_mask = PLAYER_BIT
    var core_shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 60
    core_shape.shape = circle
    core.add_child(core_shape)
    physics.add_child(core)
    for i in range(64):
        var a: float = float(i)*TAU/64
        var b: float = float(i+1)*TAU/64
        if absf(wrapf((a+b)*0.5-PI*0.5,-PI,PI))<0.28: continue
        var body := StaticBody2D.new()
        body.position = Vector2(512,256)
        body.collision_layer = STAIR_BIT
        body.collision_mask = PLAYER_BIT
        var poly := CollisionPolygon2D.new()
        poly.polygon = PackedVector2Array([Vector2(cos(a),sin(a))*100,Vector2(cos(a),sin(a))*108,Vector2(cos(b),sin(b))*108,Vector2(cos(b),sin(b))*100])
        body.add_child(poly)
        physics.add_child(body)
    var art := Node2D.new()
    art.name = "ContinuousHelix"
    art.z_index = 180
    add_child(art)
    # Solid, vertical cylindrical spindle. Back flights pass behind its front faces.
    var spindle := Node2D.new()
    stair_spindle = spindle
    spindle.name = "ContinuousStoneSpindle"
    spindle.z_index = 170
    add_child(spindle)
    for side in range(24):
        var a: float = float(side)*TAU/24
        var b: float = float(side+1)*TAU/24
        var mid: float = (a+b)*0.5
        if cos(mid)+sin(mid)<0: continue
        var p := Vector2(512,256)+Vector2(cos(a),sin(a))*58
        var q := Vector2(512,256)+Vector2(cos(b),sin(b))*58
        for course in range(17):
            var lower: float = course*16.0
            var upper: float = (course+1)*16.0
            var stone := Polygon2D.new()
            stone.polygon = PackedVector2Array([project_at(p,lower),project_at(q,lower),project_at(q,upper),project_at(p,upper)])
            stone.color = Color("58635d" if side%3 else "505c58")
            spindle.add_child(stone)
            var seam := Line2D.new()
            seam.points = PackedVector2Array([project_at(p,upper),project_at(q,upper)])
            seam.default_color = Color("39443f")
            seam.width = 1
            spindle.add_child(seam)
            if (course+side)%3==0:
                var scratch := Line2D.new()
                var at: Vector2 = project_at(p.lerp(q,0.5),lower+6)
                scratch.points = PackedVector2Array([at+Vector2(-2,-3),at,at+Vector2(1,3)])
                scratch.default_color = Color("46524c")
                spindle.add_child(scratch)
    var cap := Polygon2D.new()
    var cap_points := PackedVector2Array()
    for side in range(48):
        var a: float = side*TAU/48
        cap_points.append(project_at(Vector2(512,256)+Vector2(cos(a),sin(a))*58,272))
    cap.polygon = cap_points
    cap.color = Color("697365")
    spindle.add_child(cap)
    for i in range(12):
        var step: Dictionary = route.segments[i]
        var a := Vector2(step.from[0],step.from[1])
        var b := Vector2(step.to[0],step.to[1])
        var area := Area2D.new()
        area.add_to_group(player.stair_area_group)
        area.collision_layer = STAIR_BIT
        area.collision_mask = 0
        area.set_meta("height_start",step.z0)
        area.set_meta("height_end",step.z1)
        # Stair trigger occupancy is made of exact 16x16 cells, not rotated sub-grid polygons.
        for tile in step.tiles:
            var tile_shape := CollisionShape2D.new()
            var rectangle := RectangleShape2D.new()
            rectangle.size = Vector2(16,16)
            tile_shape.shape = rectangle
            tile_shape.position = Vector2(float(tile[0])*16+8,float(tile[1])*16+8)
            area.add_child(tile_shape)
        physics.add_child(area)
        # Eight narrow curved treads per sector; common polar endpoints prevent seams.
        for substep in range(8):
            var t0: float = float(i)+float(substep)/8.0
            var t1: float = float(i)+float(substep+1)/8.0
            var middle: float = (t0+t1)*0.5
            var section := Node2D.new()
            section.z_index = -20 if cos(PI/2+middle*TAU/6)+sin(PI/2+middle*TAU/6)<0 else 0
            art.add_child(section)
            var inner0 := helix_point(t0,62)
            var outer0 := helix_point(t0,100)
            var outer1 := helix_point(t1,100)
            var inner1 := helix_point(t1,62)
            var side := Polygon2D.new()
            side.polygon = PackedVector2Array([outer0,outer1,outer1+Vector2(0,5),outer0+Vector2(0,5)])
            side.color = Color("46534b")
            section.add_child(side)
            var top := Polygon2D.new()
            top.polygon = PackedVector2Array([inner0,outer0,outer1,inner1])
            top.color = Color("818979" if (i*8+substep)%3 else "77816f")
            section.add_child(top)
            var edge := Line2D.new()
            edge.points = PackedVector2Array([inner1,outer1])
            edge.width = 1
            edge.default_color = Color("4c594d")
            section.add_child(edge)
            var lip := Line2D.new()
            lip.points = PackedVector2Array([outer0,outer1])
            lip.width = 1
            lip.default_color = Color("a8af98")
            section.add_child(lip)
            if (i*8+substep)%9==2:
                var chip := Polygon2D.new()
                var at: Vector2 = outer0.lerp(outer1,0.5)
                chip.polygon = PackedVector2Array([at+Vector2(-2,-1),at+Vector2(2,1),at+Vector2(1,3)])
                chip.color = Color("414e46")
                section.add_child(chip)
    # Every layer has a broad stone landing joining the shared south opening to its rooms.
    for level in range(3):
        var platform := Node2D.new()
        platform.name = "StoneLandingL%d" % level
        platform.z_index = 181
        add_child(platform)
        var z: float = float(level)*128
        for x in range(30,34):
            for y in range(21,25):
                var top := Polygon2D.new()
                top.polygon = PackedVector2Array([project_at(Vector2(x*16,y*16),z),project_at(Vector2((x+1)*16,y*16),z),project_at(Vector2((x+1)*16,(y+1)*16),z),project_at(Vector2(x*16,(y+1)*16),z)])
                top.color = Color("6d7869" if (x+y)%2 else "75806f")
                platform.add_child(top)
                var seam := Line2D.new()
                seam.points = top.polygon
                seam.closed = true
                seam.width = 1
                seam.default_color = Color("455344")
                platform.add_child(seam)

func helix_point(phase: float,radius: float) -> Vector2:
    var angle: float = PI/2+phase*TAU/6
    return project_at(Vector2(512,256)+Vector2(cos(angle),sin(angle))*radius,phase*(256.0/12.0))

func configure_collision() -> void:
    player.collision_layer = PLAYER_BIT
    player.collision_mask = STAIR_BIT if player.on_stair else ((1<<current_level)|STAIR_BIT)

func filter_stair_velocity(requested: Vector2) -> Vector2:
    if not player.on_stair: return requested
    var radial: Vector2 = (player.position-Vector2(512,256)).normalized()
    var tangent := Vector2(-radial.y,radial.x)
    var along: float = requested.dot(tangent)
    if (player.stair_phase<=0.02 and along<0) or (player.stair_phase>=11.98 and along>0):
        return requested-tangent*along # finite helix end cap; radial landing exit remains open
    return requested

func nearest_phase(point: Vector2,previous: float) -> float:
    var radial := point-Vector2(512,256)
    var wrapped: float = fposmod(radial.angle()-PI/2,TAU)/TAU*6.0
    var result: float = previous
    var distance: float = INF
    for turn in range(-1,3):
        var candidate: float = wrapped+float(turn)*6.0
        if absf(candidate-previous)<distance:
            distance = absf(candidate-previous)
            result = candidate
    return clampf(result,0,12)

func sync_stair_height(_delta: float) -> void:
    var radial: Vector2 = player.position-Vector2(512,256)
    var radius: float = radial.length()
    var near_landing: bool = absf(wrapf(radial.angle()-PI*0.5,-PI,PI))<0.30
    if not player.on_stair:
        var detected: bool = false
        for area in player.stair_detector.get_overlapping_areas():
            if area.is_in_group(player.stair_area_group): detected = true
        if near_landing and radius<100 and radius>52 and detected:
            player.on_stair = true
            player.stair_phase = player.current_z_height/(256.0/12.0)
    if player.on_stair:
        var previous: float = player.stair_phase
        player.stair_phase = nearest_phase(player.position,previous)
        spiral_direction = 1 if player.stair_phase>=previous else -1
        var height: float = player.stair_phase*(256.0/12.0)
        var base: float = roundf(height/128.0)*128.0
        if near_landing and radius>96 and absf(height-base)<10:
            height = lerpf(height,base,smoothstep(96,128,radius))
            if radius>=128:
                player.on_stair = false
                player.stair_phase = base/(256.0/12.0)
                height = base
        player.current_z_height = clampf(height,0,256)
    current_level = clampi(roundi(player.current_z_height/128),0,2)
    spiral_tracking = player.on_stair
    spiral_last_angle = fposmod(radial.angle(),TAU)
    spiral_progress = fposmod(player.stair_phase,6.0)/6.0*TAU
    configure_collision()

func build_candle() -> void:
    candle = PointLight2D.new()
    candle.name = "OnlyCandleLight"
    var image := Image.create(512,512,false,Image.FORMAT_RGBA8)
    for y in range(512):
        for x in range(512):
            var strength: float = pow(maxf(0,1-Vector2(x-256,y-256).length()/256),2)
            image.set_pixel(x,y,Color(strength,strength,strength,1))
    candle.texture = ImageTexture.create_from_image(image)
    candle.position = project_at(cell([32,16]),256)-Vector2(0,25)
    candle.color = Color("b9ad8a")
    candle.texture_scale = 1.4
    candle.shadow_enabled = true
    candle.shadow_filter = Light2D.SHADOW_FILTER_PCF5
    add_child(candle)

func _process(delta: float) -> void:
    if not is_instance_valid(avatar): return
    var height: float = player.current_z_height
    var fraction: float = height/128.0
    if not debug_view:
        ambient.color = DARK_VISIBLE_AMBIENT
    for i in range(3):
        var difference: float = absf(float(i)-fraction)
        var opacity: float = clampf(1-difference,0.0,1.0)
        if player.on_stair: opacity *= 0.35
        floor_views[i].modulate = Color(0.84+0.06*i,0.88+0.04*i,0.94+0.02*i,opacity)
    avatar.position = project_at(player.position,height)
    avatar.elevation = player.jump_height
    avatar.scale = Vector2.ONE*(1+height/256*0.035)
    var behind_column: bool = player.on_stair and (player.position.x-512+player.position.y-256)<0
    avatar.z_index = (165 if behind_column else 185) if player.on_stair else 300+roundi(height)
    stair_spindle.modulate.a = move_toward(stair_spindle.modulate.a,0.28 if behind_column else 1.0,delta*4)
    avatar.modulate = Color(0.92,0.94,0.96).lerp(Color.WHITE,height/256)
    camera.position = project_at(player.position,height)
    camera.zoom = camera.zoom.lerp(Vector2.ONE*(1.15+height/256*0.035),1-exp(-delta*6))
    # Light2D has no distance_fade: fade energy at shadow-mask boundaries before changing masks.
    var boundary_distance: float = absf(fposmod(fraction,1.0)-0.5)*2
    candle.energy = 1.15*smoothstep(0,0.22,boundary_distance)
    candle.shadow_item_cull_mask = 1<<current_level
    candle.visible = height>192
    var screen_light: Vector2 = get_viewport().get_canvas_transform()*candle.global_position
    darkness.material.set_shader_parameter("candle_px",screen_light)
    darkness.material.set_shader_parameter("top_blend",smoothstep(128,256,height))
    darkness.visible = false
    status.text = "%s · 宝箱 %d/5\nWASD / 方向键移动 · E 交互 · 空格跳跃" % [["底层","中层","顶层"][current_level],collected.size()]

func _physics_process(delta: float) -> void:
    cooldown = maxf(0,cooldown-delta)
    if falling or player.on_stair:
        interact = false
        return
    for area in trigger_nodes:
        var o: Dictionary = area.get_meta("object")
        if int(area.get_meta("floor"))!=current_level or not region(o.rect).has_point(player.position): continue
        if o.type=="drop": begin_fall(int(o.target_level),o.target_cell,"SKY")
        elif interact: area.strike()
    if interact and not falling:
        for o in data.levels[current_level].objects:
            if o.type=="chest" and player.position.distance_to(cell(o.cell))<36: collected[o.id] = true
            if o.type=="gate" and player.position.distance_to(cell(o.button_cell))<30:
                opened[o.id] = true
                if gate_bodies.has(o.id): gate_bodies[o.id].collision_layer = 0
        refresh_props()
    interact = false

func refresh_props() -> void:
    for glass in glass_platforms: glass.sync_saved_state()
    for i in range(3):
        contexts[i].opened = opened
        contexts[i].broken = broken
        contexts[i].collected = collected
        floor_views[i].sync_objects()
    for id in gate_bodies:
        gate_bodies[id].collision_layer = 0 if opened.has(id) else (1<<int(String(gate_bodies[id].get_parent().name).trim_prefix("ResidentFloor")))

func begin_fall(target: int,target_cell: Array,id: String) -> void:
    if falling or target>=current_level: return
    falling = true
    fall_velocity = 0
    fall_target_floor = target
    fall_target_point = cell(target_cell)
    fall_id = id
    player.on_stair = false
    player.reset_jump()
    player.collision_mask = 0

func integrate_fall(delta: float) -> void:
    fall_velocity += 600*delta
    player.current_z_height = maxf(float(fall_target_floor)*128,player.current_z_height-fall_velocity*delta)
    player.position = player.position.move_toward(fall_target_point,100*delta)
    current_level = clampi(roundi(player.current_z_height/128),0,2)
    if is_equal_approx(player.current_z_height,float(fall_target_floor)*128) and player.position.distance_to(fall_target_point)<0.1:
        falling = false
        player.velocity = Vector2.ZERO
        configure_collision()
        cooldown = 0.35
        if fall_id=="SKY": skylight_landed.emit()

func load_level(index: int,destination: Array) -> void:
    # Compatibility for initial spawn, explicit reset and old-save restoration ONLY.
    # Stair walking and falling never call this method or change any scene/root instance.
    current_level = index
    player.current_z_height = float(index)*128
    player.stair_phase = float(index)*6
    player.on_stair = false
    player.position = cell(destination)
    player.velocity = Vector2.ZERO
    player.reset_jump()
    falling = false
    configure_collision()
    if is_instance_valid(camera): camera.position = project_at(player.position,player.current_z_height)
    refresh_props()

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo: return
    var code: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
    if code==KEY_E: interact = true
    if code==KEY_F1:
        debug_view = not debug_view
        ambient.color = Color.WHITE if debug_view else DARK_VISIBLE_AMBIENT
    if code==KEY_R:
        opened.clear()
        broken.clear()
        hits.clear()
        collected.clear()
        glass_broken.clear()
        load_level(0,data.get("spawn_cell",[57,16]))

func build_darkness() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 5
    add_child(layer)
    darkness = ColorRect.new()
    darkness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var shader := Shader.new()
    shader.code = """shader_type canvas_item;
uniform vec2 candle_px=vec2(240.0,160.0);
uniform float top_blend=0.0;
void fragment(){
 vec2 pixel=UV*vec2(480.0,320.0);
 float micro=(1.0-smoothstep(30.0,100.0,distance(pixel,vec2(240.0,160.0))))*0.82;
 float flame=pow(1.0-smoothstep(0.0,210.0,distance(pixel,candle_px)),1.4);
 float visible=mix(micro,flame,top_blend);
 COLOR=vec4(0.0,0.0,0.0,1.0-visible);
}"""
    var mat := ShaderMaterial.new()
    mat.shader = shader
    darkness.material = mat
    layer.add_child(darkness)

func build_glass_platforms() -> void:
    var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tutorial/continuous_well/glass_platforms.json"))
    for definition in definitions.platforms:
        var glass := Area2D.new()
        glass.set_script(load("res://tutorial/continuous_well/glass_platform.gd"))
        glass.name = definition.id
        glass.world = self
        glass.definition = definition
        add_child(glass)
        glass_platforms.append(glass)

func build_wayfinding() -> void:
    var marks := Node2D.new()
    marks.name = "EntranceStoneWayfinding"
    marks.z_index = 12
    floor_views[0].add_child(marks)
    var path: Array = data.get("entry_guide_cells",[[57,16],[54,16],[50,16],[46,16],[42,16],[38,20],[32,24]])
    for i in range(path.size()-1):
        var p: Vector2 = project(cell(path[i]))
        var direction: Vector2 = (project(cell(path[i+1]))-p).normalized()
        var arrow := Line2D.new()
        arrow.points = PackedVector2Array([p-direction.rotated(0.65)*6,p,p-direction.rotated(-0.65)*6])
        arrow.default_color = Color("9aa88e")
        arrow.width = 2
        marks.add_child(arrow)
