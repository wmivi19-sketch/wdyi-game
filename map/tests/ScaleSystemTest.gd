extends Node
var failures: int = 0
func check(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
 else: print("PASS: ", message)
func _ready() -> void:
 call_deferred("run")
func run() -> void:
 var bounds := {"begin": Vector2(-5000, -5000), "end": Vector2(5000, 5000)}
 var point := Vector2(-235, 1367)
 var pixel := CoordinateConverter.world_to_map(point, bounds, Vector2(2048, 2048))
 check(CoordinateConverter.map_to_world(pixel, bounds, Vector2(2048, 2048)).is_equal_approx(point), "offset world/map round trip")
 check(CoordinateConverter.calculate_marker_size("continent") == Vector2(16, 16), "continent 16 px")
 check(CoordinateConverter.calculate_marker_size("local") == Vector2(24, 24), "local 24 px")
 var camera := SmartCamera.new()
 add_child(camera)
 camera.set_mode("local", {"begin": Vector2(-10, -10), "end": Vector2(10, 10)})
 camera.set_target(Vector2(500, 500))
 camera.zoom = Vector2.ONE
 camera._clamp_to_bounds()
 check(camera.global_position.is_equal_approx(Vector2.ZERO), "oversized viewport centers camera")
 camera.position = Vector2(40, 60)
 camera.rotation = 0.25
 camera.zoom = Vector2(2, 2)
 camera.force_update_scroll()
 var screen := CoordinateConverter.world_to_screen(point, camera)
 check(CoordinateConverter.screen_to_world(screen, camera).is_equal_approx(point), "camera screen/world round trip with rotation")
 var parent := Node2D.new()
 parent.scale = Vector2(0.2, 0.3)
 add_child(parent)
 var marker := preload("res://scenes/ui/map_marker.tscn").instantiate() as MapMarker
 marker.current_map_type = "local"
 parent.add_child(marker)
 marker.update_appearance()
 var transform := marker.get_viewport_transform() * marker.get_global_transform()
 var rendered := Vector2(transform.x.length(), transform.y.length()) * marker.texture.get_size()
 check(rendered.is_equal_approx(Vector2(24, 24)), "marker stays 24 pixels under camera and parent scaling")
 # Explicit follow must only use Camera2D's smoothing, without a second lerp.
 camera.world_bounds = {}
 camera.set_target(Vector2(700, 800))
 camera._process(0.016)
 check(camera.global_position.is_equal_approx(Vector2(700, 800)), "explicit follow uses one smoothing stage")
 camera.world_bounds = {"begin": Vector2(-2000, -2000), "end": Vector2(2000, 2000)}
 camera.ignore_rotation = false
 camera.rotation = PI / 4.0
 camera.offset = Vector2(180, 0)
 camera.zoom = Vector2.ONE
 camera.global_position = Vector2(5000, 5000)
 camera._clamp_to_bounds()
 var half_view := get_viewport().get_visible_rect().size / 2.0
 var rotated_half := (half_view.x + half_view.y) / sqrt(2.0)
 var center := camera.global_position + camera.offset
 check(center.x + rotated_half <= 2000.01 and center.y + rotated_half <= 2000.01, "rotated camera and offset remain inside bounds")
 var player := preload("res://scenes/Player.tscn").instantiate()
 add_child(player)
 player.teleport_to(Vector2(123, 456))
 check(GameState.player_world_position == Vector2(123, 456), "teleport immediately synchronizes world position")
 player.camera.follow_node(player)
 player.camera.set_mode("gameplay", {"begin": Vector2(-2000, -2000), "end": Vector2(2000, 2000)})
 player.teleport_to(Vector2(1400, 1400))
 player.camera._process(0.0)
 var edge_position: Vector2 = player.camera.global_position
 player.position -= Vector2(10, 10)
 player.camera._process(0.0)
 var expected: Vector2 = player.global_position.clamp(Vector2(-2000, -2000) + get_viewport().get_visible_rect().size / 2.0, Vector2(2000, 2000) - get_viewport().get_visible_rect().size / 2.0)
 check(player.camera.global_position.is_equal_approx(expected), "node follow recalculates after boundary clamp without offset drift")
 player.queue_free()
 print("Scale system failures: ", failures)
 get_tree().quit(failures)
