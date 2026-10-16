extends Node
## 演示直接运行真实游戏与可移动角色，按Y/M查看地图；无参数。
func _ready() -> void:
 var world = preload("res://scenes/MapDemo.tscn").instantiate()
 add_child(world)
 await get_tree().process_frame
 world.status.text += "\n双地图演示：Y 大陆概览 · M 区域细节 · Esc 返回移动"
