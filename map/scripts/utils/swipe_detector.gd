class_name SwipeDetector
extends Control
## 独立 UI 手势检测；Control 比 Area2D 更适合屏幕坐标和裁剪区域。
signal swiped_left
signal swiped_right
@export var min_swipe_distance: float = 50.0
var start_position: Vector2
var tracking: bool = false
var pointer: int = -2
var blocked: bool = false
## 仅从可见检测区域内开始；同一触摸 ID 才能结束手势。
func _input(event: InputEvent) -> void:
 if not is_visible_in_tree():
  cancel()
  return
 if event is InputEventScreenTouch:
  if event.pressed:
   if not tracking: begin(event.position, event.index)
  elif tracking and pointer == event.index: finish(event.position)
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1:
  if event.pressed:
   if not tracking: begin(event.position, -1)
  elif tracking and pointer == -1: finish(event.position)
 elif event is InputEventMouseMotion and pointer == -1 and tracking:
  consume_drag(event.position)
 elif event is InputEventScreenDrag and tracking and event.index == pointer:
  consume_drag(event.position)
## position 为视口坐标；id 区分鼠标与各触点，避免多指误判。
func begin(position_value: Vector2, id: int) -> void:
 if not get_global_rect().has_point(position_value): return
 var hovered := get_viewport().gui_get_hovered_control()
 if hovered is Range or hovered is LineEdit: return
 tracking = true
 pointer = id
 start_position = position_value
 blocked = false
## 水平拖动达到阈值后吞掉输入，避免拖动结束误点按钮；position 为视口坐标。
func consume_drag(position_value: Vector2) -> void:
 var delta := position_value - start_position
 if absf(delta.y) > min_swipe_distance and absf(delta.y) > absf(delta.x):
  blocked = true
 if not blocked and absf(delta.x) >= min_swipe_distance and absf(delta.x) > absf(delta.y): get_viewport().set_input_as_handled()
## 松开时验证方向与距离；position 为视口坐标。
func finish(position_value: Vector2) -> void:
 var delta := position_value - start_position
 var valid := not blocked and absf(delta.x) >= min_swipe_distance and absf(delta.x) > absf(delta.y)
 cancel()
 if not valid: return
 get_viewport().set_input_as_handled()
 if delta.x < 0: swiped_left.emit()
 else: swiped_right.emit()
## 隐藏/取消时清除状态；无参数。
func cancel() -> void:
 tracking = false
 pointer = -2
 blocked = false
