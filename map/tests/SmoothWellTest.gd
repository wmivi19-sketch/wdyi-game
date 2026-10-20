extends "res://tests/ReferenceWellTest.gd"
func run() -> void:
    var session := root.get_node("GameSession")
    session.initialize_new_game()
    change_scene_to_file(session.TUTORIAL_SCENE)
    while current_scene==null: await process_frame
    game = current_scene
    await wait_frames()
    check(not game.darkness.visible and game.ambient.color.r>0.8,"default gameplay is readable without F1")
    var platforms: int = 0
    for child in game.get_children():
        if String(child.name).begins_with("StoneLandingL"): platforms += 1
    check(platforms==3,"each of the three floors has its own stone landing")
    var count: int = 0
    for i in range(3):
        for o in game.data.levels[i].objects:
            if o.type!="break": continue
            count += 1
            check(int(o.target_level)==i-1,"%s falls exactly one floor" % o.id)
            check(game.region(o.rect).has_point(game.cell(o.target_cell)),"%s landing vertically aligns with its opening" % o.id)
            var target_walkable: Array = game.data.levels[int(o.target_level)].walkable
            var safe: bool = false
            for tile in target_walkable:
                if int(tile[0])==int(o.target_cell[0]) and int(tile[1])==int(o.target_cell[1]): safe = true
            for other in game.data.levels[int(o.target_level)].objects:
                if other.type in ["drop","break"] and game.region(other.rect).has_point(game.cell(o.target_cell)): safe = false
            check(safe,"%s safe landing cannot chain into another broken floor" % o.id)
    check(count==4,"two breakable floors on L1 and two on L2")
    game.load_level(2,[32,24])
    check(await move_to(Vector2(632,424),250),"top platform connects to east gallery")
    for i in range(250):
        var delta: Vector2 = game.project(Vector2(848,424))-game.project(game.player.position)
        steer_screen(delta)
        await physics_frame
        if game.falling: break
    release_keys()
    check(game.falling and game.fall_id=="SKY","walking off skylight edge starts direct descent without E")
    check(game.glass_broken.has("GL3"),"skylight glass triggers naturally on the approach")
    var intermediate: bool = false
    for i in range(200):
        await physics_frame
        if game.player.current_z_height>128 and game.player.current_z_height<256: intermediate = true
        if not game.falling: break
    check(intermediate and game.returned_via_sky and game.current_level==1,"skylight continuously reaches middle hidden chamber")
    check(game.player.position.distance_to(game.cell([54,26]))<1,"skylight target is the east hidden-room safe floor")
    check(game.broken.is_empty(),"direct skylight descent does not require breaking any floor")
    check(not game.darkness.visible and game.ambient.color.r>0.8,"middle layer remains readable after descent")
    finished = true
    print("Smooth well: %d checks, %d failures" % [checks,failures])
    quit(0 if failures==0 else 1)
