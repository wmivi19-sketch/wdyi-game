extends Area2D
## XY overlap alone is insufficient: all three floors share the same physics plane.
var world
var definition: Dictionary
var triggered: bool = false
var trigger_count: int = 0
var shard_spawn_count: int = 0
var art: Node2D
var animation: AnimatedSprite2D
var glass_support: CollisionShape2D
var stone_support: CollisionShape2D
var effect_elapsed: float = 0.0
var shards_spawned: bool = false

func _ready() -> void:
    collision_layer = 0
    collision_mask = 8
    var rectangle: Rect2 = world.region(definition.rect)
    position = rectangle.get_center()
    var trigger := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = rectangle.size
    trigger.shape = shape
    add_child(trigger)
    glass_support = make_support("GlassSupport",32,false,shape)
    stone_support = make_support("PermanentStoneSupport",64,true,shape)
    art = Node2D.new()
    art.name = "GlassVisual_"+String(definition.id)
    art.position = world.project_at(position,float(definition.height))
    art.scale = Vector2.ONE*(1.0+float(definition.height)/256.0*0.035)
    art.z_index = 182
    world.add_child(art)
    animation = AnimatedSprite2D.new()
    var frames := SpriteFrames.new()
    frames.add_animation("shatter")
    frames.set_animation_loop("shatter",false)
    frames.set_animation_speed("shatter",12.0)
    var sheet: Texture2D = preload("res://tutorial/continuous_well/assets/glass_shatter_6frames.png")
    for i in range(6):
        var atlas := AtlasTexture.new()
        atlas.atlas = sheet
        atlas.region = Rect2(i*64,0,64,48)
        frames.add_frame("shatter",atlas)
    animation.sprite_frames = frames
    animation.animation = "shatter"
    art.add_child(animation)
    animation.animation_finished.connect(func(): animation.hide())
    body_entered.connect(func(body: Node2D):
        if body==world.player: try_trigger())
    sync_saved_state()

func make_support(label: String,bit: int,disabled: bool,shape: Shape2D) -> CollisionShape2D:
    # In this 2D projection, walkable support is a sensor, never a horizontal solid wall.
    var support := Area2D.new()
    support.name = label
    support.collision_layer = bit
    support.collision_mask = 0
    support.monitoring = false
    var collider := CollisionShape2D.new()
    collider.shape = shape
    collider.disabled = disabled
    support.add_child(collider)
    add_child(support)
    return collider

func try_trigger() -> void:
    if triggered or world.falling or world.player.jump_height>0.5: return
    if absf(world.player.current_z_height-float(definition.height))>6.0: return
    if not world.region(definition.rect).has_point(world.player.position): return
    if not overlaps_body(world.player): return
    triggered = true
    trigger_count += 1
    world.glass_broken[String(definition.id)] = true
    effect_elapsed = 0.0
    shards_spawned = false
    # Enable permanent support first; existing stair/core/parapet colliders remain intact.
    stone_support.set_deferred("disabled",false)
    glass_support.set_deferred("disabled",true)
    animation.show()
    animation.play("shatter")

func sync_saved_state() -> void:
    var saved: bool = world.glass_broken.has(String(definition.id))
    if saved and not triggered:
        triggered = true
        shards_spawned = true
        stone_support.set_deferred("disabled",false)
        glass_support.set_deferred("disabled",true)
        animation.stop()
        animation.hide()
    elif not saved:
        triggered = false
        shards_spawned = false
        effect_elapsed = 0.0
        glass_support.set_deferred("disabled",false)
        stone_support.set_deferred("disabled",true)
        animation.stop()
        animation.frame = 0
        animation.show()

func _physics_process(delta: float) -> void:
    try_trigger() # Also handles entering this height while already inside the XY sensor.
    art.visible = absf(world.player.current_z_height-float(definition.height))<38.0
    if triggered and not shards_spawned:
        effect_elapsed += delta
        if effect_elapsed>=0.25:
            shards_spawned = true
            spawn_shards()

func spawn_shards() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = String(definition.id).hash()
    for i in range(14):
        var shard := RigidBody2D.new()
        shard.set_script(load("res://tutorial/continuous_well/glass_shard.gd"))
        shard.name = "Shard%02d" % i
        shard.position = art.position+Vector2(rng.randf_range(-23,23),rng.randf_range(-8,8))
        shard.landing_y = shard.position.y+rng.randf_range(10,22)
        shard.linear_velocity = Vector2(rng.randf_range(-45,45),rng.randf_range(-95,-45))
        shard.angular_velocity = rng.randf_range(-6,6)
        shard.custom_integrator = true
        shard.collision_layer = 0
        shard.collision_mask = 0
        shard.mass = 0.02
        shard.z_index = art.z_index+1
        shard.source_height = float(definition.height)
        shard.world = world
        var polygon := Polygon2D.new()
        var radius: float = rng.randf_range(3,7)
        polygon.polygon = PackedVector2Array([Vector2(-radius,-radius*0.25),Vector2(radius*0.4,-radius),Vector2(radius, radius*0.5),Vector2(-radius*0.2,radius*0.65)])
        polygon.color = Color(0.43,0.49,0.48,0.68)
        shard.add_child(polygon)
        var reflection := Line2D.new()
        reflection.points = PackedVector2Array([polygon.polygon[0],polygon.polygon[1]])
        reflection.width = 1
        reflection.default_color = Color(0.66,0.70,0.67,0.5)
        shard.add_child(reflection)
        var collider := CollisionShape2D.new()
        var circle := CircleShape2D.new()
        circle.radius = 2
        collider.shape = circle
        shard.add_child(collider)
        shard.add_to_group("glass_shards")
        world.add_child(shard)
        shard_spawn_count += 1
