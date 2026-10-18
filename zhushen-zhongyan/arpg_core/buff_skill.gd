class_name ARPGBuffSkill
extends ARPGSkill
@export var effect: ARPGStatusEffect

func can_execute(_caster, _target) -> bool:
	return effect != null

func execute(caster, _target) -> void:
	caster.add_effect(effect)
