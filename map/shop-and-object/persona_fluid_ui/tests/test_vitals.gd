extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")
	create_timer(15).timeout.connect(func(): quit(1))

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var scene = load(get_script().resource_path.get_base_dir() + "/../scenes/vitals_hud.tscn")
	var hud = scene.instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame
	check(hud.get_node("Bars") is VBoxContainer, "Three vertical rows")
	check(hud.size == Vector2(340, 72), "Compact overall footprint")
	check(hud.stamina.position.y - hud.hp.size.y == 3, "Three pixel row gap")
	hud.update_vitals(85, 100, 16, 100, 41, 100, true)
	check(is_equal_approx(hud.hp._liquid.size.x, hud.hp.base_width() * 0.85), "HP border physically ends at 85 percent")
	check(is_equal_approx(hud.stamina._liquid.size.x, hud.stamina.base_width() * 0.16), "SP has independent physical length")
	check(is_equal_approx(hud.mp._liquid.size.x, hud.mp.base_width() * 0.41), "MP has independent physical length")
	check(hud.hp._value_label.position.x >= hud.hp._liquid.position.x + hud.hp.base_width(), "Numeric text sits beside the bar")
	check(hud.hp._value_label.text == "85/100", "Numeric text reflects resource")
	check(hud.stamina._warning_label.visible and not hud.hp._warning_label.visible, "Low warnings independent")
	hud.hp.set_value(20, 100, true)
	check(not hud.hp._warning_label.visible, "20 percent boundary is not low")
	hud.hp.set_value(19, 100, true)
	check(hud.hp._warning_label.visible, "Below 20 percent is low")
	hud.hp.set_value(0, 100, true)
	check(hud.hp._liquid.size.x == 0 and not hud.hp._liquid.visible, "Zero is truly zero width without a leftover frame")
	check(hud.hp._warning_label.visible and hud.hp._value_label.visible, "Zero retains warning and number")
	hud.hp.set_value(100, 100)
	check(hud.hp._liquid.size.x == 0, "Healing starts at current visible length")
	await create_timer(0.12).timeout
	check(hud.hp.displayed_ratio > 0 and hud.hp.displayed_ratio < 1, "Intermediate healing interpolation")
	check(is_equal_approx(hud.hp._liquid.size.x, hud.hp.base_width() * hud.hp.displayed_ratio), "Intermediate geometry follows Tween")
	var active_tween = hud.hp._tween
	hud.hp.set_value(100, 100)
	check(hud.hp._tween == active_tween, "Identical refresh preserves active Tween")
	hud.hp.set_value(37, 100)
	await create_timer(0.6).timeout
	check(is_equal_approx(hud.hp.displayed_ratio, 0.37), "Interrupted animation reaches latest target")
	check(is_equal_approx(hud.hp._liquid.size.x, hud.hp.base_width() * 0.37), "Latest length reaches target")
	hud.size.x = 280
	await process_frame
	await process_frame
	check(is_equal_approx(hud.hp._liquid.size.x, hud.hp.base_width() * 0.37), "Resize recomputes base width without changing ratio")
	hud.hp.set_value(100, 100, true)
	hud.hp.set_value(10, 20)
	check(hud.hp.displayed_value <= 20, "Lower maximum clamps displayed number")
	hud.reduced_motion = true
	check(hud.hp.displayed_ratio == 0.5, "Reduced motion immediately finishes Tween")
	check(hud.mp.reduced_motion and hud.stamina.reduced_motion, "Reduced motion propagates")
	check(hud.hp._material.get_shader_parameter("motion") == 0.0, "Reduced motion stops shader movement")
	hud.update_vitals(-1, 100, 10, 0, NAN, INF, true)
	check(hud.hp.current_value == 0, "Negative resource clamps")
	check(hud.stamina.displayed_ratio == 0 and not hud.stamina._warning_label.visible, "Zero maximum safe and not low")
	check(hud.mp.displayed_ratio == 0, "Nonfinite inputs safe")
	hud.hp.set_value(999, 100, true)
	check(hud.hp.current_value == 100 and hud.hp.displayed_ratio == 1, "Over-cap value clamps")
	hud.free()
	var early = load(get_script().resource_path.get_base_dir() + "/../scenes/vital_bar.tscn").instantiate()
	early.set_value(25, 100)
	root.add_child(early)
	check(early.displayed_ratio == 0.25, "Pre-ready initialization preserved")
	early.free()
	print("Three-row vitals: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
