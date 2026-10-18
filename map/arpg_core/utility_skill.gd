class_name ARPGUtilitySkill
extends ARPGSkill
## 使用物理运动执行冲刺，碰撞由 CharacterBody2D 处理。
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.15

func can_execute(caster, target) -> bool:
	# 无目标按朝向冲刺；提供目标时遵守角色类型、距离和存活检查。
	# 已释放对象可能与 null 比较相等，但其 Variant 类型仍为 OBJECT。
	return typeof(target) == TYPE_NIL or valid_target(caster, target)

func execute(caster, target) -> void:
	var direction: Vector2 = caster.facing
	if valid_target(caster, target):
		direction = caster.global_position.direction_to(target.global_position)
	caster.start_dash(direction, maxf(0.0, dash_speed), maxf(0.0, dash_duration))
