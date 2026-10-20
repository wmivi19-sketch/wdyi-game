extends Control

@export var character_name: String = "THE REBEL"
@export var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if is_node_ready():
			for bar in [hp, stamina, mp]:
				bar.reduced_motion = value
@onready var hp: Control = $Bars/HP
@onready var stamina: Control = $Bars/Stamina
@onready var mp: Control = $Bars/MP

func _ready() -> void:
	for bar in [hp, stamina, mp]:
		bar.reduced_motion = reduced_motion

## Call after ready. This view never changes gameplay resources or save data.
func update_vitals(health: float, max_health: float, energy: float,
		max_energy: float, mana: float, max_mana: float, instant: bool = false) -> void:
	hp.set_value(health, max_health, instant)
	stamina.set_value(energy, max_energy, instant)
	mp.set_value(mana, max_mana, instant)
