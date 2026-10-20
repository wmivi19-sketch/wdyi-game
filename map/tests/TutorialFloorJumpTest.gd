extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks += 1
    if ok: print("PASS ",label)
    else:
        failures += 1
        push_error("FAIL "+label)
func frames(count: int) -> void:
    for i in range(count): await physics_frame
func run() -> void:
    root.get_node("GameSession").initialize_new_game()
    change_scene_to_file("res://scenes/TutorialCandleWell.tscn")
    while current_scene==null: await process_frame
    var game: Node = current_scene
    game.load_level(1,[11,25])
    game.player.set_physics_process(false)
    game.player.jumping = true
    game.player.jump_height = 28.0
    await frames(3)
    var floor_area: Area2D
    for area in game.trigger_nodes:
        if area.get_meta("object").id=="B1": floor_area = area
    floor_area.strike()
    check(not game.hits.has("B1"),"airborne strike does not touch floor")
    game.hits["B1"] = 3
    game.broken["B1"] = true
    game.refresh_props()
    await frames(6)
    check(not game.falling and game.player.current_z_height==128,"jumping over a broken floor does not trigger early fall")
    game.player.reset_jump()
    await frames(2)
    check(game.falling,"landing on a broken floor starts fall")
    game.player.set_physics_process(true)
    for i in range(150):
        await physics_frame
        if not game.falling: break
    check(not game.falling and game.current_level==0,"post-jump drop reaches designated lower floor")
    game.load_level(2,[53,25])
    game.player.set_physics_process(false)
    game.player.jumping = true
    game.player.jump_height = 28.0
    await frames(3)
    check(game.falling and game.fall_id=="SKY","skylight still accepts deliberate airborne entry")
    game.player.set_physics_process(true)
    for i in range(150):
        await physics_frame
        if not game.falling: break
    check(game.returned_via_sky and game.current_level==1,"skylight jump still reaches middle hidden room")
    print("Tutorial floor jump: %d checks, %d failures" % [checks,failures])
    quit(0 if failures==0 else 1)
