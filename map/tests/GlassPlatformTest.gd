extends SceneTree
var checks: int = 0
var failures: int = 0
var game: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks += 1
    if ok: print("PASS ",label)
    else:
        failures += 1
        push_error("FAIL "+label)
func frames(count: int) -> void:
    for i in range(count): await physics_frame
    await process_frame
func run() -> void:
    var session := root.get_node("GameSession")
    session.initialize_new_game()
    change_scene_to_file(session.TUTORIAL_SCENE)
    while current_scene==null: await process_frame
    game = current_scene
    game.player.set_physics_process(false)
    await frames(4)
    check(game.glass_platforms.size()==3,"three glass platforms installed")
    var first: Area2D = game.glass_platforms[0]
    var second: Area2D = game.glass_platforms[1]
    var third: Area2D = game.glass_platforms[2]
    game.player.position = game.cell([32,21])
    game.player.current_z_height = 64.0
    await frames(4)
    check(not first.triggered and not second.triggered,"same XY in wrong height cannot trigger glass")
    game.player.current_z_height = 0.0
    game.player.jump_height = 10.0
    await frames(4)
    check(not first.triggered,"airborne overlap cannot shatter glass")
    game.player.jump_height = 0.0
    var original_point: Vector2 = game.player.position
    var original_mask: int = game.player.collision_mask
    await frames(4)
    check(first.triggered and first.trigger_count==1 and game.glass_broken.has("GL1"),"first grounded step triggers once")
    check(first.glass_support.disabled and not first.stone_support.disabled,"glass support hands over to permanent stone")
    check(not second.triggered,"L0 trigger does not break L1 glass")
    check(game.player.position==original_point and game.player.current_z_height==0 and game.player.collision_mask==original_mask,"effect does not modify player position height or collision mask")
    await frames(17)
    check(first.shard_spawn_count==14 and get_nodes_in_group("glass_shards").size()==14,"exactly fourteen irregular rigid-body shards")
    check(first.animation.sprite_frames.get_frame_count("shatter")==6,"six-frame non-looping animation")
    await frames(20)
    check(not first.animation.visible,"glass visual completely disappears")
    var all_cosmetic: bool = true
    for shard in get_nodes_in_group("glass_shards"):
        all_cosmetic = all_cosmetic and shard.collision_layer==0 and shard.collision_mask==0
    check(all_cosmetic,"shards never collide with player or another floor")
    await frames(30)
    var all_landed: bool = true
    for shard in get_nodes_in_group("glass_shards"): all_landed = all_landed and shard.landed
    check(all_landed,"ballistic fragments settle on their own tread plane")
    await frames(130)
    check(get_nodes_in_group("glass_shards").is_empty(),"all debris fades out two seconds after landing")
    game.player.position = game.cell([32,24])
    await frames(4)
    game.player.position = original_point
    await frames(20)
    check(first.trigger_count==1 and first.shard_spawn_count==14,"return visit cannot repeat the shatter")
    game.player.current_z_height = 128.0
    game.current_level = 1
    await frames(4)
    check(second.triggered and second.trigger_count==1,"height transition while inside XY overlap triggers L1 correctly")
    game.player.position = game.cell([51,26])
    game.player.current_z_height = 256.0
    game.current_level = 2
    await frames(4)
    check(third.triggered and third.trigger_count==1,"skylight-adjacent glass triggers at L2")
    check(not game.broken.has("B3") and not game.falling,"cosmetic glass never breaks the skylight drop floor")
    game.player.on_stair = false
    var snapshot: Dictionary = game.tutorial_snapshot()
    check(session.valid_snapshot(snapshot),"glass states are accepted in real tutorial saves")
    game.glass_broken.clear()
    for platform in game.glass_platforms: platform.sync_saved_state()
    game.restore_tutorial(snapshot)
    await frames(2)
    check(game.glass_broken.size()==3 and not third.animation.visible,"loading a save restores disappeared glass without replay")
    var invalid: Dictionary = snapshot.duplicate(true)
    invalid.glass_broken["GL999"] = true
    check(not session.valid_snapshot(invalid),"unknown glass state is rejected by save validation")
    var legacy: Dictionary = snapshot.duplicate(true)
    legacy.erase("glass_broken")
    check(session.valid_snapshot(legacy),"previous saves without glass flags remain compatible")
    check(game.resident_build_count==1 and game.find_children("*","PointLight2D",true,false).size()==1,"single scene and single candle remain intact")
    print("Glass platforms: %d checks, %d failures" % [checks,failures])
    quit(0 if failures==0 else 1)
