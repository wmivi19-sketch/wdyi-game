extends Resource
class_name ClassInfo

@export var class_id: String = ""
@export var display_name: String = ""
@export_enum("divine", "arcane", "physical", "nature") var power_system: String = "physical"
@export var stat_bonuses: Dictionary = {}
@export var skill_ids: Array[String] = []
