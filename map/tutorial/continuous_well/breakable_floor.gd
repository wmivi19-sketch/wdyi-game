extends Area2D
## No scene changes: a broken support starts the world's continuous Z fall.
@export var floor_index: int = 1
@export var object_id: String = "B1"
@export var target_floor: int = 0
@export var target_cell := Vector2i(12,12)
@export var required_hits: int = 3
var world

func strike() -> void:
    if not has_grounded_player(): return
    if not world.broken.has(object_id):
        world.hits[object_id] = mini(int(world.hits.get(object_id,0))+1,required_hits)
        if world.hits[object_id]<required_hits: return
        world.broken[object_id] = true
        world.refresh_props()
    try_drop()

func try_drop() -> void:
    if not world.broken.has(object_id): return
    # Area2D overlap lists update once per physics step; also validate the current feet rectangle.
    if not world.region(get_meta("object").rect).has_point(world.player.position): return
    if not has_grounded_player(): return
    world.begin_fall(target_floor,[target_cell.x,target_cell.y],object_id)

func _physics_process(_delta: float) -> void:
    try_drop()

func has_grounded_player() -> bool:
    # A visual jump keeps ground XY unchanged, so the trigger must explicitly ignore airborne feet.
    return not world.falling and not world.player.on_stair and not world.player.jumping and absf(world.player.current_z_height-floor_index*128.0)<=0.5
