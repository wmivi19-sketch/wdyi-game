extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var session := root.get_node("GameSession")
    session.initialize_new_game()
    change_scene_to_file(session.TUTORIAL_SCENE)
    while current_scene==null: await process_frame
    var game: Node = current_scene
    game.player.set_physics_process(false)
    game.load_level(1,[32,11])
    game.player.position = Vector2(game.route.points[3][0],game.route.points[3][1])
    game.player.current_z_height = 64.0
    game.player.stair_phase = 3.0
    game.player.on_stair = true
    game.spiral_tracking = true
    game.spiral_direction = 1
    game.spiral_last_angle = fposmod((game.player.position-Vector2(512,256)).angle(),TAU)
    game.spiral_progress = PI
    var snapshot: Dictionary = game.tutorial_snapshot()
    if not session.valid_snapshot(snapshot): push_error("fractional snapshot rejected"); quit(1); return
    game.restore_tutorial(snapshot)
    if absf(game.player.current_z_height-64)>0.01 or not game.player.on_stair: quit(1); return
    snapshot.erase("layout_revision")
    snapshot.level = 0
    snapshot.position = [520,952]
    snapshot.continuous_height = 0.0
    snapshot.continuous_stairs = false
    snapshot.spiral_route.tracking = false
    if not session.valid_snapshot(snapshot): push_error("legacy snapshot rejected"); quit(1); return
    game.restore_tutorial(snapshot)
    if game.player.position.distance_to(game.cell(game.data.spawn_cell))>1: quit(1); return
    print("PASS fractional stair save/restore; PASS old tutorial validates; PASS legacy migrates to east entry")
    quit(0)
