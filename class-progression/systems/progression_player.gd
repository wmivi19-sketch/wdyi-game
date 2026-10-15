extends Node3D
class_name ProgressionPlayer

var current_area_tag: String = "holy_altar"
var hp: float = 100.0
var stats: Dictionary = {"max_hp": 100.0}
var skill_ids: Array[String] = []
var can_interact: bool = true

func apply_progression(new_stats: Dictionary, new_skills: Array[String]) -> void:
	stats = new_stats.duplicate(true)
	skill_ids.assign(new_skills)
	hp = clampf(hp, 0.0, float(stats["max_hp"]))
