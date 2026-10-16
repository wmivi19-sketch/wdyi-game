extends Node
## 兼容 UI 查询接口，直接读取现有职业管理器，无第二份职业状态。
func get_profession(id: String) -> Dictionary:
 var entry: ClassInfo = ClassManager.classes.get(id)
 if entry == null: return {}
 return {"id": id, "name": entry.display_name, "skills": entry.skill_ids, "bonuses": entry.stat_bonuses, "power_system": entry.power_system, "icon_path": ""}
