extends Control
var menu: Control
@onready var bgm: HSlider = $Center/Panel/Content/BGM
@onready var sfx: HSlider = $Center/Panel/Content/SFX
@onready var enabled: CheckBox = $Center/Panel/Content/Enabled
@onready var fullscreen: CheckBox = $Center/Panel/Content/Fullscreen
## parent_menu是主菜单引用，偏好保存到用户配置而非修改项目JSON。
func setup(parent_menu: Control) -> void:
 menu = parent_menu
 theme = menu.theme
 bgm.value = GameSession.preferences.bgm
 sfx.value = GameSession.preferences.sfx
 enabled.button_pressed = GameSession.preferences.enabled
 enabled.disabled = not bool(menu.menu_config.audio.enable_audio)
 fullscreen.button_pressed = get_window().mode == Window.MODE_FULLSCREEN
 bgm.value_changed.connect(set_bgm)
 sfx.value_changed.connect(set_sfx)
 enabled.toggled.connect(set_enabled)
 fullscreen.toggled.connect(set_fullscreen)
 $Center/Panel/Content/Close.pressed.connect(close)
## value是0至1的音乐偏好音量。
func set_bgm(value: float) -> void:
 GameSession.preferences.bgm = value
 apply()
## value是0至1的UI音效偏好音量。
func set_sfx(value: float) -> void:
 GameSession.preferences.sfx = value
 apply()
## value是偏好静音开关。
func set_enabled(value: bool) -> void:
 GameSession.preferences.enabled = value
 apply()
## value指示是否使用当前游戏窗口全屏。
func set_fullscreen(value: bool) -> void:
 GameSession.preferences.fullscreen = value
 get_window().mode = Window.MODE_FULLSCREEN if value else Window.MODE_WINDOWED
 apply()
## 应用音频并保存偏好；无参数。
func apply() -> void:
 menu.apply_audio_preferences()
 menu.status.text = "" if GameSession.save_preferences() else GameSession.last_error
## 关闭并清除主菜单的模态引用；无参数。
func close() -> void:
 menu.modal = null
 queue_free()
## Esc只关闭当前设置，不退出游戏。
func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
  close()
  get_viewport().set_input_as_handled()
