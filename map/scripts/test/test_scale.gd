extends Node2D
var player: CharacterBody2D
var camera: SmartCamera
var info: Label
var mode: String = "gameplay"
var markers: Array[MapMarker] = []

func _ready() -> void:
 player = preload("res://scenes/Player.tscn").instantiate()
 add_child(player)
 camera = player.get_node("Camera2D")
 var overlay := CanvasLayer.new()
 add_child(overlay)
 var panel := VBoxContainer.new()
 panel.position = Vector2(20, 20)
 overlay.add_child(panel)
 info = Label.new()
 panel.add_child(info)
 for value in ["gameplay", "continent", "local"]:
  var button := Button.new()
  button.text = value
  button.pressed.connect(set_mode.bind(value))
  panel.add_child(button)
 for point in [Vector2.ZERO, Vector2(320, 160)]:
  var marker := preload("res://scenes/ui/map_marker.tscn").instantiate() as MapMarker
  marker.position = point
  add_child(marker)
  markers.append(marker)
 set_mode("gameplay")

func set_mode(value: String) -> void:
 mode = value
 var bounds: Dictionary = CoordinateConverter.config().maps.get(value, {}).get("world_bounds", {})
 camera.set_mode(value, bounds)
 for marker in markers: marker.current_map_type = value

func _draw() -> void:
 for x in range(-5120, 5121, 32):
  draw_line(Vector2(x, -5120), Vector2(x, 5120), Color(0.2, 0.25, 0.3))
  draw_line(Vector2(-5120, x), Vector2(5120, x), Color(0.2, 0.25, 0.3))

func _process(_delta: float) -> void:
 info.text = "WASD / arrows · grid 32 px\nPosition %.1f, %.1f · zoom %.3f · %s" % [player.position.x, player.position.y, camera.zoom.x, mode]
