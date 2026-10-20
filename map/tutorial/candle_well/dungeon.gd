extends Node2D
## Godot 4.x. Exactly one PointLight2D in the whole scene.
var data: Dictionary
var current_level: int = 0
var level_root: Node2D
var player: CharacterBody2D
var camera: Camera2D
var view: Node2D
var ambient: CanvasModulate
var candle: PointLight2D
var status: Label
var trigger_nodes: Array[Area2D] = []
var opened: Dictionary = {}
var broken: Dictionary = {}
var hits: Dictionary = {}
var gate_bodies: Dictionary = {}
var collected: Dictionary = {}
var cooldown: float = 0.0
const DARK_VISIBLE_AMBIENT := Color(0.85, 0.89, 0.95)
var debug_view: bool = false
var interact: bool = false
var spiral_tracking: bool = false
var spiral_direction: int = 0
var spiral_progress: float = 0.0
var spiral_last_angle: float = 0.0
var spiral_collision_root: Node2D

func cell(v: Array) -> Vector2:
    return Vector2(float(v[0]) * 16.0 + 8.0, float(v[1]) * 16.0 + 8.0)

func region(r: Array) -> Rect2:
    return Rect2(float(r[0])*16.0, float(r[1])*16.0, float(r[2])*16.0, float(r[3])*16.0)

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    data = JSON.parse_string(FileAccess.get_file_as_string("res://tutorial/candle_well/assets/dungeon.json"))
    ambient = CanvasModulate.new()
    ambient.color = DARK_VISIBLE_AMBIENT
    add_child(ambient)
    candle = PointLight2D.new()
    var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
    for y in range(512):
        for x in range(512):
            var radius := Vector2(x-256, y-256).length() / 256.0
            var strength := pow(maxf(0.0, 1.0-radius), 2.0)
            image.set_pixel(x, y, Color(strength, strength, strength, 1.0))
    candle.texture = ImageTexture.create_from_image(image)
    candle.position = project(cell([50, 46])) + Vector2(0,-25)
    candle.color = Color("b9ad8a")
    candle.energy = 1.15
    candle.texture_scale = 1.25
    candle.shadow_enabled = true
    candle.shadow_filter = Light2D.SHADOW_FILTER_PCF5
    candle.shadow_filter_smooth = 1.0
    add_child(candle)
    player = CharacterBody2D.new()
    player.set_script(load("res://tutorial/candle_well/player.gd"))
    player.collision_layer = 2
    player.collision_mask = 1
    player.z_index = 1
    var collider := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = 5.0
    collider.shape = shape
    player.add_child(collider)
    add_child(player)
    camera = Camera2D.new()
    camera.name = "PlayerCamera"
    camera.zoom = Vector2(1.5, 1.5)
    camera.position_smoothing_enabled = false
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = 2048
    camera.limit_bottom = 1024
    player.add_child(camera)
    camera.make_current()
    var ui := CanvasLayer.new()
    add_child(ui)
    status = Label.new()
    status.position = Vector2(6, 5)
    status.add_theme_font_size_override("font_size", 8)
    status.size = Vector2(465, 32)
    ui.add_child(status)
    load_level(0, [32, 59])
    if OS.get_cmdline_user_args().has("--preview"):
        debug_view = true
        ambient.color = Color.WHITE

func project(p: Vector2) -> Vector2:
    return Vector2(roundf(p.x-p.y)+1024.0,roundf((p.x+p.y)*0.5))

func _process(_delta: float) -> void:
    if is_instance_valid(camera):
        camera.position = project(player.position)-player.position
        camera.force_update_scroll()

func add_block(r: Rect2, parent: Node2D, shadow: bool = false) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = r.get_center()
    body.collision_layer = 1
    body.collision_mask = 2
    var cs := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = r.size
    cs.shape = shape
    body.add_child(cs)
    if shadow:
        var occluder := LightOccluder2D.new()
        var poly := OccluderPolygon2D.new()
        var half := r.size / 2.0
        poly.polygon = PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)])
        occluder.occluder = poly
        body.add_child(occluder)
    parent.add_child(body)
    return body

func load_level(index: int, destination: Array) -> void:
    spiral_tracking = false
    spiral_direction = 0
    spiral_progress = 0.0
    if is_instance_valid(view):
        remove_child(view)
        view.queue_free()
    if is_instance_valid(level_root):
        remove_child(level_root)
        level_root.queue_free()
    current_level = index
    trigger_nodes.clear()
    gate_bodies.clear()
    level_root = Node2D.new()
    add_child(level_root)
    move_child(level_root, 0)
    var sprite := Sprite2D.new()
    sprite.texture = load("res://tutorial/candle_well/assets/L%d_albedo.png" % index)
    sprite.centered = false
    sprite.z_index = -1
    level_root.add_child(sprite)
    sprite.visible = false
    # Merge each row into horizontal runs; no per-pixel or per-texture collision guesswork.
    var walls: Dictionary = {}
    for c in data.levels[index].solid:
        walls[Vector2i(int(c[0]),int(c[1]))] = true
    for y in range(64):
        var x: int = 0
        while x < 64:
            if not walls.has(Vector2i(x,y)):
                x += 1
                continue
            var begin := x
            while x < 64 and walls.has(Vector2i(x,y)):
                x += 1
            add_block(Rect2(begin*16,y*16,(x-begin)*16,16),level_root)
    for o in data.levels[index].objects:
        if o.type == "gate" and not opened.has(o.id):
            gate_bodies[o.id] = add_block(region(o.rect),level_root)
        if o.type in ["stairs","break","drop"]:
            var area := Area2D.new()
            var r := region(o.rect)
            area.position = r.get_center()
            area.collision_layer = 0
            area.collision_mask = 2
            area.monitoring = true
            var cs := CollisionShape2D.new()
            var shape := RectangleShape2D.new()
            shape.size = r.size
            cs.shape = shape
            area.add_child(cs)
            area.set_meta("object",o)
            level_root.add_child(area)
            trigger_nodes.append(area)
    candle.enabled = index == 2
    player.position = cell(destination)
    player.velocity = Vector2.ZERO
    if player.has_method("reset_jump"):
        player.call("reset_jump")
    camera.position = project(player.position)-player.position
    view = Node2D.new()
    view.set_script(load("res://tutorial/candle_well/iso_view.gd"))
    view.game = self
    add_child(view)
    view.build()
    build_spiral_collisions()
    camera.reset_smoothing()
    camera.force_update_scroll()
    cooldown = 0.7
    queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.physical_keycode == KEY_E:
        interact = true
    if event.physical_keycode == KEY_F1:
        debug_view = not debug_view
        ambient.color = Color.WHITE if debug_view else DARK_VISIBLE_AMBIENT
    if event.physical_keycode == KEY_R:
        opened.clear()
        broken.clear()
        hits.clear()
        collected.clear()
        load_level(0,[32,59])

func _physics_process(delta: float) -> void:
    cooldown = maxf(0.0,cooldown-delta)
    status.text = "L%d | WASD: move on ground | E: interact | R: reset | chests %d/5\n2D PIXEL / ISOMETRIC | F1: brightness assist [%s]" % [current_level,collected.size(), "ON" if debug_view else "OFF"]
    if cooldown > 0.0:
        interact = false
        return
    if update_spiral_travel():
        interact = false
        return
    for area in trigger_nodes:
        if not area.overlaps_body(player):
            continue
        var o: Dictionary = area.get_meta("object")
        var travel: bool = o.type == "drop" or (o.type == "stairs" and interact)
        if o.type == "break":
            if interact and not broken.has(o.id):
                hits[o.id] = int(hits.get(o.id,0))+1
                if hits[o.id] >= 3:
                    broken[o.id] = true
                    view.sync_objects()
                    queue_redraw()
            travel = broken.has(o.id)
        if travel:
            # Deferred to avoid changing physics objects during an overlap query.
            cooldown = 0.7
            interact = false
            call_deferred("load_level",int(o.target_level),o.target_cell)
            return
    if interact:
        for o in data.levels[current_level].objects:
            if o.type == "chest" and player.position.distance_to(cell(o.cell)) < 36.0:
                collected[o.id] = true
            if o.type == "gate" and player.position.distance_to(cell(o.button_cell)) < 30.0:
                opened[o.id] = true
                if gate_bodies.has(o.id) and is_instance_valid(gate_bodies[o.id]):
                    gate_bodies[o.id].queue_free()
                    gate_bodies.erase(o.id)
        queue_redraw()
        view.sync_objects()
    interact = false

func _draw() -> void:
    pass # All visible geometry is rendered by iso_view.gd.

func build_spiral_collisions() -> void:
    spiral_collision_root = Node2D.new()
    spiral_collision_root.name = "SpiralCollisions"
    level_root.add_child(spiral_collision_root)
    # 2D feet physics: solid spindle/inner rim, and thick outer parapet polygons.
    var inner := StaticBody2D.new()
    inner.name = "SpindleAndInnerRim"
    inner.position = Vector2(512,512)
    inner.collision_layer = 1
    inner.collision_mask = 2
    var shape := CircleShape2D.new()
    shape.radius = 48.0
    var collider := CollisionShape2D.new()
    collider.shape = shape
    inner.add_child(collider)
    spiral_collision_root.add_child(inner)
    for segment in range(64):
        var a: float = float(segment)*TAU/64.0
        var b: float = float(segment+1)*TAU/64.0
        var middle: float = (a+b)*0.5
        if absf(sin(middle))<0.27 or absf(wrapf(middle-PI*0.5,-PI,PI))<0.27:
            continue # East/west platforms and the accessible south entrance ramp.
        var body := StaticBody2D.new()
        body.name = "OuterParapet%02d" % segment
        body.position = Vector2(512,512)
        body.collision_layer = 1
        body.collision_mask = 2
        var poly := CollisionPolygon2D.new()
        poly.polygon = PackedVector2Array([
            Vector2(cos(a),sin(a))*100.0,Vector2(cos(a),sin(a))*108.0,
            Vector2(cos(b),sin(b))*108.0,Vector2(cos(b),sin(b))*100.0])
        body.add_child(poly)
        spiral_collision_root.add_child(body)

func update_spiral_travel() -> bool:
    var offset := player.position-Vector2(512,512)
    var radius := offset.length()
    if radius<50.0 or radius>116.0:
        spiral_tracking = false
        spiral_progress = 0.0
        return false
    var angle := fposmod(offset.angle(),TAU)
    if not spiral_tracking:
        # Start where the player actually joins the stair; do not require a hidden seam.
        spiral_direction = 1 if current_level==0 else (-1 if current_level==2 else 0)
        spiral_tracking = true
        spiral_progress = 0.0
        spiral_last_angle = angle
        return false
    var movement := wrapf(angle-spiral_last_angle,-PI,PI)
    spiral_last_angle = angle
    # Reject teleports/shortcuts; the player must actually follow the treads.
    if absf(movement)>0.3:
        spiral_tracking = false
        spiral_progress = 0.0
        return false
    if spiral_direction==0:
        if absf(movement)<0.005: return false
        spiral_direction = 1 if movement>0.0 else -1
    spiral_progress = maxf(0.0,spiral_progress+movement*spiral_direction)
    var at_end: bool = (angle>TAU-0.35) if spiral_direction==1 else (angle<0.35)
    if spiral_progress<0.35 or not at_end:
        return false
    var destination: int = current_level+spiral_direction
    if destination<0 or destination>2:
        return false
    var landing: Array = [40,32] if spiral_direction==1 else [40,31]
    cooldown = 0.7
    spiral_tracking = false
    call_deferred("load_level",destination,landing)
    return true
