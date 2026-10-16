extends Resource
class_name DeityInfo

@export var deity_id: String = ""
@export var display_name: String = ""
@export_range(1.0, 10.0, 0.1) var base_hp_multiplier: float = 2.0
@export var stat_bonuses: Dictionary = {}
@export var divine_skill_ids: Array[String] = []
