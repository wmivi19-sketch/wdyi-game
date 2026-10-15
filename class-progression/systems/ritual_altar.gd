extends Node3D
class_name RitualAltar

@export var altar_id: String = ""
@export var ritual_ids: Array[String] = []
@export_range(0.1, 20.0, 0.1) var interaction_radius: float = 3.0

func permits(player: ProgressionPlayer, ritual_id: String) -> bool:
	return (
		player.can_interact
		and ritual_ids.has(ritual_id)
		and player.global_position.distance_to(global_position) <= interaction_radius
	)
