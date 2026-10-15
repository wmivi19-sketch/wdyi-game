extends Resource
class_name ClassRecipe

@export var recipe_id: String = ""
@export var materials: Dictionary = {}
@export var output_mark_id: String = ""
@export_range(1, 99, 1) var output_count: int = 1
