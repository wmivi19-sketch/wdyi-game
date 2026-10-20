extends SceneTree
var checks: int = 0
var failures: int = 0
var finished: bool = false
var held: Dictionary = {}
var ids: Array = []
var worst_height_step: float = 0.0
var worst_position_step: float = 0.0
var game: Node

func _initialize() -> void:
    call_deferred("run")
    create_timer(150.0).timeout.connect(func():
        if not finished:
            release_keys()
            push_error("Continuous well test timeout")
            quit(1))

func check(ok: bool,label: String) -> void:
    checks += 1
    if ok: print("PASS ",label)
    else:
        failures += 1
        push_error("FAIL "+label)

func key_state(key: int,pressed: bool) -> void:
    if bool(held.get(key,false))==pressed: return
    var event := InputEventKey.new()
    event.physical_keycode = key
    event.keycode = key
    event.pressed = pressed
    Input.parse_input_event(event)
    held[key] = pressed

func release_keys() -> void:
    for key in [KEY_W,KEY_A,KEY_S,KEY_D]: key_state(key,false)

func move_to(goal: Vector2,limit: int = 600) -> bool:
    var frames: int = 0
    while game.player.position.distance_to(goal)>2.8 and frames<limit:
        var delta: Vector2 = game.project(goal)-game.project(game.player.position)
        steer_screen(delta)
        var old_point: Vector2 = game.player.position
        var old_height: float = game.player.current_z_height
        await physics_frame
        worst_height_step = maxf(worst_height_step,absf(game.player.current_z_height-old_height))
        worst_position_step = maxf(worst_position_step,game.player.position.distance_to(old_point))
        frames += 1
    release_keys()
    return game.player.position.distance_to(goal)<=2.8

func stable_roots() -> bool:
    for i in range(3):
        if game.floor_roots[i].get_instance_id()!=ids[i]: return false
    return game.resident_build_count==1

func wait_frames(count: int = 6) -> void:
    for i in range(count): await physics_frame
    await process_frame

func press_e() -> void:
    var event := InputEventKey.new()
    event.physical_keycode = KEY_E
    event.pressed = true
    game._unhandled_key_input(event)
    await wait_frames()

func run() -> void:
    var session := root.get_node("GameSession")
    session.storage_override = {"save_path":"user://reference-tests/save.json","preferences_path":"user://reference-tests/settings.cfg"}
    session.initialize_new_game()
    change_scene_to_file(session.TUTORIAL_SCENE)
    for i in range(1000):
        await process_frame
        if current_scene!=null: break
    game = current_scene
    await wait_frames()
    for r in game.floor_roots: ids.append(r.get_instance_id())
    check(int(game.data["size"][0])==64 and int(game.data["size"][1])==32,"compact 64x32 grid")
    check(get_nodes_in_group("stair_path").size()==12,"twelve connected stair sections")
    check(game.player.position.distance_to(game.cell(game.data.spawn_cell))<1,"east entry spawn")
    for goal in [Vector2(680,264),Vector2(616,296),Vector2(616,392),Vector2(512,392),Vector2(512,336)]:
        check(await move_to(goal,300),"entry walkway reaches "+str(goal))
    check(game.player.on_stair,"walk-on stair binding")
    for index in range(1,13):
        var p: Array = game.route.points[index]
        check(await move_to(Vector2(p[0],p[1]),180),"ascending section %d" % index)
    check(absf(game.player.current_z_height-256)<2,"twelve sections reach L2")
    check(worst_height_step<4 and worst_position_step<4,"continuous height and XY, no teleport")
    check(stable_roots(),"single resident scene throughout climb")
    check(await move_to(Vector2(512,392),150),"top platform exit")
    check(not game.player.on_stair,"top floor collision band restored")
    await move_to(Vector2(512,336),150)
    for index in range(11,-1,-1):
        var p: Array = game.route.points[index]
        check(await move_to(Vector2(p[0],p[1]),180),"descending section %d" % index)
    check(game.player.current_z_height<2,"same stairs return to L0")
    for spec in [[1,[11,25],"B1",0,[12,26]],[1,[10,5],"B2",0,[11,6]],[2,[36,25],"B3",1,[36,26]],[2,[16,24],"B4",1,[16,26]]]:
        game.load_level(spec[0],spec[1])
        await wait_frames()
        await press_e()
        await press_e()
        check(not game.broken.has(spec[2]),"two hits preserve "+spec[2])
        await press_e()
        check(game.broken.has(spec[2]) and game.falling,"third hit starts "+spec[2])
        for frame in range(500):
            await physics_frame
            if not game.falling: break
        check(not game.falling and game.current_level==spec[3] and game.player.position.distance_to(game.cell(spec[4]))<1,"safe reward landing "+spec[2])
    game.load_level(2,[53,25])
    await wait_frames()
    for frame in range(200):
        await physics_frame
        if not game.falling: break
    check(game.returned_via_sky and game.current_level==1,"direct skylight descent records main loop")
    var total: int = 0
    var hidden_count: int = 0
    for layer in game.data.levels:
        for o in layer.objects:
            if o.type=="chest":
                total += 1
                if o.hidden: hidden_count += 1
                game.load_level(int(layer.z)/128,o.cell)
                await press_e()
    check(total==5 and hidden_count==3 and game.collected.size()==5,"five chests, three drop-only rewards")
    game.load_level(1,[47,26])
    await press_e()
    check(game.opened.has("G4"),"east chamber opens from inside")
    for goal in [Vector2(616,424),Vector2(512,424),Vector2(512,392),Vector2(512,336)]:
        check(await move_to(goal,260),"chamber exit walkway "+str(goal))
    for index in range(5,-1,-1):
        var p: Array = game.route.points[index]
        check(await move_to(Vector2(p[0],p[1]),180),"main loop down section %d" % index)
    for goal in [Vector2(512,392),Vector2(616,392),Vector2(616,296),Vector2(680,264),game.cell([60,16])]:
        check(await move_to(goal,300),"return to east exit "+str(goal))
    check(game.can_finish(),"exit requires east L0 after sky loop")
    check(session.save_game(),"compact layout state saves")
    var snapshot: Dictionary = session.read_snapshot()
    game.restore_tutorial(snapshot)
    check(game.can_finish(),"save restore preserves completion loop")
    check(game.find_children("*","PointLight2D",true,false).size()==1,"one physical candle light")
    check(stable_roots(),"falls and restore preserve all floor instances")
    release_keys()
    finished = true
    print("Reference tutorial: %d checks, %d failures; max height step %.3f, max XY %.3f" % [checks,failures,worst_height_step,worst_position_step])
    quit(0 if failures==0 else 1)



func steer_screen(delta: Vector2) -> void:
    # Select the nearest eight-way screen heading, rather than oversteering a tiny axis error.
    var horizontal: bool = absf(delta.x)>1.8 and absf(delta.x)>=absf(delta.y)*0.4142
    var vertical: bool = absf(delta.y)>1.8 and absf(delta.y)>=absf(delta.x)*0.4142
    key_state(KEY_A,horizontal and delta.x<0)
    key_state(KEY_D,horizontal and delta.x>0)
    key_state(KEY_W,vertical and delta.y<0)
    key_state(KEY_S,vertical and delta.y>0)
