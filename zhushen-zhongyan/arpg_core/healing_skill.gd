class_name ARPGHealingSkill
extends ARPGSkill
@export var healing: float = 30.0

func execute(caster, _target) -> void:
	caster.resources.heal(maxf(0.0, healing) * level)
