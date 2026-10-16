extends Node2D
class_name RitualAltar

@export var altar_id: String = ""
@export var ritual_ids: Array[String] = []
@export_range(1.0, 200.0, 1.0) var interaction_radius: float = 20.0

func permits(player: ProgressionPlayer, ritual_id: String) -> bool:
	return (
		player.can_interact
		and ritual_ids.has(ritual_id)
		and player.global_position.distance_to(global_position) <= interaction_radius
	)
