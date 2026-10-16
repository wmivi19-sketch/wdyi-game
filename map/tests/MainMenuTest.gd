extends SceneTree
## 测试运行在SceneTree脚本中，菜单真正切场景后仍能继续验证。
var failures: int = 0
var checks: int = 0
var finished: bool = false
var session: Node
var menu: Control
const PROFILE := "user://main-menu-tests/"
## 延迟至自动加载初始化完毕；无参数。
func _initialize() -> void:
 call_deferred("run")
 create_timer(30.0).timeout.connect(func():
  if not finished:
   push_error("Main menu test timed out")
   quit(1))
## condition为断言，message为说明。
func check(condition: bool, message: String) -> void:
 checks += 1
 if condition: print("PASS: ",message)
 else:
  failures += 1
  push_error(message)
## 安全写入测试档，完全隔离真实存档和偏好；path/text为测试数据。
func write_text(path: String, text: String) -> void:
 var file := FileAccess.open(path,FileAccess.WRITE)
 if file == null:
  check(false,"测试文件无法写入：%s（%s）" % [path,error_string(FileAccess.get_open_error())])
  return
 file.store_string(text)
 file.close()
## 等待实际场景变化；path为预期场景资源路径。
func wait_scene(path: String) -> bool:
 for frame in 2000:
  await process_frame
  if current_scene != null and current_scene.scene_file_path == path:
   for extra in 6: await process_frame
   return true
 return false
## 验证资源、音频池、模态、转场和完整存档恢复；无参数。
func run() -> void:
 root.size = Vector2i(1080,740)
 session = root.get_node("GameSession")
 session.storage_override = {"save_path":PROFILE+"save.json","preferences_path":PROFILE+"settings.cfg"}
 if not session.prepare_storage(PROFILE+"probe.txt"):
  check(false,session.last_error)
  finish()
  return
 var probe := FileAccess.open(PROFILE+"probe.txt",FileAccess.WRITE)
 if probe == null:
  check(false,"测试用户目录不可写：%s（%s）" % [ProjectSettings.globalize_path(PROFILE),error_string(FileAccess.get_open_error())])
  finish()
  return
 probe.close()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE+"probe.txt"))
 for name in ["save.json","settings.cfg"]:
  if FileAccess.file_exists(PROFILE+name): DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE+name))
 menu = load("res://scenes/ui/main_menu.tscn").instantiate()
 root.add_child(menu)
 current_scene = menu
 for frame in 5: await process_frame
 check(menu.buttons.size() == 5,"从配置生成五个菜单动作")
 check(menu.buttons["continue"].disabled,"无存档时禁用继续")
 check(menu.bg_sprite.texture == null and menu.get_node("BackgroundLayer/Fallback").size == Vector2(root.size),"无封面时真实色块填满窗口")
 check(menu.logo_texture.texture != null and menu.logo_texture.get_node("Title").visible,"缺Logo时显示生成占位和标题")
 check(menu.sfx_players.size() == 5,"缺音效仍建立完整固定音效池")
 check(menu.bgm_player.stream == null,"缺BGM保持静音")
 if OS.get_cmdline_user_args().has("--capture-menu"):
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute("res://.validation")
  root.get_texture().get_image().save_png("res://.validation/menu-default.png")
 menu._on_audio_toggle_toggled(false)
 check(not menu.is_audio_enabled and not menu.bgm_player.playing,"静音开关不依赖音频资源存在")
 menu._on_audio_toggle_toggled(true)
 check(menu.is_audio_enabled,"无资源也可重新开启声音")
 menu._on_button_pressed("open_settings")
 check(is_instance_valid(menu.modal),"设置场景可实际打开")
 menu.modal.set_bgm(0.35)
 menu.modal.set_sfx(0.45)
 check(is_equal_approx(float(session.preferences.bgm),0.35) and FileAccess.file_exists(PROFILE+"settings.cfg"),"音量偏好可保存")
 var preferences_path: String = session.options.storage.preferences_path
 session.options.storage.preferences_path = "res://forbidden-settings.cfg"
 menu.modal.set_bgm(0.4)
 check(not menu.status.text.is_empty() and menu.status.text == session.last_error,"设置保存失败向界面显示原因")
 session.options.storage.preferences_path = preferences_path
 menu.modal.set_bgm(0.35)
 check(menu.status.text.is_empty() and session.last_error.is_empty(),"保存恢复后清除过期错误提示")
 menu.modal.close()
 await process_frame
 menu._on_button_pressed("show_credits")
 check(menu.modal.get_node("Center/Panel/Content/Names").text.contains("Godot"),"制作人员文本来自配置")
 menu.modal.close()
 await process_frame
 var fixture: Dictionary = menu.menu_config.duplicate(true)
 fixture.visual.logo_image = PROFILE+"logo.png"
 fixture.visual.background_image = PROFILE+"cover.png"
 fixture.visual.button_theme_path = ""
 fixture.audio.bgm_path = PROFILE+"tone.wav"
 fixture.audio.hover_sound = PROFILE+"tone.wav"
 fixture.audio.click_sound = PROFILE+"tone.wav"
 var image := Image.create(16,8,false,Image.FORMAT_RGBA8)
 image.fill(Color.RED)
 image.save_png(fixture.visual.logo_image)
 image.save_png(fixture.visual.background_image)
 var tone := MenuResources.tone(fixture.audio,440.0)
 check(tone.save_to_wav(PROFILE+"tone.wav") == OK,"生成标准PCM音频测试资源")
 check(MenuResources.audio(PROFILE+"tone.wav") is AudioStreamWAV,"Godot4.3原始WAV可动态加载")
 menu.config_path = PROFILE+"menu.json"
 write_text(menu.config_path,JSON.stringify(fixture))
 check(menu.reload_config(),"运行时切换菜单资源配置")
 check(menu.bg_sprite.texture != null and not menu.logo_texture.get_node("Title").visible,"自定义封面和Logo替代占位")
 check(menu.bgm_player.stream is AudioStreamWAV and menu.bgm_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"循环设置在音频流而非播放器上")
 for index in 30: menu._play_click_sound()
 check(menu.sfx_players.size() == 5,"反复播放不耗尽音效池")
 var connections := 0
 for player in menu.sfx_players: connections += player.get_signal_connection_list("finished").size()
 check(connections == 0,"播放不会累积finished连接")
 menu._on_audio_toggle_toggled(false)
 var silent: bool = not menu.bgm_player.playing
 for player in menu.sfx_players: silent = silent and not player.playing
 check(silent,"静音立即停止BGM与全部音效")
 image.fill(Color.BLUE)
 image.save_png(fixture.visual.logo_image)
 menu._process(2.0)
 check(menu.logo_texture.texture.get_image().get_pixel(0,0).is_equal_approx(Color.BLUE),"同路径同尺寸图片替换自动刷新")
 var previous: Dictionary = menu.menu_config.duplicate(true)
 write_text(menu.config_path,"{invalid")
 check(not menu.reload_config() and menu.menu_config == previous,"损坏JSON保留上一有效菜单")
 write_text(menu.config_path,JSON.stringify(fixture))
 menu.reload_config()
 root.size = Vector2i(480,640)
 for frame in 5: await process_frame
 var stack: Control = menu.get_node("UILayer/ContentScroll/Center/MainStack")
 check(stack.size.x <= 432,"窄屏菜单保持可用宽度")
 check(is_equal_approx(menu.bg_sprite.scale.x,menu.bg_sprite.scale.y),"封面等比例覆盖而不拉伸")
 if OS.get_cmdline_user_args().has("--capture-menu"):
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute("res://.validation")
  root.get_texture().get_image().save_png("res://.validation/menu-custom-narrow.png")
 menu.menu_config.navigation.game_scene = "res://missing_game.tscn"
 menu._start_new_game()
 check(not menu.is_transitioning and menu.status.text.contains("场景"),"游戏场景缺失时保留菜单")
 menu.menu_config.navigation.game_scene = "res://scenes/MapDemo.tscn"
 menu._on_button_pressed("start_new_game")
 check(menu.is_transitioning and menu.transition_overlay.visible,"新游戏执行淡出遮罩")
 menu._on_button_pressed("start_new_game")
 if not await wait_scene("res://scenes/MapDemo.tscn"):
  check(false,"新游戏进入真实地图场景")
  finish()
  return
 var world: Node = current_scene
 var bridge = world.get_node("WorldItems")
 var classes: Node = root.get_node("ClassManager")
 var clock: Node = root.get_node("GameManager")
 check(classes.players[1].class_ids == ["warrior"],"新游戏真实角色初始职业")
 check(world.player.scene_file_path == "res://scenes/player/player.tscn" and world.player.get_node("BaseBody").texture.resource_path == "res://assets/characters/player/sprites/warrior.png","新游戏接入透明战士主角场景")
 bridge.inventory.add_item("ore",3)
 bridge.inventory.add_item("herb",2)
 bridge.merchant.remove_item("ore",2)
 classes.add_class_slot("mage",1)
 world.player.hp = 77.0
 clock.current_day = 5
 clock.current_period = 1
 clock.time_updated.emit(5,1)
 clock.switch_to_continent(2)
 for frame in 8: await process_frame
 var marker: Node2D = world.loader.resource_points.get_child(0)
 world.player.teleport_to(marker.global_position)
 var key := str(world.loader.current_data.id)+":"+str(marker.get_meta("map_data").id)
 bridge.depleted[key] = true
 world.progression_world.claimed_events["test_story"] = true
 check(session.save_game(),"保存真实背包职业时钟和地图数据")
 check(not session.save_game("res://forbidden-save.json") and not session.last_error.is_empty(),"非法存档路径返回明确错误")
 var before_hash := FileAccess.get_sha256(session.save_path())
 root.get_node("CraftingSystem").busy[bridge.inventory] = true
 check(not session.save_game() and before_hash == FileAccess.get_sha256(session.save_path()),"合成进行中拒绝保存并保留原存档")
 root.get_node("CraftingSystem").busy.erase(bridge.inventory)
 var original := FileAccess.get_file_as_string(session.save_path())
 write_text(session.save_path(),"{broken")
 var old_day: int = clock.current_day
 check(not session.load_game() and clock.current_day == old_day,"损坏存档不修改当前状态")
 write_text(session.save_path(),original)
 bridge.inventory.add_item("ore",1)
 check(session.save_game(),"已有存档可原子替换保存")
 check(session.return_to_menu(),"保存后返回菜单")
 if not await wait_scene("res://scenes/ui/main_menu.tscn"):
  check(false,"返回菜单场景成功")
  finish()
  return
 menu = current_scene
 check(not menu.buttons["continue"].disabled,"有效存档开启继续按钮")
 menu._on_button_pressed("load_game")
 if not await wait_scene("res://scenes/MapDemo.tscn"):
  check(false,"继续游戏进入真实地图")
  finish()
  return
 world = current_scene
 bridge = world.get_node("WorldItems")
 var selected_continent := -1
 for child in world.character_info_ui.get_children():
  if child is OptionButton: selected_continent = child.selected
 check(selected_continent == clock.current_continent_id,"继续游戏的大陆下拉框与实际地图一致")
 var saved_position = JSON.parse_string(original).position
 check(world.loader.to_local(world.player.global_position).distance_to(Vector2(saved_position[0],saved_position[1])) < 0.1,"继续游戏恢复保存位置")
 check(bridge.inventory.get_item_count("ore") == 4 and bridge.inventory.get_item_count("herb") == 2,"继续恢复共享背包")
 check("mage" in classes.players[1].class_ids and is_equal_approx(world.player.hp,77.0),"继续恢复职业和血量")
 check(clock.current_day == 5 and clock.current_period == 1,"继续恢复游戏日期时段")
 check(bridge.merchant.get_item_count("ore") == 28,"继续恢复商人库存")
 check(bridge.depleted.has(key) and not world.loader.resource_points.get_child(0).visible,"耗尽资源不重复刷新")
 check(world.progression_world.claimed_events.has("test_story"),"剧情奖励领取状态恢复")
 check(session.return_to_menu(),"再次正常返回菜单")
 await wait_scene("res://scenes/ui/main_menu.tscn")
 menu = current_scene
 menu._on_button_pressed("start_new_game")
 await wait_scene("res://scenes/MapDemo.tscn")
 world = current_scene
 check(world.get_node("WorldItems").inventory.get_item_count("ore") == 0 and classes.players[1].class_ids == ["warrior"],"重新开始不继承旧背包和职业")
 check(session.has_valid_save(),"新游戏不擅自删除磁盘旧存档")
 check(MenuResources.wav(PackedByteArray([1,2,3])) == null,"无效WAV安全静音")
 var invalid := MenuResources.defaults()
 invalid.buttons[0].action = "execute_arbitrary_method"
 check(not MenuResources.valid(invalid),"配置动作受白名单保护")
 finish()
## 输出退出码；无参数。
func finish() -> void:
 finished = true
 print("Main menu: %d checks, %d failures" % [checks,failures])
 quit(0 if failures == 0 else 1)
