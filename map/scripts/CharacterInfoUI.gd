extends CanvasLayer
## 旧入口兼容层：Tab/B 打开同一个统一玩家窗口。
signal panel_toggled(is_visible: bool)
@onready var character_info_panel: PlayerPanel = $PlayerPanel
## 转发可见状态给原地图；无参数。
func _ready() -> void:
 character_info_panel.visibility_changed.connect(func(): panel_toggled.emit(character_info_panel.visible))
## items 为地图背包适配层；职业、背包两页只绑定一次。
func setup(items: Node) -> void:
 character_info_panel.setup(items.world.progression_world, items)
## 保留 Tab/B 并支持 Esc 关闭；event 为实际输入事件。
func _input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if character_info_panel.visible and event.keycode == KEY_F5:
  GameSession.quick_save_feedback()
  get_viewport().set_input_as_handled()
 elif character_info_panel.visible and event.keycode == KEY_F10:
  GameSession.return_to_menu()
  get_viewport().set_input_as_handled()
 elif event.is_action_pressed("open_player_panel"):
  character_info_panel.visible = not character_info_panel.visible
  get_viewport().set_input_as_handled()
 elif event.keycode == KEY_ESCAPE and character_info_panel.visible:
  character_info_panel.close_panel()
  get_viewport().set_input_as_handled()

 elif character_info_panel.visible:
  if event.keycode == KEY_LEFT: character_info_panel._on_prev_pressed()
  elif event.keycode == KEY_RIGHT: character_info_panel._on_next_pressed()
  elif event.keycode == KEY_F3 and character_info_panel.bridge != null: character_info_panel.bridge.open_gm()
  get_viewport().set_input_as_handled()
