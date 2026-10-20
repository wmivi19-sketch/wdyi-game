extends SceneTree
func _initialize() -> void:
    call_deferred("capture")
func capture() -> void:
    root.get_node("GameSession").initialize_new_game()
    change_scene_to_file("res://scenes/TutorialCandleWell.tscn")
    for i in range(1000):
        await process_frame
        if current_scene!=null: break
    if current_scene==null: quit(1); return
    var game: Node = current_scene
    game.player.set_physics_process(false)
    DirAccess.make_dir_recursive_absolute("res://.validation/continuous")
    for phase in [0,3,6,9,12]:
        var point: Array = game.route.points[phase]
        game.player.position = Vector2(point[0],point[1])
        game.player.current_z_height = phase*(256.0/12.0)
        game.player.stair_phase = phase
        game.player.on_stair = true
        game.current_level = clampi(roundi(float(phase)/6),0,2)
        for frame in range(12): await process_frame
        await RenderingServer.frame_post_draw
        print("VIEW ",root.get_visible_rect()," LIGHT ",game.get_viewport().get_canvas_transform()*game.candle.global_position," ACTOR ",game.get_viewport().get_canvas_transform()*game.avatar.global_position," RECT ",game.darkness.size)
        var image := root.get_texture().get_image()
        image.resize(960,640,Image.INTERPOLATE_NEAREST)
        var error := image.save_png("res://.validation/continuous/height-%03d.png" % (roundi(phase*(256.0/12.0))))
        print("CAPTURE height ",roundi(phase*(256.0/12.0))," error=",error)
    quit()
