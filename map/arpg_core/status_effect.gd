class_name ARPGStatusEffect
extends Resource
## 同 id 刷新持续时间；不同 id 的数值加算。负数可表示 Debuff。
@export var id: StringName = &"effect"
@export var duration: float = 3.0
@export var damage_bonus: float = 0.0
@export var damage_reduction: float = 0.0
@export var speed_bonus: float = 0.0
@export var stamina_regen_bonus: float = 0.0
@export var mana_regen_bonus: float = 0.0
@export var stun: bool = false
