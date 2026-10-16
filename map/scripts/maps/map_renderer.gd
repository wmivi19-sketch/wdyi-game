class_name MapRenderer
extends "res://scripts/ui/map_canvas.gd"
## Uses existing MapTexture, TerrainLayer and marker layers from map_system.tscn.
func refresh_markers() -> void:
 update_all_marker_scales()
