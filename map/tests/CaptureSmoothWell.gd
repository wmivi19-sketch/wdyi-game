extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
    root.get_node("GameSession").initialize_new_game()
    change_scene_to_file("res://scenes/TutorialCandleWell.tscn")
    while current_scene==null: await process_frame
    var game: Node = current_scene
    game.player.set_physics_process(false)
    DirAccess.make_dir_recursive_absolute("res://.validation/smooth")
    for frame in range(35): await process_frame
    await save_frame("entry_default")
    for phase in [3,6,9,12]:
        var point: Array = game.route.points[phase]
        game.player.position = Vector2(point[0],point[1])
        game.player.current_z_height = phase*256.0/12.0
        game.player.stair_phase = phase
        game.player.on_stair = true
        game.current_level = clampi(roundi(float(phase)/6),0,2)
        for frame in range(35): await process_frame
        await save_frame("height-%03d" % roundi(phase*256.0/12.0))
    game.player.current_z_height = 128
    game.player.position = Vector2(512,336)
    game.player.on_stair = true
    game.current_level = 1
    for frame in range(35): await process_frame
    game.set_process(false)
    game.camera.zoom = Vector2.ONE*0.68
    game.camera.position = game.project_at(Vector2(512,256),128)+Vector2(0,15)
    game.camera.force_update_scroll()
    for child in game.get_children():
        if child is CanvasLayer: child.visible = false
    for frame in range(5): await process_frame
    await save_frame("three-floor_stair_overview")
    print("Captured default readable lighting, circular flights, three landings and diagnostic overview")
    quit()
func save_frame(label: String) -> void:
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    image.resize(960,640,Image.INTERPOLATE_NEAREST)
    image.save_png("res://.validation/smooth/"+label+".png")
