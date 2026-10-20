extends Node
var checks: int = 0
var failures: int = 0
var demo: Node
var panel: PlayerPanel
## 延迟至自动加载完成后执行；无参数。
func _ready() -> void:
 call_deferred("run")
## condition 是结果；description 是失败说明。
func check(condition: bool, description: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error(description)
 else: print("PASS: ", description)
## code 为按键；repeat 用于验证按键重复不会反复切换窗口。
func key(code: Key, repeat: bool = false) -> void:
 var event := InputEventKey.new()
 event.keycode = code
 event.physical_keycode = code
 event.pressed = true
 event.echo = repeat
 Input.parse_input_event(event)
 var release := event.duplicate() as InputEventKey
 release.pressed = false
 release.echo = false
 Input.parse_input_event(release)
## 等待切换动画并让布局更新；无参数。
func settle() -> void:
 await get_tree().create_timer(panel.page_transition_speed + 0.04).timeout
 await get_tree().process_frame
## start/end 是视口坐标；touch 为触摸手势，否则真实鼠标事件。
func swipe(start: Vector2, end: Vector2, touch: bool) -> void:
 start = get_viewport().get_screen_transform() * start
 end = get_viewport().get_screen_transform() * end
 if touch:
  var down := InputEventScreenTouch.new()
  down.index = 0
  down.position = start
  down.pressed = true
  Input.parse_input_event(down)
  var up := down.duplicate() as InputEventScreenTouch
  up.position = end
  up.pressed = false
  Input.parse_input_event(up)
 else:
  var down := InputEventMouseButton.new()
  down.button_index = MOUSE_BUTTON_LEFT
  down.position = start
  down.pressed = true
  Input.parse_input_event(down)
  var move := InputEventMouseMotion.new()
  move.position = end
  move.relative = end - start
  move.button_mask = MOUSE_BUTTON_MASK_LEFT
  Input.parse_input_event(move)
  var up := down.duplicate() as InputEventMouseButton
  up.position = end
  up.pressed = false
  Input.parse_input_event(up)
## 验证真实主场景、翻页输入、数据同步和窄屏布局；无参数。
func run() -> void:
 get_window().size = Vector2i(1080, 740)
 for frame in 3: await get_tree().process_frame
 demo = preload("res://scenes/MapDemo.tscn").instantiate()
 add_child(demo)
 for index in 5: await get_tree().process_frame
 panel = demo.character_info_ui.character_info_panel
 var bridge = demo.get_node("WorldItems")
 check(not panel.visible, "统一面板默认关闭")
 check(bridge.panel == panel, "商店与职业共用一个窗口")
 check(GameState.player_inventory == bridge.inventory, "背包引用真实角色库存")
 key(KEY_TAB)
 await get_tree().process_frame
 check(panel.visible and panel.current_page == 0, "Tab 打开背包页")
 check(panel.title_label.text == "背包" and panel.page_indicator.text == "1/2", "初始标题页码")
 check(panel.prev_button.disabled and not panel.next_button.disabled, "首尾导航边界")
 check(panel.backpack_page.grid_container.get_child_count() == bridge.inventory.slots, "全部背包格子显示")
 bridge.inventory.add_item("ore", 3)
 panel.backpack_page.show_item_detail("ore")
 check(panel.backpack_page.detail_label.text.contains("矿石"), "选择物品详情")
 check(is_equal_approx(panel.backpack_page.weight_bar.value, bridge.inventory.current_weight), "承重实时同步")
 await capture("backpack")
 panel.next_button.pressed.emit()
 check(panel.is_animating and panel.prev_button.disabled and panel.next_button.disabled, "动画期间禁用导航")
 panel.switch_to_page(0)
 await settle()
 check(panel.current_page == 1 and panel.page_indicator.text == "2/2", "平滑切换到职业页并拒绝重复操作")
 check(panel.profession_page.profession_list.get_child_count() == 3, "职业页保留三个槽位")
 panel.profession_page.show_profession_detail("warrior")
 check(panel.profession_page.detail_label.text.contains("战士"), "真实职业详情")
 await capture("profession")
 var form = panel.profession_page.profession_list.get_child(0)
 check(form.profession_id == "warrior" and form.level_label.text == "已掌握", "不虚构职业等级")
 bridge.inventory.add_item("herb", 2)
 check(panel.backpack_page.dirty, "隐藏背包页仅标脏")
 GameState.add_curse("fatigue")
 check(panel.profession_page.curse_list.get_child_count() == 2, "诅咒新增同步")
 GameState.remove_curse("fatigue")
 check(panel.profession_page.curse_list.get_child_count() == 1, "诅咒移除同步")
 var region := panel.swipe_detector.get_global_rect()
 var center := region.get_center()
 swipe(center, center + Vector2(120, 0), false)
 await settle()
 check(panel.current_page == 0, "鼠标向右拖动切回背包")
 check(not panel.backpack_page.dirty, "重新显示时刷新隐藏数据")
 swipe(center, center - Vector2(120, 0), true)
 await settle()
 check(panel.current_page == 1, "触摸向左滑动到职业")
 swipe(center, center + Vector2(10, 0), false)
 await settle()
 check(panel.current_page == 1, "短距离不误翻页")
 swipe(center, center + Vector2(120, 180), true)
 await settle()
 check(panel.current_page == 1, "纵向滚动不误翻页")
 swipe(Vector2(1, 1), Vector2(180, 1), false)
 await settle()
 check(panel.current_page == 1, "面板外手势无效")
 key(KEY_TAB, true)
 await get_tree().process_frame
 check(panel.visible, "重复按键不切换面板")
 panel.close_panel()
 ClassManager.add_class_slot("mage", 1)
 check(not panel.visible and panel.profession_page.dirty, "隐藏时职业变更不打开窗口")
 key(KEY_B)
 for frame in 3: await get_tree().process_frame
 check(panel.visible and panel.profession_page.profession_list.get_child(1).profession_id == "mage", "B 打开同一面板并刷新职业")
 var old_day := GameManager.current_day
 var old_period := GameManager.current_period
 key(KEY_N)
 check(GameManager.current_day == old_day and GameManager.current_period == old_period, "面板内按键不穿透至游戏时钟")
 panel.switch_to_page(0)
 get_window().size = Vector2i(480, 800)
 for index in 5: await get_tree().process_frame
 await settle()
 check(not panel.is_animating and is_equal_approx(panel.pages.position.x, -panel.current_page * panel.screen_width), "动画中改变尺寸不会错位")
 check(panel.page_container.clip_contents and panel.backpack_page.size == panel.page_container.size, "固定裁剪视口与页面同宽")
 panel.backpack_page.refresh()
 check(panel.backpack_page.grid_container.columns >= 1, "响应式背包列数")
 await capture("narrow")
 panel.switch_to_page(-1)
 panel.switch_to_page(5)
 check(not panel.is_animating, "拒绝无效页号")
 key(KEY_ESCAPE)
 await get_tree().process_frame
 check(not panel.visible, "Esc 关闭统一窗口")
 print("Player panel: %d checks, %d failures" % [checks, failures])
 get_tree().quit(0 if failures == 0 else 1)

## 可选真实渲染截图；name 为文件标签，headless 测试不会等待绘制。
func capture(name_value: String) -> void:
 if not OS.get_cmdline_user_args().has("--capture-ui"): return
 await RenderingServer.frame_post_draw
 var image := get_viewport().get_texture().get_image()
 var directory := "res://.validation"
 DirAccess.make_dir_recursive_absolute(directory)
 image.save_png(directory.path_join("player-panel-" + name_value + ".png"))
