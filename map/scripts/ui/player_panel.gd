class_name PlayerPanel
extends Control
signal page_changed(page_index: int)
signal closed
@export var page_transition_speed: float = 0.3
@export var swipe_threshold: float = 50.0
@onready var page_container: Control = $PageContainer
@onready var pages: Control = $PageContainer/Pages
@onready var backpack_page: BackpackPage = $PageContainer/Pages/BackpackPage
@onready var profession_page: ProfessionPage = $PageContainer/Pages/ProfessionPage
@onready var title_label: Label = $HeaderBar/TitleLabel
@onready var page_indicator: Label = $NavigationBar/PageIndicator
@onready var prev_button: TextureButton = $NavigationBar/PrevButton
@onready var next_button: TextureButton = $NavigationBar/NextButton
@onready var swipe_detector: SwipeDetector = $PageContainer/SwipeDetector
var current_page: int = 0
var target_page: int = 0
var screen_width: float = 0.0
var is_animating: bool = false
var settings: Dictionary = {}
var transition: Tween
var bridge: Node
## 初始化主题、导航和布局；无参数。
func _ready() -> void:
 settings = Config.read_json("res://resources/ui/player_panel.json")
 page_transition_speed = float(settings.transition_seconds)
 swipe_threshold = float(settings.swipe_threshold)
 swipe_detector.min_swipe_distance = swipe_threshold
 prev_button.pressed.connect(_on_prev_pressed)
 next_button.pressed.connect(_on_next_pressed)
 $HeaderBar/CloseButton.pressed.connect(close_panel)
 swipe_detector.swiped_left.connect(_on_next_pressed)
 swipe_detector.swiped_right.connect(_on_prev_pressed)
 page_container.resized.connect(_update_page_positions)
 visibility_changed.connect(on_visibility_changed)
 for button in [prev_button, next_button, $HeaderBar/CloseButton]:
  button.mouse_entered.connect(hover.bind(button, true))
  button.mouse_exited.connect(hover.bind(button, false))
 get_tree().node_added.connect(on_control_added)
 _update_page_positions()
 hide()
## world 是职业世界，items 是背包商店适配层。
func setup(world: Node, items: Node) -> void:
 bridge = items
 backpack_page.setup(items.inventory, settings)
 profession_page.setup(world, settings)
 refresh_data()
## index 在页面子节点数量范围内；动画期间拒绝重复导航。
func switch_to_page(page_index: int) -> void:
 var count := pages.get_child_count()
 if is_animating or page_index < 0 or page_index >= count or page_index == current_page: return
 target_page = page_index
 is_animating = true
 update_navigation()
 pages.get_child(target_page).show()
 refresh_page(target_page)
 transition = create_tween()
 transition.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
 transition.tween_property(pages, "position:x", -target_page * screen_width, page_transition_speed)
 transition.finished.connect(finish_transition)
## 完成当前目标页，统一恢复按钮与页码；无参数。
func finish_transition() -> void:
 current_page = target_page
 is_animating = false
 for index in pages.get_child_count(): pages.get_child(index).visible = index == current_page
 update_navigation()
 refresh_data()
 page_changed.emit(current_page)
## 上一页；无参数。
func _on_prev_pressed() -> void:
 switch_to_page(current_page - 1)
## 下一页；无参数。
func _on_next_pressed() -> void:
 switch_to_page(current_page + 1)
## 尺寸变化时终止旧坐标动画并准确落在目标页；无参数。
func _update_page_positions() -> void:
 if not is_node_ready(): return
 if transition != null and transition.is_running():
  transition.kill()
  current_page = target_page
  is_animating = false
 screen_width = page_container.size.x
 pages.size = Vector2(screen_width * pages.get_child_count(), page_container.size.y)
 for index in pages.get_child_count():
  var page: Control = pages.get_child(index)
  page.position = Vector2(index * screen_width, 0)
  page.size = page_container.size
  page.visible = index == current_page
 pages.position.x = -current_page * screen_width
 update_navigation()
 refresh_data()
## 刷新页标题及边界按钮；无参数。
func update_navigation() -> void:
 if not is_node_ready(): return
 var titles: Array = settings.get("page_titles", [])
 title_label.text = str(titles[current_page]) if current_page < titles.size() else "页面 %d" % (current_page + 1)
 page_indicator.text = "%d/%d" % [current_page + 1, pages.get_child_count()]
 prev_button.disabled = is_animating or current_page == 0
 next_button.disabled = is_animating or current_page == pages.get_child_count() - 1
## 只刷新当前可见页面；无参数。
func refresh_data() -> void:
 if is_visible_in_tree(): refresh_page(current_page)
## index 为目标页，页面脚本之间不互相依赖。
func refresh_page(index: int) -> void:
 var page := pages.get_child(index)
 if page.has_method("refresh"): page.refresh()
 if index == 0 and bridge != null: bridge.refresh()
## 显示时更新数据；隐藏时收敛动画并清除未结束手势。
func on_visibility_changed() -> void:
 if not is_node_ready(): return
 if not visible:
  swipe_detector.cancel()
  if transition != null and transition.is_running():
   transition.kill()
   finish_transition()
 else:
  _update_page_positions()
  call_deferred("refresh_data")
## 关闭窗口；无参数。
func close_panel() -> void:
 hide()
 closed.emit()
## button 为导航按钮；entered 指示是否悬停。
func hover(button: Control, entered: bool) -> void:
 button.pivot_offset = button.size / 2.0
 var animation := button.create_tween()
 animation.tween_property(button, "scale", Vector2.ONE * (float(settings.hover_scale) if entered else 1.0), page_transition_speed)

## 动态生成的物品和职业按钮也使用一致悬停动画；node 为新增节点。
func on_control_added(node: Node) -> void:
 if node is Button and is_ancestor_of(node):
  node.mouse_entered.connect(hover.bind(node, true))
  node.mouse_exited.connect(hover.bind(node, false))
