extends Control

const FLUID = preload("../shaders/fluid.gdshader")
const TRACK_LEFT := 44.0
const TEXT_WIDTH := 76.0
const TEXT_GAP := 8.0

@export var caption: String = "HP"
@export var accent: Color = Color("ff244f")
@export_range(0.0, 1.0) var warning_ratio: float = 0.20
@export var transition_seconds: float = 0.45
@export var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if is_instance_valid(_material):
			_material.set_shader_parameter("motion", 0.0 if value else 1.0)
			if value:
				set_value(current_value, maximum_value, true)

var current_value: float = 100.0
var maximum_value: float = 100.0
var displayed_value: float = 100.0
var displayed_ratio: float = 1.0
var _tween: Tween
var _material: ShaderMaterial
var _value_label: Label
var _warning_label: Label
var _title: Label
var _liquid: ColorRect

func _ready() -> void:
	custom_minimum_size = Vector2(200, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = FLUID
	_material.set_shader_parameter("accent", accent)
	_material.set_shader_parameter("fill", 1.0)
	_material.set_shader_parameter("trail", 0.0)
	_liquid = ColorRect.new()
	_liquid.material = _material
	_liquid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_liquid)
	_title = Label.new()
	_title.text = caption
	_title.add_theme_color_override("font_color", accent)
	add_child(_title)
	_value_label = Label.new()
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.clip_text = true
	add_child(_value_label)
	_warning_label = Label.new()
	_warning_label.text = "!"
	_warning_label.add_theme_color_override("font_color", Color("fff0bb"))
	add_child(_warning_label)
	for label in [_title, _value_label, _warning_label]:
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	resized.connect(_layout)
	_layout()
	set_value(current_value, maximum_value, true)

func base_width() -> float:
	return maxf(0.0, size.x - TRACK_LEFT - TEXT_GAP - TEXT_WIDTH)

func _layout() -> void:
	_liquid.position = Vector2(TRACK_LEFT, 4)
	_liquid.size = Vector2(base_width() * displayed_ratio, 14)
	_liquid.visible = displayed_ratio > 0.0
	_title.position = Vector2(0, 1)
	_warning_label.position = Vector2(27, 1)
	_value_label.position = Vector2(size.x - TEXT_WIDTH, 1)
	_value_label.size = Vector2(TEXT_WIDTH, 20)

## Current ratio drives the real ColorRect width, including its outer border.
func set_value(value: float, maximum: float, instant: bool = false) -> void:
	var previous_value := current_value
	var previous_maximum := maximum_value
	maximum_value = maxf(maximum, 0.0) if is_finite(maximum) else 0.0
	current_value = clampf(value, 0.0, maximum_value) if is_finite(value) else 0.0
	if not is_instance_valid(_material):
		return
	_material.set_shader_parameter("motion", 0.0 if reduced_motion else 1.0)
	var ratio := current_value / maximum_value if maximum_value > 0.0 else 0.0
	var low := maximum_value > 0.0 and ratio < warning_ratio
	_material.set_shader_parameter("danger", 1.0 if low else 0.0)
	_warning_label.visible = low
	if not instant and not reduced_motion and transition_seconds > 0.0 and _tween != null \
			and current_value == previous_value and maximum_value == previous_maximum:
		return
	if _tween:
		_tween.kill()
	_set_display(minf(displayed_value, maximum_value))
	if instant or reduced_motion or transition_seconds <= 0.0:
		_set_display(current_value)
		_set_fill(ratio)
		return
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_display, displayed_value, current_value, transition_seconds)
	_tween.tween_method(_set_fill, displayed_ratio, ratio, transition_seconds)

func _set_display(value: float) -> void:
	displayed_value = value
	_value_label.text = "%d/%d" % [roundi(value), roundi(maximum_value)]

func _set_fill(value: float) -> void:
	displayed_ratio = clampf(value, 0.0, 1.0)
	_layout()
