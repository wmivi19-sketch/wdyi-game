extends Control
var menu: Control
## parent_menu提供配置文本与主题，不硬编码制作人员名单。
func setup(parent_menu: Control) -> void:
 menu = parent_menu
 theme = menu.theme
 $Center/Panel/Content/Title.text = menu.menu_config.credits.title
 $Center/Panel/Content/Names.text = "\n".join(menu.menu_config.credits.lines)
 $Center/Panel/Content/Close.pressed.connect(close)
## 关闭当前模态，不创建第二个菜单实例。
func close() -> void:
 menu.modal = null
 queue_free()
## Esc返回菜单；event为键盘事件。
func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
  close()
  get_viewport().set_input_as_handled()
