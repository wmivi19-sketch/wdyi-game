extends SceneTree

func _initialize() -> void:
    call_deferred("capture")

func capture() -> void:
    var session := root.get_node("GameSession")
    session.storage_override = {"save_path":"user://tutorial-capture/save.json","preferences_path":"user://tutorial-capture/settings.cfg"}
    change_scene_to_file("res://scenes/ui/main_menu.tscn")
    await create_timer(0.8).timeout
    current_scene._start_new_game()
    await create_timer(1.0).timeout
    if current_scene.scene_file_path != session.TUTORIAL_SCENE:
        quit(1)
        return
    current_scene.load_level(1,[32,28])
    for i in range(10): await process_frame
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://.validation")
    var image := root.get_texture().get_image()
    image.resize(960,640,Image.INTERPOLATE_NEAREST)
    var error := image.save_png("res://.validation/tutorial-integrated.png")
    print("Tutorial screenshot: ",error)
    quit(0 if error==OK else 1)
