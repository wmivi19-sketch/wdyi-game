class_name Item
extends Resource
@export var id: String
@export var name: String
@export var description: String
@export var icon_path: String
@export var rarity: int
@export var category: String
@export var stackable: bool
@export var max_stack: int
@export var weight: float
@export var base_value: int
@export var element_type: String
@export var is_tradeable: bool
@export var is_bound: bool

## 返回缓存图标；无参数。
func get_icon() -> Texture2D:
 return AssetManager.get_item_icon(id, icon_path)
## 按当前稀有度创建占位纹理；无参数。
func _generate_placeholder() -> Texture2D:
 return AssetManager.generate_placeholder(rarity)
