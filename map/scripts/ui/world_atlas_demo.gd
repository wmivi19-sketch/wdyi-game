extends Node
## 使用真实主场景打开上传的世界地图；Esc后可继续移动和使用原功能。
func _ready() -> void:
 var world = preload("res://scenes/MapDemo.tscn").instantiate()
 add_child(world)
 for frame in 3: await get_tree().process_frame
 world.map_system._open_continent()
