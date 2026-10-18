class_name ARPGSkill
extends Resource
## 配置资源不保存运行时冷却；每个角色独立保存冷却。
@export var title: String = "技能"
@export var cooldown: float = 1.0
@export var mana_cost: float = 0.0
@export var stamina_cost: float = 0.0
@export_range(1, 18) var level: int = 1
@export var cast_range: float = 180.0

func valid_target(caster, target) -> bool:
	# 点击地形、空目标或已释放对象必须正常失败，不能直接访问角色属性。
	if not is_instance_valid(caster) or not is_instance_valid(target):
		return false
	if not caster is ARPGCharacter or not target is ARPGCharacter:
		return false
	return target != caster and not target.dead and caster.global_position.distance_to(target.global_position) <= maxf(0.0, cast_range)

func can_execute(_caster, _target) -> bool:
	return true

func execute(_caster, _target) -> void:
	pass
