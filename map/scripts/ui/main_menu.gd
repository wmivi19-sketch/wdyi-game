class_name MainMenu
extends Control
## 可替换资源的开始界面：保留上一个有效配置，资源失败时使用占位/静音。
@export_file("*.json") var config_path: String = MenuResources.CONFIG_PATH
var menu_config: Dictionary = {}
var buttons: Dictionary = {}
var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var hover_stream: AudioStream
var click_stream: AudioStream
var is_audio_enabled: bool = true
var is_transitioning: bool = false
var elapsed: float = 0.0
var fingerprint: String = ""
var sfx_cursor: int = 0
var hover_tweens: Dictionary = {}
var modal: Control
@onready var bg_sprite: Sprite2D = $BackgroundLayer/BackgroundSprite
@onready var logo_texture: TextureRect = $UILayer/ContentScroll/Center/MainStack/LogoSection/LogoTexture
@onready var subtitle_label: Label = $UILayer/ContentScroll/Center/MainStack/LogoSection/SubtitleLabel
@onready var version_label: Label = $UILayer/FooterSection/VersionLabel
@onready var copyright_label: Label = $UILayer/FooterSection/CopyrightLabel
@onready var audio_toggle: CheckBox = $UILayer/AudioToggle
@onready var transition_overlay: ColorRect = $TransitionOverlay
@onready var button_section: VBoxContainer = $UILayer/ContentScroll/Center/MainStack/ButtonSection
@onready var status: Label = $UILayer/ContentScroll/Center/MainStack/Status
## 初始化菜单和输入；无参数。
func _ready() -> void:
 clip_contents = true
 audio_toggle.toggled.connect(_on_audio_toggle_toggled)
 resized.connect(layout_menu)
 reload_config()
 if GameSession.preferences.fullscreen: get_window().mode = Window.MODE_FULLSCREEN
 fingerprint = MenuResources.signature(menu_config, config_path)
## 重载JSON/同路径资源；格式非法时保留旧配置，无初始配置时使用完整默认值。
func reload_config() -> bool:
 var candidate := MenuResources.read_config(config_path)
 var valid := not candidate.is_empty()
 if not valid:
  push_warning("菜单配置缺失或无效，保留有效配置/使用安全默认值")
  if not menu_config.is_empty(): return false
  candidate = MenuResources.defaults()
 menu_config = candidate
 GameSession.configure_menu(menu_config)
 _apply_visual_config()
 _create_buttons()
 _setup_audio()
 version_label.text = "v" + str(menu_config.version)
 copyright_label.text = menu_config.copyright
 copyright_label.tooltip_text = menu_config.copyright
 _update_continue_button()
 layout_menu()
 return valid
## 为真实背景生成可绘制占位，不对空Node2D设置modulate冒充背景。
func _apply_visual_config() -> void:
 var visual: Dictionary = menu_config.visual
 $BackgroundLayer/Fallback.color = MenuResources.color(visual.background_color_fallback)
 bg_sprite.texture = MenuResources.texture(visual.background_image)
 var logo := MenuResources.texture(visual.logo_image)
 var title: Label = logo_texture.get_node("Title")
 title.visible = logo == null
 title.text = visual.title_text
 if logo == null:
  var image := Image.create(512,128,false,Image.FORMAT_RGBA8)
  image.fill(MenuResources.color(visual.logo_fallback_color))
  logo = ImageTexture.create_from_image(image)
 logo_texture.texture = logo
 subtitle_label.text = visual.subtitle_text
 theme = make_theme()
## 加载配置Theme，或按JSON色彩生成完整占位主题。
func make_theme() -> Theme:
 var path := str(menu_config.visual.button_theme_path)
 var result: Theme
 if not path.is_empty() and ResourceLoader.exists(path): result = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE) as Theme
 if result == null:
  result = Theme.new()
  var style: Dictionary = menu_config.style
  for pair in [["normal","normal_color"],["hover","hover_color"],["pressed","pressed_color"],["disabled","disabled_color"],["focus","hover_color"]]:
   var box := StyleBoxFlat.new()
   box.bg_color = Color(style[pair[1]])
   box.border_color = Color(style.border_color)
   box.set_border_width_all(int(style.border_width))
   box.set_corner_radius_all(int(style.corner_radius))
   for side in [SIDE_LEFT,SIDE_RIGHT]: box.set_content_margin(side,14.0)
   for side in [SIDE_TOP,SIDE_BOTTOM]: box.set_content_margin(side,8.0)
   result.set_stylebox(pair[0],"Button",box)
 var font := SystemFont.new()
 font.font_names = PackedStringArray([str(menu_config.style.font_name),"Noto Sans CJK SC","sans-serif"])
 result.default_font = font
 result.default_font_size = int(menu_config.style.font_size)
 result.set_color("font_color","Button",Color(menu_config.style.font_color))
 for state in menu_config.visual.button_textures:
  var texture := MenuResources.texture(str(menu_config.visual.button_textures[state]))
  if texture == null: continue
  var box := StyleBoxTexture.new()
  box.texture = texture
  box.content_margin_left = 14.0
  box.content_margin_right = 14.0
  box.content_margin_top = 8.0
  box.content_margin_bottom = 8.0
  result.set_stylebox(state,"Button",box)
 var panel := StyleBoxFlat.new()
 panel.bg_color = Color(menu_config.style.normal_color)
 panel.border_color = Color(menu_config.style.border_color)
 panel.set_border_width_all(int(menu_config.style.border_width))
 panel.set_corner_radius_all(int(menu_config.style.corner_radius))
 for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: panel.set_content_margin(side,18.0)
 result.set_stylebox("panel","PanelContainer",panel)
 return result
## 从白名单配置生成按钮，先移出旧节点，避免热重载时重复布局。
func _create_buttons() -> void:
 for tween in hover_tweens.values():
  if tween != null and tween.is_running(): tween.kill()
 hover_tweens.clear()
 for child in button_section.get_children():
  button_section.remove_child(child)
  child.queue_free()
 buttons.clear()
 for entry in menu_config.buttons:
  var button := Button.new()
  button.name = str(entry.id).validate_node_name()
  button.text = entry.text
  button.custom_minimum_size.y = float(menu_config.layout.button_height)
  button.pressed.connect(_on_button_pressed.bind(str(entry.action)))
  button.mouse_entered.connect(_on_button_hover.bind(button,true))
  button.mouse_exited.connect(_on_button_hover.bind(button,false))
  button.focus_entered.connect(_play_hover_sound)
  button_section.add_child(button)
  buttons[entry.id] = button
 call_deferred("focus_default_button")
## 确保总线存在，返回其索引；name_value为总线名。
func ensure_bus(name_value: String) -> int:
 var index := AudioServer.get_bus_index(name_value)
 if index >= 0: return index
 AudioServer.add_bus()
 index = AudioServer.bus_count - 1
 AudioServer.set_bus_name(index,name_value)
 return index
## 建立固定大小音效池；每次播放不追加finished连接。
func _setup_audio() -> void:
 var audio: Dictionary = menu_config.audio
 ensure_bus(audio.bgm_bus)
 ensure_bus(audio.sfx_bus)
 if bgm_player == null:
  bgm_player = AudioStreamPlayer.new()
  bgm_player.name = "MenuBGM"
  add_child(bgm_player)
  bgm_player.finished.connect(_on_bgm_finished)
 bgm_player.stop()
 bgm_player.bus = audio.bgm_bus
 bgm_player.stream = MenuResources.audio(audio.bgm_path)
 if bgm_player.stream is AudioStreamOggVorbis: bgm_player.stream.loop = true
 elif bgm_player.stream is AudioStreamWAV: bgm_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
 for player in sfx_players:
  player.stop()
  remove_child(player)
  player.queue_free()
 sfx_players.clear()
 for index in int(audio.pool_size):
  var player := AudioStreamPlayer.new()
  player.bus = audio.sfx_bus
  add_child(player)
  sfx_players.append(player)
 hover_stream = MenuResources.audio(audio.hover_sound)
 click_stream = MenuResources.audio(audio.click_sound)
 if audio.generate_placeholders:
  if hover_stream == null: hover_stream = MenuResources.tone(audio,float(audio.hover_hz))
  if click_stream == null: click_stream = MenuResources.tone(audio,float(audio.click_hz))
 apply_audio_preferences()
## 更新音量和静音；不覆盖资源配置的全局禁用值。
func apply_audio_preferences() -> void:
 var audio: Dictionary = menu_config.audio
 is_audio_enabled = bool(audio.enable_audio) and bool(GameSession.preferences.enabled)
 audio_toggle.set_pressed_no_signal(is_audio_enabled)
 audio_toggle.disabled = not bool(audio.enable_audio)
 bgm_player.volume_db = linear_to_db(maxf(0.0001,float(audio.bgm_volume) * float(GameSession.preferences.bgm)))
 for player in sfx_players:
  player.volume_db = linear_to_db(maxf(0.0001,float(audio.sfx_volume) * float(GameSession.preferences.sfx)))
  if float(GameSession.preferences.sfx) * float(audio.sfx_volume) == 0.0: player.stop()
 if is_audio_enabled and bgm_player.stream != null and float(GameSession.preferences.bgm) * float(menu_config.audio.bgm_volume) > 0.0:
  if not bgm_player.playing: bgm_player.play()
 else:
  bgm_player.stop()
  for player in sfx_players: player.stop()
## 通用流的BGM循环后备；播放器没有loop属性。
func _on_bgm_finished() -> void:
 if is_audio_enabled and bgm_player.stream != null and float(GameSession.preferences.bgm) * float(menu_config.audio.bgm_volume) > 0.0 and not is_transitioning: bgm_player.play()
## 从空闲槽播放，全部忙时轮换；stream为已加载音效。
func play_sfx(stream: AudioStream) -> void:
 if not is_audio_enabled or float(GameSession.preferences.sfx) * float(menu_config.audio.sfx_volume) == 0.0 or stream == null or sfx_players.is_empty(): return
 var selected: AudioStreamPlayer
 for player in sfx_players:
  if not player.playing:
   selected = player
   break
 if selected == null:
  selected = sfx_players[sfx_cursor % sfx_players.size()]
  sfx_cursor += 1
 selected.stop()
 selected.stream = stream
 selected.play()
## 播放悬停音效；无参数。
func _play_hover_sound() -> void:
 play_sfx(hover_stream)
## 播放点击音效；无参数。
func _play_click_sound() -> void:
 play_sfx(click_stream)
## button为配置按钮；entered表示进入/离开。
func _on_button_hover(button: Button, entered: bool) -> void:
 if entered: _play_hover_sound()
 var id := button.get_instance_id()
 if hover_tweens.has(id) and hover_tweens[id].is_running(): hover_tweens[id].kill()
 button.pivot_offset = button.size / 2.0
 var tween := button.create_tween()
 tween.tween_property(button,"scale",Vector2.ONE * (float(menu_config.layout.hover_scale) if entered else 1.0),float(menu_config.layout.hover_seconds))
 hover_tweens[id] = tween
## 只分派明确的菜单动作，不执行配置指定的任意方法。
func _on_button_pressed(action: String) -> void:
 if is_transitioning or is_instance_valid(modal): return
 _play_click_sound()
 match action:
  "start_new_game": _start_new_game()
  "load_game": _load_game()
  "open_settings": open_modal("settings_scene")
  "show_credits": open_modal("credits_scene")
  "quit_game": get_tree().quit()
## 场景路径来自配置，验证PackedScene类型后才修改新局状态。
func game_scene() -> PackedScene:
 var path := str(menu_config.navigation.game_scene)
 if not ResourceLoader.exists(path): return null
 return ResourceLoader.load(path) as PackedScene
## 开始全新会话；磁盘存档保留到玩家主动保存时才替换。
func _start_new_game() -> void:
 var packed := game_scene()
 if packed == null:
  status.text = "游戏场景缺失或类型不正确"
  return
 GameState.initialize_new_game()
 _fade_and_change_scene(packed)
## 继续有效存档；失败保留菜单与当前状态。
func _load_game() -> void:
 var packed := game_scene()
 if packed == null:
  status.text = "游戏场景缺失或类型不正确"
  return
 if not GameState.load_game():
  status.text = GameSession.last_error
  _update_continue_button()
  return
 _fade_and_change_scene(packed)
## 单次淡出转场；packed为已验证场景，失败时恢复菜单交互。
func _fade_and_change_scene(packed: PackedScene) -> void:
 if is_transitioning: return
 is_transitioning = true
 for button in buttons.values(): button.disabled = true
 audio_toggle.disabled = true
 transition_overlay.show()
 transition_overlay.modulate.a = 0.0
 var tween := create_tween()
 tween.tween_property(transition_overlay,"modulate:a",1.0,float(menu_config.layout.transition_seconds))
 await tween.finished
 var error := get_tree().change_scene_to_packed(packed)
 if error != OK:
  is_transitioning = false
  transition_overlay.hide()
  for button in buttons.values(): button.disabled = false
  apply_audio_preferences()
  _update_continue_button()
  status.text = "场景切换失败，错误码 %d" % error
## 检测完整存档；无存档或损坏时禁用继续，不伪造加载成功。
func _update_continue_button() -> void:
 if not buttons.has("continue") or is_transitioning: return
 var valid := GameSession.has_valid_save()
 buttons["continue"].disabled = not valid
 buttons["continue"].tooltip_text = "恢复上次保存的游戏" if valid else GameSession.last_error
## path_key为设置/制作人员场景配置键；缺失时仅提示。
func open_modal(path_key: String) -> void:
 var path := str(menu_config.navigation.get(path_key,""))
 var packed: PackedScene
 if ResourceLoader.exists(path): packed = ResourceLoader.load(path) as PackedScene
 if packed == null:
  status.text = "界面场景不可用"
  return
 modal = packed.instantiate() as Control
 if modal == null:
  status.text = "界面根节点必须为Control"
  return
 add_child(modal)
 modal.setup(self)
## 声音复选框true为开启；value为用户选择。
func _on_audio_toggle_toggled(value: bool) -> void:
 GameSession.preferences.enabled = value
 GameSession.save_preferences()
 apply_audio_preferences()
## 响应式居中、纵向滚动和等比例封面裁切；无参数。
func layout_menu() -> void:
 if not is_node_ready() or menu_config.is_empty(): return
 var dimensions := size
 var layout: Dictionary = menu_config.layout
 $BackgroundLayer/Fallback.size = dimensions
 if bg_sprite.texture != null:
  var texture_size := bg_sprite.texture.get_size()
  var factor := maxf(dimensions.x / texture_size.x, dimensions.y / texture_size.y)
  bg_sprite.scale = Vector2.ONE * factor
  bg_sprite.position = (dimensions - texture_size * factor) / 2.0
 var stack: VBoxContainer = $UILayer/ContentScroll/Center/MainStack
 stack.custom_minimum_size.x = maxf(120.0,minf(float(layout.max_width),dimensions.x - 2.0 * float(layout.margin) - 24.0))
 stack.add_theme_constant_override("separation",int(layout.spacing) * 2)
 logo_texture.custom_minimum_size.y = minf(float(layout.logo_height),maxf(64.0,dimensions.y * 0.18))
 button_section.add_theme_constant_override("separation",int(layout.spacing))
## 定期检测JSON及资源内容；转场时冻结菜单避免重建按钮。
func _process(delta: float) -> void:
 if menu_config.is_empty() or is_transitioning: return
 elapsed += delta
 if elapsed < float(menu_config.layout.poll_seconds): return
 elapsed = 0.0
 var latest := MenuResources.signature(menu_config,config_path)
 if latest != fingerprint:
  reload_config()
  fingerprint = MenuResources.signature(menu_config,config_path)
 _update_continue_button()
## 离开菜单立即停止音频；无参数。
func _exit_tree() -> void:
 if is_instance_valid(bgm_player): bgm_player.stop()
 for player in sfx_players:
  if is_instance_valid(player): player.stop()

## 多次热重载可能在同一帧发生，只为当前仍在树中的按钮设置焦点。
func focus_default_button() -> void:
 if not is_transitioning and buttons.has("new_game") and is_instance_valid(buttons.new_game) and buttons.new_game.is_inside_tree(): buttons.new_game.grab_focus()
