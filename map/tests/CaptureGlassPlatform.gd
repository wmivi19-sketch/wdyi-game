extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
    root.get_node("GameSession").initialize_new_game()
    change_scene_to_file("res://scenes/TutorialCandleWell.tscn")
    while current_scene==null: await process_frame
    var game: Node = current_scene
    game.player.set_physics_process(false)
    var platform: Area2D = game.glass_platforms[1]
    platform.set_physics_process(false)
    platform.monitoring = false
    game.player.position = game.cell([32,21])
    game.player.current_z_height = 128.0
    game.current_level = 1
    game.debug_view = true
    game.ambient.color = Color.WHITE
    for i in range(5): await process_frame
    platform.art.visible = true
    game.set_process(false)
    game.camera.position = platform.art.position+Vector2(0,-12)
    game.camera.zoom = Vector2.ONE*3.0
    game.camera.force_update_scroll()
    for child in game.get_children():
        if child is CanvasLayer: child.visible = false
    DirAccess.make_dir_recursive_absolute("res://.validation/glass")
    await process_frame
    await RenderingServer.frame_post_draw
    save_frame("00_intact")
    platform.monitoring = true
    platform.set_physics_process(true)
    for step in range(1,37):
        for frame in range(5): await physics_frame
        await process_frame
        await RenderingServer.frame_post_draw
        save_frame("%02d" % step)
    print("Captured intact, six-frame shatter, rigid-body debris and complete cleanup")
    quit()
func save_frame(label: String) -> void:
    var image := root.get_texture().get_image()
    image.resize(960,640,Image.INTERPOLATE_NEAREST)
    image.save_png("res://.validation/glass/"+label+".png")
