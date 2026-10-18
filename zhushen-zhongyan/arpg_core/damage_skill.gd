class_name ARPGDamageSkill
extends ARPGSkill
@export var damage: float = 25.0
@export var damage_per_level: float = 5.0
@export var on_hit: ARPGStatusEffect

func can_execute(caster, target) -> bool:
	return valid_target(caster, target)

func execute(caster, target) -> void:
	target.take_damage(maxf(0.0, damage + damage_per_level * (level - 1)) * caster.damage_multiplier())
	if on_hit != null and not target.dead:
		target.add_effect(on_hit)
