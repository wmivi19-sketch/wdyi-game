extends Node
## 运行真正主场景并打开统一面板，示例物品从配置读取；无参数。
func _ready() -> void:
 var demo = preload("res://scenes/MapDemo.tscn").instantiate()
 add_child(demo)
 await get_tree().process_frame
 var panel = demo.character_info_ui.character_info_panel
 for id in panel.settings.demo_items: demo.get_node("WorldItems").inventory.add_item(id, int(panel.settings.demo_items[id]))
 panel.show()
