extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
    root.get_node("GameSession").initialize_new_game()
    change_scene_to_file("res://scenes/TutorialCandleWell.tscn")
    while current_scene==null: await process_frame
    var game: Node = current_scene
    DirAccess.make_dir_recursive_absolute("res://.validation/mobility")
    var origin: Vector2 = game.player.position
    var index: int = 0
    for i in range(4):
        for frame in range(3): await physics_frame
        await save_frame(index)
        index += 1
    for key in [KEY_A,KEY_W,KEY_D,KEY_S]:
        var event := InputEventKey.new()
        event.keycode = key # Deliberately exercise logical-only input in the real controller.
        event.pressed = true
        Input.parse_input_event(event)
        var before: Vector2 = game.player.position
        for i in range(12):
            for frame in range(3): await physics_frame
            await save_frame(index)
            index += 1
        print("KEY ",OS.get_keycode_string(key)," ground distance ",before.distance_to(game.player.position))
        event.pressed = false
        Input.parse_input_event(event)
    for i in range(4):
        for frame in range(3): await physics_frame
        await save_frame(index)
        index += 1
    print("Active movement capture; final distance from spawn ",origin.distance_to(game.player.position))
    quit()
func save_frame(index: int) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    image.resize(960,640,Image.INTERPOLATE_NEAREST)
    image.save_png("res://.validation/mobility/%03d.png" % index)
