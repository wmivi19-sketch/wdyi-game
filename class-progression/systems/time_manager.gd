extends Node

# Demo clock. Only the authoritative simulation should change these values.
var current_day: int = 12
var current_phase: String = "night"

func get_current_day() -> int:
	return current_day

func get_current_phase() -> String:
	return current_phase
