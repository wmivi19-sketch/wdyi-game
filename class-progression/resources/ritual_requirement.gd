extends Resource
class_name RitualRequirement

enum Kind { CLASS_ACQUISITION, DEITY_ASCENSION }

@export var ritual_id: String = ""
@export var kind: Kind = Kind.CLASS_ACQUISITION
@export var required_mark_id: String = ""
@export var consume_mark_on_success: bool = true
@export_range(1, 999, 1) var start_day: int = 1
@export_range(1, 999, 1) var end_day: int = 999
@export var allowed_phases: Array[String] = []
@export var allowed_area_tags: Array[String] = []
@export_range(0.1, 600.0, 0.1) var duration_seconds: float = 10.0
@export var required_class_ids: Array[String] = []
@export var granted_class_id: String = ""
@export var granted_deity_id: String = ""
