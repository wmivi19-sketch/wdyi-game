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
func run() -> void:
    root.get_node("GameSession").initialize_new_game()
    change_scene_to_file("res://scenes/TutorialCandleWell.tscn")
    while current_scene==null: await process_frame
    game = current_scene
    await frames(5)
    check(game.player.is_physics_processing() and not paused,"new game starts with active player physics")
    check(game.player.motion_mode==CharacterBody2D.MOTION_MODE_FLOATING,"top-down character uses floating wall-slide motion")
    check(game.player.position.distance_to(game.cell([57,16]))<1,"spawn is inside spacious entrance hall")
    var cases := [[KEY_W,Vector2.UP],[KEY_S,Vector2.DOWN],[KEY_A,Vector2.LEFT],[KEY_D,Vector2.RIGHT],[KEY_UP,Vector2.UP],[KEY_DOWN,Vector2.DOWN],[KEY_LEFT,Vector2.LEFT],[KEY_RIGHT,Vector2.RIGHT]]
    for physical in [false,true]:
        for item in cases:
            game.load_level(0,game.data.spawn_cell)
            await frames(3)
            var before: Vector2 = game.player.position
            var event := InputEventKey.new()
            if physical: event.physical_keycode = item[0]
            else: event.keycode = item[0]
            event.pressed = true
            Input.parse_input_event(event)
            await frames(12)
            var screen_delta: Vector2 = game.project(game.player.position)-game.project(before)
            var expected: Vector2 = item[1]
            check(screen_delta.dot(expected)>15 and absf(screen_delta.cross(expected))<0.3,"%s key %d moves in correct screen direction" % ["physical" if physical else "logical-only",item[0]])
            event.pressed = false
            Input.parse_input_event(event)
            await frames(2)
            var released: Vector2 = game.player.position
            await frames(4)
            check(game.player.position.distance_to(released)<0.01,"released key does not leave player moving")
    game.load_level(0,[12,6])
    var interact_event := InputEventKey.new()
    interact_event.keycode = KEY_E
    interact_event.pressed = true
    game._unhandled_key_input(interact_event)
    await frames(3)
    check(game.collected.has("C2"),"logical-only E still interacts with world objects")
    check(game.nearest_phase(Vector2(509,355),12)>11.9,"top return platform cannot unwrap to middle floor")
    check(game.nearest_phase(Vector2(515,355),0)<0.1,"bottom entrance cannot unwrap to upper turn")
    check(game.has_node("ResidentView0/EntranceStoneWayfinding"),"entrance has visible stone route guidance")
    print("Entry mobility: %d checks, %d failures" % [checks,failures])
    quit(0 if failures==0 else 1)
